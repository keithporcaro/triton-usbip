<#
  triton_host_watch.ps1 — host-side auto-(re)attach supervisor for the iPad Triton (Phase 2).

  Launched from the paired client's `do_cmd` at stream start (hidden). It keeps the synthetic
  28DE:1302 attached whenever the iPad's USB/IP server will accept it, and — paired with the iPad's
  BLE readiness gate — gives Steam a REAL connect/disconnect.

  IP DISCOVERY: by the time the do_cmd fires the stream is pure UDP — there is NO client TCP
  connection on the host (verified), so the client IP is read from Apollo's own session-start log
  line `Expecting incoming session connections from <ip>` (written ~1s before this runs). That line
  is Debug-level, so Apollo must log at Debug (min_log_level=Debug).

  LIVENESS: stream-end is detected from Apollo's Info-level `... [active sessions: N]` line (N==0),
  which is logged regardless of Debug, so this half is robust to log level.

  It only attaches when the device is ABSENT, so it never stacks vhci ports. On exit it detaches.
  All activity is logged to $LogPath (the do_cmd launches this hidden, so console output is lost).

  Usage:
    .\triton_host_watch.ps1                       # auto-discover the iPad IP from the Apollo log
    .\triton_host_watch.ps1 -IpadIp 192.168.1.50  # or pass it explicitly
    .\triton_host_watch.ps1 -PollSeconds 1        # attach-retry / liveness cadence (default 1s)

  Pair with `.\triton_host_attach.ps1 -Detach` as the client's `undo_cmd` (cleanup backstop in case
  the watcher is killed abnormally; the watcher already detaches on normal stream end).
#>
param(
  [string]$IpadIp = "",
  [int]$PollSeconds = 1,
  [string]$LogPath = "C:\Users\keith\triton\watch.log",
  [string]$ApolloLogDir = "C:\Program Files\Apollo\config\logs",
  [int]$DiscoverSeconds = 25
)

$usbip = 'C:\Program Files\USBip\usbip.exe'
$apolloPorts = 47984, 47989, 48010, 48011   # only for the start-up diagnostic snapshot

function Log([string]$msg) {
  try { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $msg) -ErrorAction SilentlyContinue } catch {}
}
function Normalize-Ip([string]$addr) {
  if ($addr -match '^::ffff:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$') { return $Matches[1] }
  return $addr
}
function Get-NewestApolloLog {
  Get-ChildItem $ApolloLogDir -Filter 'sunshine-*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
# Current stream client's IP, from Apollo's session-start log line (Debug-level).
function Get-StreamClientIp {
  $log = Get-NewestApolloLog; if (-not $log) { return $null }
  $lines = Get-Content $log.FullName -ErrorAction SilentlyContinue
  $m = $lines | Select-String -Pattern 'Expecting incoming session connections from\s+(\S+)' | Select-Object -Last 1
  if ($m) { return (Normalize-Ip $m.Matches[0].Groups[1].Value) }
  $m = $lines | Select-String -Pattern 'Control peer address \[(.+)\]' | Select-Object -Last 1
  if ($m) { return (Normalize-Ip ($m.Matches[0].Groups[1].Value -replace ':\d+$','')) }
  return $null
}
# Global active-session count from Apollo's Info-level "active sessions: N" line.
# 0 = explicit end; -1 = no recent count line (treat as still-active, e.g. long session).
function Get-ActiveSessions {
  $log = Get-NewestApolloLog; if (-not $log) { return -1 }
  $m = Get-Content $log.FullName -Tail 400 -ErrorAction SilentlyContinue |
       Select-String -Pattern 'active sessions:\s*(\d+)' | Select-Object -Last 1
  if ($m) { return [int]$m.Matches[0].Groups[1].Value }
  return -1
}
function Test-TritonPresent {
  return [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
                Where-Object { $_.InstanceId -like '*VID_28DE&PID_1302*' })
}

if (-not (Test-Path $usbip)) { Log "FATAL: usbip-win2 not found at $usbip"; return }
Log "=== watcher start (poll ${PollSeconds}s, discover ${DiscoverSeconds}s) pid=$PID ==="

# Diagnostic: confirm whether ANY client TCP exists on the Apollo ports at do_cmd time (expected: none).
$snap = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object { $apolloPorts -contains $_.LocalPort }
Log ("apollo-port TCP @start: [" + (($snap | ForEach-Object { "$($_.RemoteAddress)->L$($_.LocalPort)" }) -join ", ") + "]")

# IP discovery from the Apollo log (poll briefly in case the do_cmd beats the log flush).
if (-not $IpadIp) {
  $deadline = (Get-Date).AddSeconds($DiscoverSeconds)
  while (-not $IpadIp -and (Get-Date) -lt $deadline) {
    $IpadIp = Get-StreamClientIp
    if (-not $IpadIp) { Start-Sleep -Milliseconds 250 }
  }
}
if (-not $IpadIp) { Log "discovery FAILED: no client IP in Apollo log (is min_log_level=Debug?). Exiting."; return }
Log "discovered iPad IP = $IpadIp (from Apollo log)"

try {
  while ($true) {
    $active = Get-ActiveSessions
    if ($active -eq 0) { Log "Apollo reports active sessions: 0; stream ended."; break }
    if (-not (Test-TritonPresent)) {
      $r = (& $usbip attach -r $IpadIp -b 1-1 --once *>&1) -join ' '
      Log "tick: triton=ABSENT active=$active attach-> $r"
    } else {
      Log "tick: triton=present active=$active"
    }
    Start-Sleep -Seconds $PollSeconds
  }
}
finally {
  & $usbip detach -a *> $null
  Log "detached all USB/IP ports. === watcher end ==="
}
