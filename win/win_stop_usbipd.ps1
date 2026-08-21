# Elevated: free TCP 3240 for the WSL hid-triton server by stopping the usbipd
# service, and tidy the leftover 2-1 share. Reversible (Start-Service usbipd later).
$log = Join-Path $env:TEMP 'sc_stop.log'
"=== stop usbipd ===" | Set-Content $log
try { Stop-Service -Name usbipd -Force -ErrorAction Stop; "Stop-Service OK" | Add-Content $log }
catch { "Stop-Service failed: $_" | Add-Content $log }
Start-Sleep -Seconds 1
("usbipd status: " + (Get-Service usbipd).Status) | Add-Content $log
$usbipd = Join-Path $env:ProgramFiles 'usbipd-win\usbipd.exe'
(& $usbipd unbind --busid 2-1 2>&1 | Out-String) | Add-Content $log
"=== DONE ===" | Add-Content $log
