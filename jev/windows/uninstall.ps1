# JEV 本地判分服务 · 卸载（「设置 → 应用」里点卸载会运行它）
# 只删除安装器自己放进来的东西；目录里如果还有别的文件，会原样保留。
$ErrorActionPreference = 'SilentlyContinue'

# Windows PowerShell 5.1 launched from a PowerShell 7 session inherits PS7's PSModulePath and then
# fails to auto-load built-in cmdlets. Reset it to the 5.1 defaults before anything else runs.
if ($PSVersionTable.PSVersion.Major -le 5) {
  $env:PSModulePath = [Environment]::GetFolderPath('MyDocuments') + '\WindowsPowerShell\Modules;' +
    $env:ProgramFiles + '\WindowsPowerShell\Modules;' + $env:SystemRoot + '\System32\WindowsPowerShell\v1.0\Modules'
}
$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$launch = Join-Path $InstallDir 'launch.js'

Write-Host ''
Write-Host '  正在卸载 JEV 本地判分服务…' -ForegroundColor White

$agent = Join-Path $InstallDir 'agent.ps1'
if (Test-Path -LiteralPath $agent) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $agent stop | Out-Null }
Get-Process -Name 'llama-server' | Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir, [StringComparison]::OrdinalIgnoreCase) } |
  ForEach-Object { $_.Kill(); [void]$_.WaitForExit(3000) }

$scheme = 'jev'
try { $s = (Get-Content -LiteralPath (Join-Path $InstallDir 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).scheme; if ($s -match '^[a-z][a-z0-9+.-]*$') { $scheme = $s } } catch { }
# jev:// 只在仍指向本目录时才删（避免误删别处重新安装的注册）
$cmd = (Get-ItemProperty -Path "HKCU:\Software\Classes\$scheme\shell\open\command" -Name '(default)').'(default)'
if ($cmd -and $cmd -like "*$launch*") { Remove-Item -Path "HKCU:\Software\Classes\$scheme" -Recurse -Force }
$un = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GenuineEduJEV' + $(if ($scheme -ne 'jev') { "-$scheme" } else { '' })
if ((Get-ItemProperty -Path $un -Name InstallLocation).InstallLocation -eq $InstallDir) { Remove-Item -Path $un -Recurse -Force }

foreach ($name in 'jev', 'agent.ps1', 'launch.js', 'config.json', 'agent.log', 'agent.log.old', 'uninstall.ps1') {
  $p = Join-Path $InstallDir $name
  for ($i = 0; $i -lt 5 -and (Test-Path -LiteralPath $p); $i++) {
    Remove-Item -LiteralPath $p -Recurse -Force
    if (Test-Path -LiteralPath $p) { Start-Sleep -Milliseconds 600 }
  }
}
if (-not (Get-ChildItem -LiteralPath $InstallDir -Force)) { Remove-Item -LiteralPath $InstallDir -Force }

Write-Host '  ✓ 已卸载。网页会自动退回文字匹配判分。' -ForegroundColor Green
Start-Sleep -Seconds 3
