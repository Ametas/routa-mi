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
foreach ($file in 'RoutaMi.exe', 'RoutaMiCore.exe', 'RoutaMiHelperService.exe', 'libcronet.dll') {
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
# them under %APPDATA%\<CompanyName>\<ProductName>).
$prefsDir = Join-Path $env:APPDATA 'RoutaTerm\RoutaMi'
New-Item -ItemType Directory -Force $prefsDir | Out-Null
@{
  'flutter.version' = 1
  'flutter.config'  = '{"appSettingProps":{"disclaimerAccepted":true,"autoRun":true}}'
} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $prefsDir 'shared_preferences.json')
$app = Start-Process (Join-Path $dir 'RoutaMi.exe') -PassThru
$deadline = (Get-Date).AddSeconds(60)
while (-not (Get-Process RoutaMiCore -ErrorAction SilentlyContinue)) {
  if ($app.HasExited) { Fail "RoutaMi.exe exited with $($app.ExitCode)" }
  if ((Get-Date) -gt $deadline) {
    Get-Process RoutaMi* | Format-Table Id, ProcessName, StartTime | Out-String | Write-Host
    Get-ChildItem -Recurse $prefsDir -ErrorAction SilentlyContinue | Select-Object FullName, Length | Out-String | Write-Host
    Fail 'RoutaMi.exe did not start the core'
  }
  Start-Sleep -Seconds 1
}
$owner = (Get-CimInstance Win32_Process -Filter "Name = 'RoutaMiCore.exe'").ParentProcessId
$parent = (Get-Process -Id $owner -ErrorAction SilentlyContinue).ProcessName
Write-Host "RoutaMi.exe started the core (parent: $parent)"
if ($parent -ne 'RoutaMiHelperService') { Fail 'the core was not started by the helper service' }
Stop-Process -Id $app.Id -Force
Start-Sleep -Seconds 2

Start-Process (Join-Path $dir 'unins000.exe') -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait
Start-Sleep -Seconds 3
if (Get-Service RoutaMiHelperService -ErrorAction SilentlyContinue) { Fail 'uninstall left the helper service' }
Write-Host 'uninstall removed the helper service'
