# Elevated, minimal: stop ONLY the usbipd service to free TCP 3240. Does not touch
# any bound device (the real controller is in use by Steam). Reversible: Start-Service usbipd.
$log = Join-Path $env:TEMP 'sc_stop.log'
"=== stop usbipd service (svc only) ===" | Set-Content $log
try { Stop-Service -Name usbipd -Force -ErrorAction Stop; "Stop-Service OK" | Add-Content $log }
catch { "Stop-Service failed: $_" | Add-Content $log }
Start-Sleep -Seconds 1
("usbipd status: " + (Get-Service usbipd).Status) | Add-Content $log
"=== DONE ===" | Add-Content $log
