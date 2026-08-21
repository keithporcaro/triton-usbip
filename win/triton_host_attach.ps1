<#
  triton_host_attach.ps1 — Windows host side of the iPad Triton test.

  Run this on the Apollo host WHILE a stream from the iPad (Voidlink) is active. Voidlink starts
  the synthetic Triton USB/IP server on the iPad's :3240 when the stream connects; this script
  attaches it with usbip-win2 so Windows enumerates 28DE:1302 and Steam claims it.

  No controller required for a SMOKE TEST: with no Steam Controller paired to the iPad, the server
  serves a neutral 0x42 report, so Steam should still claim the controller (centered/no movement).
  Plug in the real controller (paired in iPad Settings) later to see live input.

  Usage:
    .\triton_host_attach.ps1                 # auto-discover the iPad IP from the active stream, attach
    .\triton_host_attach.ps1 -IpadIp 192.168.1.50   # explicit iPad IP
    .\triton_host_attach.ps1 -Detach         # detach all (run on stream end)

  Note: usbipd (the WSL-sharer) may stay running — it listens on :3240 locally; this script
  connects OUT to the iPad, so there is no port conflict.
#>
param([string]$IpadIp = "", [switch]$Detach)

$usbip = 'C:\Program Files\USBip\usbip.exe'
if (-not (Test-Path $usbip)) { Write-Host "usbip-win2 not found at $usbip"; return }

if ($Detach) { & $usbip detach -a; Write-Host "detached all USB/IP ports"; return }

if (-not $IpadIp) {
    # Discover the streaming client (iPad) from active connections to Apollo/Moonlight ports.
    $apolloPorts = 47984,47989,48010,48011
    $conns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
             Where-Object { $apolloPorts -contains $_.LocalPort -and $_.RemoteAddress -notmatch '^(127\.|::1|0\.0\.0\.0)' }
    $IpadIp = $conns | Group-Object RemoteAddress | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name
    if ($IpadIp) { Write-Host "Discovered streaming client (iPad) IP: $IpadIp" }
}
if (-not $IpadIp) {
    Write-Host "Could not auto-discover the iPad IP. Start a stream first, or pass -IpadIp <addr>."
    Write-Host "(Find it in iPad Settings -> Wi-Fi, or in Apollo's web UI under connected clients.)"
    return
}

Write-Host "iPad $IpadIp reachable on :3240 ? " -NoNewline
$ok = (Test-NetConnection -ComputerName $IpadIp -Port 3240 -WarningAction SilentlyContinue).TcpTestSucceeded
Write-Host $ok
if (-not $ok) {
    Write-Host "Not reachable. Is the iPad streaming (so Voidlink's server is up) and on this LAN?"
    return
}

Write-Host "Attaching..."
& $usbip attach -r $IpadIp -b 1-1 --once
Start-Sleep -Seconds 3
Write-Host "=== Windows enumeration of the synthetic Triton ==="
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like '*VID_28DE&PID_1302*' } |
    Format-Table -Auto Status, Class, FriendlyName | Out-String -Width 160
Write-Host "Now open Steam -> Settings -> Controller. (.\triton_host_attach.ps1 -Detach to remove.)"
