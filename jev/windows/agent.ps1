# JEV local judging agent (Windows)
#
# One small headless process that owns llama-server for the web page:
#   - started on demand by the jev:// protocol (launch.js), never at logon
#   - picks free ports, starts llama-server with a one-time API key
#   - answers the page on 127.0.0.1:8002 (/ping /status /bye /stop)
#   - stops llama-server and exits when every page tab is gone
#
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
# Usage: agent.ps1 [start|stop|status]   (also accepts jev://start style URLs)
param([string]$Action = 'start')

# Windows PowerShell 5.1 launched from a PowerShell 7 session inherits PS7's PSModulePath and then
# fails to auto-load built-in cmdlets. Reset it to the 5.1 defaults before anything else runs.
if ($PSVersionTable.PSVersion.Major -le 5) {
  $env:PSModulePath = [Environment]::GetFolderPath('MyDocuments') + '\WindowsPowerShell\Modules;' +
    $env:ProgramFiles + '\WindowsPowerShell\Modules;' + $env:SystemRoot + '\System32\WindowsPowerShell\v1.0\Modules'
}

$ErrorActionPreference = 'Stop'
$AgentVersion = '2.0.0'
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$JevDir = Join-Path $Base 'jev'
$LlamaExe = Join-Path $JevDir 'llama\llama-server.exe'
$ModelName = 'Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf'
$LogPath = Join-Path $Base 'agent.log'

# ---------------------------------------------------------------- config
$Cfg = @{
  agentPorts       = @(8002, 18002, 28002)
  llamaPorts       = @(8001, 18001, 28001)
  allowedOrigins   = @('https://genuineedu.pages.dev', 'https://*.genuineedu.pages.dev', 'http://localhost:*', 'http://127.0.0.1:*')
  heartbeatTimeout = 90     # seconds without any ping from a tab -> that tab is gone
  byeGrace         = 10     # seconds after the last tab said bye -> shut down
  launchGrace      = 120    # seconds after launch with no tab ever seen -> shut down
  errorLinger      = 60     # seconds to keep reporting a startup error
  startupTimeout   = 120    # seconds for llama-server to become healthy
  sleepIdle        = 300    # llama-server unloads the model after this much idleness
  ctxSize          = 2048
}
$cfgFile = Join-Path $Base 'config.json'
if (Test-Path -LiteralPath $cfgFile) {
  try {
    $j = Get-Content -LiteralPath $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $Cfg[$p.Name] = $p.Value }
  } catch { }
}

function Write-Log([string]$msg) {
  try {
    if ((Test-Path -LiteralPath $LogPath) -and ((Get-Item -LiteralPath $LogPath).Length -gt 512KB)) {
      Move-Item -LiteralPath $LogPath -Destination ($LogPath + '.old') -Force
    }
    Add-Content -LiteralPath $LogPath -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + " [$PID] " + $msg) -Encoding UTF8
  } catch { }
}

function Get-OwnLlama {
  # Only ever touch llama-server processes that live in OUR install dir.
  $target = [IO.Path]::GetFullPath($LlamaExe)
  @(Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -and ([IO.Path]::GetFullPath($_.Path) -ieq $target) } catch { $false }
    })
}

function Stop-OwnLlama {
  foreach ($p in Get-OwnLlama) {
    try { $p.Kill(); [void]$p.WaitForExit(3000); Write-Log ('killed llama-server pid ' + $p.Id) } catch { }
  }
}

function Invoke-Local([int]$port, [string]$path, [int]$timeoutMs = 1500) {
  try {
    $req = [Net.HttpWebRequest]::Create("http://127.0.0.1:$port$path")
    $req.Proxy = $null
    $req.Timeout = $timeoutMs
    $req.ReadWriteTimeout = $timeoutMs
    $resp = $req.GetResponse()
    try {
      $sr = New-Object IO.StreamReader($resp.GetResponseStream())
      return @{ status = [int]$resp.StatusCode; body = $sr.ReadToEnd() }
    } finally { $resp.Close() }
  } catch [Net.WebException] {
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      $_.Exception.Response.Close()
      return @{ status = $code; body = '' }
    }
    return $null
  } catch { return $null }
}

function Find-Agent {
  foreach ($port in $Cfg.agentPorts) {
    $r = Invoke-Local $port '/status'
    if ($r -and $r.status -eq 200 -and $r.body -match '"app"\s*:\s*"jev-agent"') { return @{ port = $port; body = $r.body } }
  }
  return $null
}

function Test-PortFree([int]$port) {
  # Something already answering?  Then it is taken (covers 0.0.0.0 listeners too).
  $c = New-Object Net.Sockets.TcpClient
  try {
    $iar = $c.BeginConnect('127.0.0.1', $port, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne(300) -and $c.Connected) { return $false }
  } catch { } finally { $c.Close() }
  $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
  try { $l.ExclusiveAddressUse = $true; $l.Start(); return $true } catch { return $false } finally { try { $l.Stop() } catch { } }
}

# ---------------------------------------------------------------- one-shot actions
$act = $Action.ToLowerInvariant()
if ($act -match 'stop') { $act = 'stop' } elseif ($act -match 'status') { $act = 'status' } else { $act = 'start' }

if ($act -eq 'status') {
  $a = Find-Agent
  if ($a) { Write-Output $a.body; exit 0 }
  Write-Output '{"app":"jev-agent","state":"offline"}'
  exit 1
}

if ($act -eq 'stop') {
  $a = Find-Agent
  if ($a) { [void](Invoke-Local $a.port '/stop' 3000); Start-Sleep -Milliseconds 800 }
  Stop-OwnLlama
  exit 0
}

# ---------------------------------------------------------------- start: single instance
$createdNew = $false
$mutex = New-Object Threading.Mutex($true, 'Local\JEV_Agent_v2', [ref]$createdNew)
if (-not $createdNew) { exit 0 }

$listener = $null
$llama = $null
$state = 'starting'
$errorCode = ''
$llamaPort = 0
$key = [guid]::NewGuid().ToString('N')
$launchAt = Get-Date
$stateAt = Get-Date
$clients = @{}           # client id -> last ping time
$everSeen = $false
$emptySince = $null
$quit = $false
$quitReason = ''

function Set-State([string]$s, [string]$err = '') {
  $script:state = $s
  $script:errorCode = $err
  $script:stateAt = Get-Date
  Write-Log ("state=$s" + $(if ($err) { " error=$err" } else { '' }))
}

function Test-OriginAllowed([string]$origin) {
  if (-not $origin) { return $true }        # non-browser local tools (curl, installer)
  foreach ($pat in $Cfg.allowedOrigins) {
    $rx = '^' + ([regex]::Escape([string]$pat) -replace '\\\*', '[A-Za-z0-9-]+') + '$'
    if ($origin -match $rx) { return $true }
  }
  return $false
}

function ConvertTo-JsonString([string]$s) {
  '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Get-StatusJson {
  $parts = @(
    '"app":"jev-agent"',
    ('"version":' + (ConvertTo-JsonString $AgentVersion)),
    ('"state":' + (ConvertTo-JsonString $state)),
    ('"error":' + (ConvertTo-JsonString $errorCode)),
    ('"clients":' + $clients.Count)
  )
  if ($state -eq 'ready') {
    $parts += '"llama":{"url":' + (ConvertTo-JsonString "http://127.0.0.1:$llamaPort") + ',"key":' + (ConvertTo-JsonString $key) + '}'
    $parts += '"key":' + (ConvertTo-JsonString $key)
  }
  '{' + ($parts -join ',') + '}'
}

function Send-Response($stream, [int]$code, [string]$body, [string]$origin, [string]$type = 'application/json') {
  $reason = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found' }[$code]
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  $h = "HTTP/1.1 $code $reason`r`nContent-Type: $type; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n"
  if ($origin -and (Test-OriginAllowed $origin)) {
    $h += "Access-Control-Allow-Origin: $origin`r`nVary: Origin`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nAccess-Control-Allow-Headers: *`r`nAccess-Control-Allow-Private-Network: true`r`nAccess-Control-Max-Age: 600`r`n"
  }
  $hb = [Text.Encoding]::ASCII.GetBytes($h + "`r`n")
  $stream.Write($hb, 0, $hb.Length)
  if ($bytes.Length) { $stream.Write($bytes, 0, $bytes.Length) }
  $stream.Flush()
}

function Read-Request($stream) {
  $buf = New-Object byte[] 8192
  $ms = New-Object IO.MemoryStream
  $deadline = (Get-Date).AddMilliseconds(1500)
  while ((Get-Date) -lt $deadline -and $ms.Length -lt 65536) {
    try { $n = $stream.Read($buf, 0, $buf.Length) } catch { break }
    if ($n -le 0) { break }
    $ms.Write($buf, 0, $n)
    $text = [Text.Encoding]::ASCII.GetString($ms.ToArray())
    if ($text.Contains("`r`n`r`n")) { return $text }
  }
  return [Text.Encoding]::ASCII.GetString($ms.ToArray())
}

function Get-Query([string]$target, [string]$name) {
  $q = $target.IndexOf('?')
  if ($q -lt 0) { return '' }
  foreach ($kv in $target.Substring($q + 1).Split('&')) {
    $p = $kv.Split('=', 2)
    if ($p[0] -eq $name -and $p.Length -eq 2) { return [Uri]::UnescapeDataString($p[1]) }
  }
  return ''
}

function Handle-Client($client) {
  $stream = $client.GetStream()
  $stream.ReadTimeout = 1000
  try {
    $req = Read-Request $stream
    $lines = $req -split "`r`n"
    $first = $lines[0] -split ' '
    if ($first.Length -lt 2) { Send-Response $stream 400 '{"error":"bad_request"}' ''; return }
    $method = $first[0].ToUpperInvariant()
    $target = $first[1]
    $origin = ''
    foreach ($l in $lines) { if ($l -match '^(?i)origin:\s*(.+)$') { $origin = $Matches[1].Trim() } }

    if (-not (Test-OriginAllowed $origin)) {
      Write-Log "rejected origin $origin"
      Send-Response $stream 403 '{"error":"origin_not_allowed"}' ''
      return
    }
    if ($method -eq 'OPTIONS') { Send-Response $stream 204 '' $origin; return }

    $path = ($target -split '\?')[0]
    $cid = Get-Query $target 'c'
    if (-not $cid) { $cid = 'anon' }
    if ($cid.Length -gt 64) { $cid = $cid.Substring(0, 64) }

    switch ($path) {
      '/ping' {
        $script:clients[$cid] = Get-Date
        $script:everSeen = $true
        Send-Response $stream 200 (Get-StatusJson) $origin
      }
      '/status' { Send-Response $stream 200 (Get-StatusJson) $origin }
      '/bye' {
        $script:clients.Remove($cid)
        Write-Log "bye from $cid"
        Send-Response $stream 200 '{"ok":true}' $origin
      }
      '/stop' {
        Send-Response $stream 200 '{"ok":true}' $origin
        $script:quit = $true
        $script:quitReason = 'stop requested'
      }
      default { Send-Response $stream 404 '{"error":"not_found"}' $origin }
    }
  } catch {
    Write-Log ('request error: ' + $_.Exception.Message)
  } finally {
    try { $client.Close() } catch { }
  }
}

function Start-Llama {
  if (-not (Test-Path -LiteralPath $LlamaExe)) { Set-State 'error' 'llama_missing'; return }
  if (-not (Test-Path -LiteralPath (Join-Path $JevDir $ModelName))) { Set-State 'error' 'model_missing'; return }
  $script:llamaPort = 0
  # Ports can be held for a moment (a process still exiting, WSL port forwarding...): retry ~10 s before giving up.
  for ($try = 0; $try -lt 6 -and -not $script:llamaPort; $try++) {
    if ($try) { Start-Sleep -Seconds 2 }
    foreach ($p in $Cfg.llamaPorts) { if (Test-PortFree $p) { $script:llamaPort = $p; break } else { Write-Log "llama port $p busy" } }
  }
  if (-not $script:llamaPort) { Set-State 'error' 'port_busy'; return }

  $serverLog = Join-Path $JevDir 'server.log'
  try { if ((Test-Path -LiteralPath $serverLog) -and ((Get-Item -LiteralPath $serverLog).Length -gt 2MB)) { Remove-Item -LiteralPath $serverLog -Force } } catch { }

  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $LlamaExe
  # Relative model/log paths: llama-server cannot open some non-ASCII absolute paths.
  $psi.Arguments = "-m `"$ModelName`" --host 127.0.0.1 --port $($script:llamaPort) -c $($Cfg.ctxSize) --no-webui --api-key $key --sleep-idle-seconds $($Cfg.sleepIdle) --log-file server.log"
  $psi.WorkingDirectory = $JevDir
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  try {
    $script:llama = [Diagnostics.Process]::Start($psi)
    Write-Log ("llama-server pid $($script:llama.Id) on port $($script:llamaPort)")
  } catch {
    Write-Log ('llama start failed: ' + $_.Exception.Message)
    Set-State 'error' 'llama_start_failed'
  }
}

function Test-LlamaHealthy {
  $r = Invoke-Local $llamaPort '/health' 800
  return ($r -and $r.status -eq 200 -and $r.body -match '"ok"')
}

# ---------------------------------------------------------------- main
try {
  Write-Log "agent $AgentVersion starting"
  foreach ($p in $Cfg.agentPorts) {
    $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, [int]$p)
    try { $l.ExclusiveAddressUse = $true; $l.Start(); $listener = $l; Write-Log "listening on $p"; break } catch { Write-Log "agent port $p busy" }
  }
  if (-not $listener) { Write-Log 'no free agent port, giving up'; exit 1 }

  Stop-OwnLlama            # leftovers from a crashed agent or the old tray controller
  Start-Llama

  $lastCheck = Get-Date
  while (-not $quit) {
    if ($listener.Pending()) { Handle-Client ($listener.AcceptTcpClient()); continue }
    Start-Sleep -Milliseconds 100
    $now = Get-Date
    if (($now - $lastCheck).TotalMilliseconds -lt 500) { continue }
    $lastCheck = $now

    # llama-server lifecycle
    if ($state -ne 'error' -and $llama -and $llama.HasExited) {
      Write-Log ("llama-server exited with code " + $llama.ExitCode)
      if ($state -eq 'starting') { Set-State 'error' 'llama_exit' } else { $quit = $true; $quitReason = 'llama-server exited' }
    } elseif ($state -eq 'starting') {
      if (Test-LlamaHealthy) { Set-State 'ready' }
      elseif (($now - $stateAt).TotalSeconds -gt $Cfg.startupTimeout) { Set-State 'error' 'startup_timeout' }
    }
    if ($state -eq 'error' -and ($now - $stateAt).TotalSeconds -gt $Cfg.errorLinger) { $quit = $true; $quitReason = "error $errorCode" }

    # page lifecycle: forget silent tabs, exit when nobody is left
    foreach ($id in @($clients.Keys)) {
      if (($now - $clients[$id]).TotalSeconds -gt $Cfg.heartbeatTimeout) { $clients.Remove($id); Write-Log "client $id timed out" }
    }
    if ($clients.Count -gt 0) { $emptySince = $null }
    elseif ($everSeen) {
      if (-not $emptySince) { $emptySince = $now }
      elseif (($now - $emptySince).TotalSeconds -gt $Cfg.byeGrace) { $quit = $true; $quitReason = 'all pages closed' }
    } elseif (($now - $launchAt).TotalSeconds -gt $Cfg.launchGrace) { $quit = $true; $quitReason = 'no page connected' }
  }
} catch {
  Write-Log ('fatal: ' + ($_ | Out-String))
} finally {
  Write-Log ("shutting down: $quitReason")
  if ($llama -and -not $llama.HasExited) { try { $llama.Kill(); [void]$llama.WaitForExit(3000) } catch { } }
  if ($listener) { try { $listener.Stop() } catch { } }
  try { $mutex.ReleaseMutex() } catch { }
}
