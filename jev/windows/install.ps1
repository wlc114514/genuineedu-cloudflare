# JEV 本地判分服务 · Windows 安装器
# 由网页下载的 install-jev.bat 拉起；也可以直接：
#   powershell -ExecutionPolicy Bypass -File install.ps1 [-Origin https://genuineedu.pages.dev]
# 重复运行是安全的：已下载的文件校验通过就跳过，下载中断会续传。
param(
  [string]$Origin = $(if ($env:JEV_ORIGIN) { $env:JEV_ORIGIN } else { 'https://genuineedu.pages.dev' }),
  [string]$InstallDir = $(if ($env:JEV_INSTALL_DIR) { $env:JEV_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\JEV' }),
  [string]$Source = '',
  [string[]]$LlamaUrls = @(),
  [string[]]$ModelUrls = @(),
  [switch]$NoStart,
  [switch]$NoRegister,
  [string]$Scheme = 'jev'          # 仅测试用：换个协议名，避免覆盖正式的 jev://
)

# Windows PowerShell 5.1 launched from a PowerShell 7 session inherits PS7's PSModulePath and then
# fails to auto-load built-in cmdlets. Reset it to the 5.1 defaults before anything else runs.
if ($PSVersionTable.PSVersion.Major -le 5) {
  $env:PSModulePath = [Environment]::GetFolderPath('MyDocuments') + '\WindowsPowerShell\Modules;' +
    $env:ProgramFiles + '\WindowsPowerShell\Modules;' + $env:SystemRoot + '\System32\WindowsPowerShell\v1.0\Modules'
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$Origin = $Origin.TrimEnd('/')
if (-not $Source) { $Source = "$Origin/jev/windows" }

$LLAMA_TAG = 'b8944'
$LLAMA_ZIP = "llama-$LLAMA_TAG-bin-win-cpu-x64.zip"
$LLAMA_SHA = 'cd9f83790996746f2071e3fb463bf51b70e6502be4baeac2f258745f73cc9625'
$LLAMA_SIZE = 15895092
$MODEL = 'Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf'
$MODEL_SHA = '0a19bc29bacc33e0d871146c8612b24dd14c2ed2e61cedeb7a928b0852628bac'
$MODEL_SIZE = 529296864
if (-not $LlamaUrls.Count) {
  $gh = "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_TAG/$LLAMA_ZIP"
  $LlamaUrls = @("https://gh-proxy.com/$gh", "https://ghproxy.net/$gh", $gh)
}
if (-not $ModelUrls.Count) {
  $p = "chaoliangUNSW/Jev-Style-0.8B-Decision-v3-GGUF/resolve/main/$MODEL"
  $ModelUrls = @("https://hf-mirror.com/$p", "https://huggingface.co/$p")
}

$JevDir = Join-Path $InstallDir 'jev'
$LlamaDir = Join-Path $JevDir 'llama'
$LlamaExe = Join-Path $LlamaDir 'llama-server.exe'
$ModelPath = Join-Path $JevDir $MODEL
$AgentFiles = @('agent.ps1', 'launch.js', 'uninstall.ps1')

function Say([string]$msg, [string]$color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Step([string]$msg) { Write-Host ''; Write-Host $msg -ForegroundColor Cyan }
function Fail([string]$msg, [string]$hint = '') {
  Write-Host ''
  Write-Host "[安装失败] $msg" -ForegroundColor Red
  if ($hint) { Write-Host $hint -ForegroundColor Yellow }
  Write-Host '重新运行安装器即可继续（已下载的部分不会重下）。' -ForegroundColor Yellow
  exit 1
}

function Test-Sha([string]$file, [string]$sha) {
  $fs = [IO.File]::OpenRead($file)
  try {
    $alg = [Security.Cryptography.SHA256]::Create()
    $hex = -join ($alg.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') })
  } finally { $fs.Dispose() }
  return $hex -ieq $sha
}

$Curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (-not (Test-Path -LiteralPath $Curl)) { $Curl = $null }

# 下载到 .part，大小与 SHA256 都对上才改成正式文件名
function Get-Verified([string[]]$urls, [string]$dest, [string]$sha, [long]$size, [string]$label) {
  if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -eq $size) {
    Say "  校验已有的$label…"
    if (Test-Sha $dest $sha) { Say '  已存在且完整，跳过下载' 'Green'; return }
    Say '  已有文件损坏，重新下载' 'Yellow'
    Remove-Item -LiteralPath $dest -Force
  }
  $part = "$dest.part"
  if ((Test-Path -LiteralPath $part) -and (Get-Item -LiteralPath $part).Length -gt $size) { Remove-Item -LiteralPath $part -Force }
  $i = 0
  foreach ($u in $urls) {
    $i++
    $hostName = ([Uri]$u).Host
    Say "  下载中（线路 $i/$($urls.Count)：$hostName）"
    if ($Curl) {
      & $Curl -L --fail --retry 3 --retry-delay 2 --connect-timeout 20 -# -C - -o $part $u
      $rc = $LASTEXITCODE
      if ($rc -eq 33 -or $rc -eq 36) {   # 服务器不支持续传：从头下
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        & $Curl -L --fail --retry 3 --retry-delay 2 --connect-timeout 20 -# -o $part $u
        $rc = $LASTEXITCODE
      }
      if ($rc -ne 0) { Say "  这条线路失败（curl $rc），换下一条" 'Yellow'; continue }
    } else {
      try { Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $part } catch { Say '  这条线路失败，换下一条' 'Yellow'; continue }
    }
    if (-not (Test-Path -LiteralPath $part)) { continue }
    $len = (Get-Item -LiteralPath $part).Length
    if ($len -ne $size) {
      Say "  文件大小不对（$len / $size），换下一条" 'Yellow'
      if ($len -gt $size) { Remove-Item -LiteralPath $part -Force }
      continue
    }
    Say '  校验中…'
    if (-not (Test-Sha $part $sha)) {
      Say '  校验不通过（文件被篡改或损坏），换下一条' 'Yellow'
      Remove-Item -LiteralPath $part -Force
      continue
    }
    Move-Item -LiteralPath $part -Destination $dest -Force
    Say '  完成' 'Green'
    return
  }
  Fail "$label 下载失败。" '请检查网络（校园网/代理有时会拦截大文件），稍后重试。'
}

function Get-AgentFile([string]$name) {
  $dest = Join-Path $InstallDir $name
  $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot $name } else { $null }
  if ($local -and (Test-Path -LiteralPath $local)) { Copy-Item -LiteralPath $local -Destination $dest -Force; return }
  $tmp = "$dest.new"
  $ok = $false
  for ($try = 1; $try -le 3 -and -not $ok; $try++) {
    try {
      if ($Curl) { & $Curl -fsSL --retry 2 -o $tmp "$Source/$name"; $ok = ($LASTEXITCODE -eq 0) }
      else { Invoke-WebRequest -UseBasicParsing -Uri "$Source/$name" -OutFile $tmp; $ok = $true }
    } catch { $ok = $false }
  }
  # 防呆：拿到的必须是我们的脚本，而不是网关错误页
  if ($ok) { $ok = (Get-Content -LiteralPath $tmp -Raw -Encoding UTF8) -match 'JEV' }
  if (-not $ok) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; Fail "无法下载组件 $name（$Source）。" }
  Move-Item -LiteralPath $tmp -Destination $dest -Force
}

function Stop-Everything {
  # 新版管家
  $agent = Join-Path $InstallDir 'agent.ps1'
  if (Test-Path -LiteralPath $agent) {
    try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $agent stop | Out-Null } catch { }
  }
  # 旧版托盘控制器（jev_tray.ps1）和旧的隐藏启动器
  try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='wscript.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -and ($_.CommandLine -match 'jev_tray\.ps1|start_jev_hidden\.vbs' -or ($_.CommandLine -like "*$InstallDir*agent.ps1*")) -and $_.ProcessId -ne $PID } |
      ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch { } }
  } catch { }
  # 本安装目录里的 llama-server（别处的 llama-server 不碰）
  Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and $_.Path.StartsWith($InstallDir, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
  } | ForEach-Object { try { $_.Kill(); [void]$_.WaitForExit(3000) } catch { } }
}

function Test-LlamaVersion {
  if (-not (Test-Path -LiteralPath $LlamaExe)) { return $false }
  $stamp = Join-Path $LlamaDir 'VERSION'
  if ((Test-Path -LiteralPath $stamp) -and ((Get-Content -LiteralPath $stamp -Raw).Trim() -eq $LLAMA_TAG)) { return $true }
  try {
    $out = & $LlamaExe --version 2>&1 | Out-String
    if ($out -match ('version:\s*' + $LLAMA_TAG.TrimStart('b') + '\b')) { Set-Content -LiteralPath $stamp -Value $LLAMA_TAG; return $true }
  } catch { }
  return $false
}

function Find-AgentReady([int]$seconds) {
  $end = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $end) {
    foreach ($port in 8002, 18002, 28002) {
      try {
        # 不走系统代理（Clash 之类开着时，127.0.0.1 也可能被转给代理）
        $req = [Net.HttpWebRequest]::Create("http://127.0.0.1:$port/status")
        $req.Proxy = $null
        $req.Timeout = 2000
        $resp = $req.GetResponse()
        try { $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() } finally { $resp.Close() }
        if ($body -match '"app":"jev-agent"') {
          if ($body -match '"state":"ready"') { return 'ready' }
          if ($body -match '"state":"error".*?"error":"([a-z_]+)"') { return $Matches[1] }
        }
      } catch { }
    }
    Start-Sleep -Milliseconds 700
  }
  return 'timeout'
}

# ======================================================================
Write-Host ''
Write-Host '  JEV 本地判分服务 · 安装' -ForegroundColor White
Write-Host "  位置：$InstallDir" -ForegroundColor DarkGray
Write-Host '  装好以后不用管它：网页需要时自动启动，网页关掉自动停止。' -ForegroundColor DarkGray

Step '[1/5] 检查环境'
if (-not [Environment]::Is64BitOperatingSystem) { Fail '需要 64 位 Windows。' }
try { New-Item -ItemType Directory -Force -Path $LlamaDir | Out-Null } catch { Fail "无法创建目录 $InstallDir" '请检查磁盘权限。' }
$needMB = 60
if (-not ((Test-Path -LiteralPath $ModelPath) -and (Get-Item -LiteralPath $ModelPath).Length -eq $MODEL_SIZE)) { $needMB += 560 }
$drive = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($InstallDir))
$freeMB = [math]::Floor((New-Object IO.DriveInfo($drive)).AvailableFreeSpace / 1MB)
if ($freeMB -lt $needMB) { Fail "磁盘 $drive 剩余空间不足（需要约 $needMB MB，现有 $freeMB MB）。" }
Say "  磁盘空间够用（剩余 $freeMB MB）" 'Green'
Stop-Everything
Say '  已停止正在运行的旧服务' 'Green'

Step "[2/5] 推理引擎 llama-server（$LLAMA_TAG，约 16MB）"
if (Test-LlamaVersion) {
  Say '  已是最新，跳过' 'Green'
} else {
  $zip = Join-Path $env:TEMP $LLAMA_ZIP
  Get-Verified $LlamaUrls $zip $LLAMA_SHA $LLAMA_SIZE 'llama-server 压缩包'
  Say '  解压中…'
  $tmp = Join-Path $env:TEMP ('jev-llama-' + [guid]::NewGuid().ToString('N'))
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    $exe = Get-ChildItem -LiteralPath $tmp -Recurse -Filter 'llama-server.exe' | Select-Object -First 1
    if (-not $exe) { Fail '压缩包里没有 llama-server.exe。' }
    Get-ChildItem -LiteralPath $LlamaDir -Force | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $exe.DirectoryName '*') -Destination $LlamaDir -Recurse -Force
    Set-Content -LiteralPath (Join-Path $LlamaDir 'VERSION') -Value $LLAMA_TAG
  } catch {
    Fail ('解压失败：' + $_.Exception.Message) '如果杀毒软件拦截了 llama-server.exe，请把它加入信任后重试。'
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
  if (-not (Test-LlamaVersion)) { Fail 'llama-server 无法运行。' '可能被杀毒软件隔离，或系统缺少 VC++ 运行库。' }
  Say '  完成' 'Green'
}

Step '[3/5] 判分模型（约 505MB，第一次装需要几分钟）'
Get-Verified $ModelUrls $ModelPath $MODEL_SHA $MODEL_SIZE '模型'

Step '[4/5] 安装服务组件'
foreach ($f in $AgentFiles) { Get-AgentFile $f }
# 允许访问本服务的网站：默认几项 + 下载安装器的那个网站，保留用户以前手动加的
$cfgPath = Join-Path $InstallDir 'config.json'
$origins = New-Object Collections.Generic.List[string]
foreach ($o in @('https://genuineedu.pages.dev', 'https://*.genuineedu.pages.dev', 'http://localhost:*', 'http://127.0.0.1:*', $Origin)) { if ($o -and -not $origins.Contains($o)) { $origins.Add($o) } }
if (Test-Path -LiteralPath $cfgPath) {
  try {
    $old = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($o in @($old.allowedOrigins)) { if ($o -and -not $origins.Contains([string]$o)) { $origins.Add([string]$o) } }
  } catch { }
}
$cfgJson = @{ allowedOrigins = $origins.ToArray(); scheme = $Scheme } | ConvertTo-Json -Compress
[IO.File]::WriteAllText($cfgPath, $cfgJson, (New-Object Text.UTF8Encoding($false)))
# 旧版托盘/启动脚本（已被管家取代）
foreach ($old in 'jev_tray.ps1', 'start_jev_hidden.vbs', 'jev_run.ico', 'jev_stop.ico', 'tray.log', 'tray_error.log', '启动判分服务.bat') {
  Remove-Item -LiteralPath (Join-Path $InstallDir $old) -Force -ErrorAction SilentlyContinue
}
Say '  完成' 'Green'

Step '[5/5] 注册到系统'
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
$launch = Join-Path $InstallDir 'launch.js'
if (-not $NoRegister) {
  $cls = "HKCU:\Software\Classes\$Scheme"
  New-Item -Path "$cls\shell\open\command" -Force | Out-Null
  Set-ItemProperty -Path $cls -Name '(default)' -Value 'URL:JEV Local Service'
  Set-ItemProperty -Path $cls -Name 'URL Protocol' -Value ''
  Set-ItemProperty -Path "$cls\shell\open\command" -Name '(default)' -Value "`"$wscript`" //B //Nologo //E:jscript `"$launch`" `"%1`""

  # 「设置 → 应用」里可以像普通软件一样卸载
  $un = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GenuineEduJEV' + $(if ($Scheme -ne 'jev') { "-$Scheme" } else { '' })
  New-Item -Path $un -Force | Out-Null
  $sizeKB = [int]((Get-ChildItem -LiteralPath $InstallDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1KB)
  $props = @{
    DisplayName = 'JEV 本地判分服务'; DisplayVersion = '2.0.0'; Publisher = 'GenuineEdu'
    InstallLocation = $InstallDir; URLInfoAbout = $Origin
    UninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $InstallDir 'uninstall.ps1')`""
  }
  foreach ($k in $props.Keys) { Set-ItemProperty -Path $un -Name $k -Value $props[$k] }
  foreach ($k in 'NoModify', 'NoRepair') { New-ItemProperty -Path $un -Name $k -Value 1 -PropertyType DWord -Force | Out-Null }
  New-ItemProperty -Path $un -Name 'EstimatedSize' -Value $sizeKB -PropertyType DWord -Force | Out-Null
  Say '  已注册（卸载：设置 → 应用 → JEV 本地判分服务）' 'Green'
} else {
  Say '  测试模式：跳过注册' 'DarkGray'
}

if ($NoStart) { Say ''; Say '安装完成。' 'Green'; exit 0 }

Write-Host ''
Say '正在启动判分服务…'
Start-Process -FilePath $wscript -ArgumentList @('//B', '//Nologo', '//E:jscript', "`"$launch`"", 'start') -WindowStyle Hidden
$res = Find-AgentReady 90
switch ($res) {
  'ready' {
    Write-Host ''
    Write-Host '  ✓ 安装完成，判分服务已就绪。回到网页就能用了。' -ForegroundColor Green
    Write-Host '    以后不用再管它：网页需要时自动启动，关掉网页自动停止。' -ForegroundColor DarkGray
    exit 0
  }
  'model_missing' { Fail '模型文件缺失。' }
  'llama_missing' { Fail 'llama-server 缺失。' '可能被杀毒软件隔离了，请恢复后重试。' }
  'port_busy' { Fail '本机端口被占满（8001/18001/28001）。' '关掉占用这些端口的程序后，回到网页点「启动」即可。' }
  default {
    Fail "服务没有按时启动（$res）。" ('日志：' + (Join-Path $InstallDir 'agent.log') + ' 和 ' + (Join-Path $JevDir 'server.log'))
  }
}
