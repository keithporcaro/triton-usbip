# Elevated: record Secure Boot / testsigning state, install usbip-win2, re-check.
# Constraint 2: Secure Boot must stay ON and no testsigning must be required.
$log = Join-Path $env:TEMP 'sc_install.log'
"=== usbip-win2 install ===" | Set-Content $log
function Add-Log($m) { ($m | Out-String).TrimEnd() | Add-Content $log }

"--- Secure Boot BEFORE ---" | Add-Content $log
try { Add-Log ("Confirm-SecureBootUEFI = " + (Confirm-SecureBootUEFI)) } catch { Add-Log "SecureBoot err: $_" }
"--- testsigning BEFORE (empty = good) ---" | Add-Content $log
Add-Log (bcdedit /enum '{current}' | Select-String -Pattern 'testsigning')

"--- running installer (complete the GUI) ---" | Add-Content $log
$exe = Join-Path $env:TEMP 'USBip-0.9.7.7-x64.exe'
$p = Start-Process $exe -Wait -PassThru
Add-Log "installer exit code = $($p.ExitCode)"
Start-Sleep -Seconds 2

"--- Secure Boot AFTER ---" | Add-Content $log
try { Add-Log ("Confirm-SecureBootUEFI = " + (Confirm-SecureBootUEFI)) } catch { Add-Log "SecureBoot err: $_" }
"--- testsigning AFTER (empty = good) ---" | Add-Content $log
Add-Log (bcdedit /enum '{current}' | Select-String -Pattern 'testsigning')

"--- install location + usbip.exe ---" | Add-Content $log
foreach ($d in @("$env:ProgramFiles\USBip","$env:ProgramFiles\usbip-win2","$env:ProgramFiles\usbipd-win2")) {
  if (Test-Path $d) { Add-Log "DIR $d"; Add-Log (Get-ChildItem $d -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -Expand Name) }
}
"--- usbip vhci driver registered? ---" | Add-Content $log
Add-Log (pnputil /enum-drivers | Select-String -Pattern 'usbip','vhci' -Context 1,5)
"--- usbip-related services ---" | Add-Content $log
Add-Log (Get-Service | Where-Object { $_.Name -like '*usbip*' -or $_.Name -like '*vhci*' } | Format-Table -Auto Name,Status,DisplayName)
"=== DONE ===" | Add-Content $log
