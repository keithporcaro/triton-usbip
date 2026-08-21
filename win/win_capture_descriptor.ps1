# Elevated orchestrator: bind+attach the Steam Controller (busid 2-1) into WSL,
# dump its HID report descriptor, then detach+unbind to return it to Windows.
# Launched via Start-Process -Verb RunAs. All output -> $env:TEMP\sc_capture.log
$ErrorActionPreference = 'Continue'
$log = Join-Path $env:TEMP 'sc_capture.log'
"=== sc descriptor capture (elevated) ===" | Set-Content $log
$usbipd = Join-Path $env:ProgramFiles 'usbipd-win\usbipd.exe'
function L($m) { $m | Add-Content $log }

L "[1] bind --busid 2-1"
(& $usbipd bind --busid 2-1 2>&1 | Out-String) | Add-Content $log
L "bind exit=$LASTEXITCODE"

L "[2] attach --wsl --busid 2-1"
(& $usbipd attach --wsl --busid 2-1 2>&1 | Out-String) | Add-Content $log
L "attach exit=$LASTEXITCODE"

Start-Sleep -Seconds 3

L "[3] WSL descriptor dump"
$dump = (& wsl.exe -u root -e bash -c "tr -d '\r' < /home/keith/dev/steamcontroller-test/tools/triton-usbip/win/wsl_dump_descriptor.sh | bash" 2>&1 | Out-String)
$dump | Add-Content $log

L "[4] detach --busid 2-1"
(& $usbipd detach --busid 2-1 2>&1 | Out-String) | Add-Content $log
L "detach exit=$LASTEXITCODE"

L "[5] unbind --busid 2-1"
(& $usbipd unbind --busid 2-1 2>&1 | Out-String) | Add-Content $log
L "unbind exit=$LASTEXITCODE"

L "=== DONE ==="
