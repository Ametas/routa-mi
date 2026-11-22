# CI smoke test on a Windows runner (administrator): installs RoutaMi,
# registers the helper service and checks the parts a GUI test cannot reach.
param(
  [Parameter(Mandatory)] [string] $Installer,
  [Parameter(Mandatory)] [string] $CoreSha256
)
$ErrorActionPreference = 'Stop'
function Fail($message) { Write-Error $message; exit 1 }

$dir = Join-Path $env:ProgramFiles 'RoutaMi'
Start-Process $Installer -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait
foreach ($file in 'RoutaMi.exe', 'RoutaMiCore.exe', 'RoutaMiHelperService.exe', 'RoutaMiTray.exe', 'libcronet.dll') {
  if (-not (Test-Path (Join-Path $dir $file))) { Fail "installer did not place $file" }
}
Write-Host 'installed into Program Files'

# The core talks to the app over loopback: the first frame is the token.
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$core = Start-Process (Join-Path $dir 'RoutaMiCore.exe') -ArgumentList "tcp:${port}:smoke-token" -PassThru
$accept = $listener.AcceptTcpClientAsync()
if (-not $accept.Wait(15000)) { Fail 'the core did not connect back' }
$stream = $accept.Result.GetStream()
$header = New-Object byte[] 4
$read = 0
while ($read -lt 4) { $read += $stream.Read($header, $read, 4 - $read) }
$length = [BitConverter]::ToUInt32($header, 0)
$payload = New-Object byte[] $length
$read = 0
while ($read -lt $length) { $read += $stream.Read($payload, $read, $length - $read) }
$token = [Text.Encoding]::UTF8.GetString($payload)
if ($token -ne 'smoke-token') { Fail "first frame was '$token'" }
Stop-Process -Id $core.Id -Force
$listener.Stop()
Write-Host 'core process connected with the token'

& (Join-Path $dir 'RoutaMiHelperService.exe') install
if ($LASTEXITCODE -ne 0) { Fail "helper install exited with $LASTEXITCODE" }
Start-Sleep -Seconds 2
$service = Get-Service RoutaMiHelperService
if ($service.Status -ne 'Running') { Fail "helper service is $($service.Status)" }
$config = sc.exe qc RoutaMiHelperService | Out-String
if ($config -notmatch [regex]::Escape("`"$dir\RoutaMiHelperService.exe`"")) {
  Fail "service path is not quoted: $config"
}
$ping = (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:47990/ping).Content
if ($ping -ne $CoreSha256) { Fail "ping returned '$ping', want $CoreSha256" }
Write-Host 'helper service runs from Program Files and reports the core hash'

$body = @{ path = (Join-Path $dir 'RoutaMiCore.exe'); arg = 'tcp:1:x' } | ConvertTo-Json
try {
  Invoke-WebRequest -UseBasicParsing -Method Post -Body $body http://127.0.0.1:47990/start | Out-Null
  Fail 'the helper accepted a caller that is not RoutaMi.exe'
} catch [System.Net.WebException] {
  if ([int]$_.Exception.Response.StatusCode -ne 403) { throw }
} catch {
  if ($_.Exception.Response.StatusCode.value__ -ne 403) { throw }
}
Write-Host 'helper refuses other callers'

# The app itself: with the helper installed it must start the core through
# it, which only works if the helper recognises RoutaMi.exe as its caller.
# The core starts with the proxy, after a first launch's disclaimer: the
# preferences accept it and turn on autoRun (shared_preferences_windows keeps
# them under %APPDATA%\<CompanyName>\<ProductName>). They come in the
# pre-database format (no version), which the app migrates: that is the only
# way to hand it a profile without the UI. TUN is on, as a user would switch
# it: the app must bring up the Wintun adapter through the core the helper
# runs.
$prefsDir = Join-Path $env:APPDATA 'RoutaTerm\RoutaMi'
New-Item -ItemType Directory -Force (Join-Path $prefsDir 'profiles') | Out-Null
"mode: direct`nproxies: []`nrules:`n  - MATCH,DIRECT`n" |
  Set-Content -Encoding utf8 -NoNewline (Join-Path $prefsDir 'profiles\smoke.yaml')
$config = @{
  appSetting       = @{ disclaimerAccepted = $true; autoRun = $true }
  profiles         = @(@{ id = 'smoke'; label = 'smoke'; autoUpdateDuration = 86400000000; autoUpdate = $false })
  currentProfileId = 'smoke'
  patchClashConfig = @{ mode = 'direct'; tun = @{ enable = $true } }
} | ConvertTo-Json -Depth 5 -Compress
@{ 'flutter.config' = $config } | ConvertTo-Json |
  Set-Content -Encoding utf8 (Join-Path $prefsDir 'shared_preferences.json')
$appLog = Join-Path $env:RUNNER_TEMP 'routami-app.log'
$appErr = Join-Path $env:RUNNER_TEMP 'routami-app.err'
$app = Start-Process (Join-Path $dir 'RoutaMi.exe') -PassThru `
  -RedirectStandardOutput $appLog -RedirectStandardError $appErr
$deadline = (Get-Date).AddSeconds(60)
while (-not (Get-Process RoutaMiCore -ErrorAction SilentlyContinue)) {
  if ($app.HasExited) { Fail "RoutaMi.exe exited with $($app.ExitCode)" }
  if ((Get-Date) -gt $deadline) {
    Get-Process RoutaMi* | Format-Table Id, ProcessName, StartTime | Out-String | Write-Host
    Get-ChildItem -Recurse $prefsDir -ErrorAction SilentlyContinue | Select-Object FullName, Length | Out-String | Write-Host
    sc.exe query RoutaMiHelperService | Out-String | Write-Host
    foreach ($log in $appLog, $appErr, (Join-Path $env:ProgramData 'RoutaMi\helper.log')) {
      Write-Host "--- $log"
      Get-Content $log -Tail 200 -ErrorAction SilentlyContinue | Write-Host
    }
    Fail 'RoutaMi.exe did not start the core'
  }
  Start-Sleep -Seconds 1
}
$owner = (Get-CimInstance Win32_Process -Filter "Name = 'RoutaMiCore.exe'").ParentProcessId
$parent = (Get-Process -Id $owner -ErrorAction SilentlyContinue).ProcessName
Write-Host "RoutaMi.exe started the core (parent: $parent)"
Start-Sleep -Seconds 5
Write-Host '--- helper.log'
Get-Content (Join-Path $env:ProgramData 'RoutaMi\helper.log') -Tail 60 -ErrorAction SilentlyContinue | Write-Host
if (-not (Get-Process RoutaMiCore -ErrorAction SilentlyContinue)) { Fail 'the core exited after starting' }
if ($parent -ne 'RoutaMiHelperService') { Fail 'the core was not started by the helper service' }
$deadline = (Get-Date).AddSeconds(60)
while (-not (Get-NetAdapter -Name RoutaMi -ErrorAction SilentlyContinue)) {
  if ((Get-Date) -gt $deadline) {
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status | Out-String | Write-Host
    foreach ($log in $appLog, $appErr) {
      Write-Host "--- $log"
      Get-Content $log -Tail 200 -ErrorAction SilentlyContinue | Write-Host
    }
    Fail 'the app turned TUN on but no RoutaMi adapter came up'
  }
  Start-Sleep -Seconds 1
}
Write-Host "the app brought up the TUN adapter: $((Get-NetAdapter -Name RoutaMi).InterfaceDescription)"
Stop-Process -Id $app.Id -Force
$deadline = (Get-Date).AddSeconds(15)
while (Get-Process RoutaMiCore -ErrorAction SilentlyContinue) {
  if ((Get-Date) -gt $deadline) { Fail 'the core outlived the app' }
  Start-Sleep -Milliseconds 500
}

# Lite mode: RoutaMi.exe --lite starts, hands the core to RoutaMiTray.exe and
# exits; the tray restarts the core through the helper; RoutaMi.exe takes the
# core back without starting a new one.
function Show-Logs {
  Get-Process RoutaMi* -ErrorAction SilentlyContinue | Format-Table Id, ProcessName | Out-String | Write-Host
  foreach ($log in $appLog, $appErr, (Get-ChildItem $env:APPDATA -Recurse -Filter lite.log -ErrorAction SilentlyContinue | Select-Object -First 1).FullName, (Join-Path $env:ProgramData 'RoutaMi\helper.log')) {
    Write-Host "--- $log"
    Get-Content $log -Tail 80 -ErrorAction SilentlyContinue | Write-Host
  }
}
function Wait-Until($what, $seconds, [scriptblock] $condition) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while (-not (& $condition)) {
    if ((Get-Date) -gt $deadline) {
      Show-Logs
      Fail "timed out: $what"
    }
    Start-Sleep -Milliseconds 500
  }
}
# lite.json sits in the app's data directory (path_provider), next to the prefs.
function Lite-State { Get-ChildItem $env:APPDATA -Recurse -Filter lite.json -ErrorAction SilentlyContinue | Select-Object -First 1 }
function Core-Pid { (Get-Process RoutaMiCore -ErrorAction SilentlyContinue | Select-Object -First 1).Id }
function Lite($method, $path) {
  $state = Get-Content (Lite-State).FullName -Raw | ConvertFrom-Json
  $headers = @{ Authorization = "Bearer $($state.token)" }
  Invoke-RestMethod -Method $method -Headers $headers -TimeoutSec 60 "http://127.0.0.1:$($state.port)$path"
}

$app = Start-Process (Join-Path $dir 'RoutaMi.exe') -ArgumentList '--lite' -PassThru `
  -RedirectStandardOutput $appLog -RedirectStandardError $appErr
Wait-Until 'RoutaMi.exe --lite went to the tray' 90 {
  $app.HasExited -and (Get-Process RoutaMiTray -ErrorAction SilentlyContinue) -and (Lite-State)
}
$litePid = Core-Pid
if (-not $litePid) {
  Write-Host "RoutaMi.exe exit code: $($app.ExitCode)"
  Show-Logs
  Fail 'no core after RoutaMi.exe left for the tray'
}
# The app's exit must not take the core with it (the helper's /stop).
Start-Sleep -Seconds 5
if ((Core-Pid) -ne $litePid) { Fail "the core $litePid did not survive RoutaMi.exe leaving for the tray" }
$status = Lite GET /status
if (-not $status.connected) { Fail "tray status: $($status | ConvertTo-Json -Compress)" }
# CI has no profile, so the app may not have started the proxy: the tray
# keeps whatever state it was handed, and toggles flip it.
$initial = [bool]$status.running
Write-Host "lite mode: RoutaMi.exe exited, the tray holds core $litePid (running: $initial)"

Lite POST /toggle | Out-Null
if ([bool](Lite GET /status).running -eq $initial) { Fail 'the tray did not toggle the core' }
Lite POST /toggle | Out-Null
if ([bool](Lite GET /status).running -ne $initial) { Fail 'the tray did not toggle the core back' }

Lite POST /restart | Out-Null
Wait-Until 'the tray restarted the core' 30 { (Core-Pid) -and (Core-Pid) -ne $litePid }
$restartedPid = Core-Pid
$owner = (Get-CimInstance Win32_Process -Filter "ProcessId = $restartedPid").ParentProcessId
if ((Get-Process -Id $owner).ProcessName -ne 'RoutaMiHelperService') { Fail 'the tray restarted the core outside the helper' }
$status = Lite GET /status
if (-not $status.connected -or [bool]$status.running -ne $initial) { Fail "after restart: $($status | ConvertTo-Json -Compress)" }
Write-Host "lite mode: the tray restarted the core through the helper ($restartedPid)"

$app = Start-Process (Join-Path $dir 'RoutaMi.exe') -PassThru `
  -RedirectStandardOutput $appLog -RedirectStandardError $appErr
Wait-Until 'RoutaMi.exe took the core back' 90 { -not (Get-Process RoutaMiTray -ErrorAction SilentlyContinue) }
Start-Sleep -Seconds 5
if ($app.HasExited) { Fail "RoutaMi.exe exited with $($app.ExitCode) after taking the core" }
if ((Core-Pid) -ne $restartedPid) { Fail "RoutaMi.exe started a new core instead of taking $restartedPid" }
Write-Host 'lite mode: RoutaMi.exe took the running core back'
Stop-Process -Id $app.Id -Force
Start-Sleep -Seconds 2

Start-Process (Join-Path $dir 'unins000.exe') -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait
Start-Sleep -Seconds 3
if (Get-Service RoutaMiHelperService -ErrorAction SilentlyContinue) { Fail 'uninstall left the helper service' }
Write-Host 'uninstall removed the helper service'
