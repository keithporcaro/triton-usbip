#!/bin/bash
# Local USB/IP sanity attach in WSL (Task 2 Step 4): run hid-triton, attach it to
# this kernel's vhci over loopback, and confirm it enumerates with the genuine
# descriptor. Run as root in WSL. Assumes TCP 3240 is free (usbipd stopped).
set +e
cd /home/keith/dev/steamcontroller-test/tools/triton-usbip/c || exit 1

echo "=== vhci_hcd (builtin) ==="
modprobe vhci_hcd 2>&1; echo "(modprobe rc=$? — builtin is fine)"

echo "=== start hid-triton server ==="
rm -f /tmp/hid-triton.log
./hid-triton > /tmp/hid-triton.log 2>&1 &
SRV=$!
sleep 1
if ! kill -0 "$SRV" 2>/dev/null; then echo "SERVER DIED:"; cat /tmp/hid-triton.log; exit 1; fi
echo "server pid=$SRV"

echo "=== usbip list -r 127.0.0.1 ==="
/usr/local/bin/usbip list -r 127.0.0.1 2>&1

echo "=== usbip attach -r 127.0.0.1 -b 1-1 ==="
/usr/local/bin/usbip attach -r 127.0.0.1 -b 1-1 2>&1; echo "attach rc=$?"
sleep 2

echo "=== lsusb (expect 28de:1302 Valve) ==="
lsusb -d 28de:1302 2>&1

echo "=== /usr/local/bin/usbip port ==="
/usr/local/bin/usbip port 2>&1 | head -6

echo "=== synthetic report_descriptor (expect 372 content bytes) ==="
for RD in /sys/bus/usb/devices/*/[0-9]*:28DE:1302.*/report_descriptor; do
  [ -e "$RD" ] || continue
  echo "$RD"
  od -An -tx1 -v "$RD" | tr -s ' ' | head -3
  echo "  total bytes: $(od -An -tx1 -v "$RD" | wc -w)"
done

echo "=== dmesg tail (enumeration / hid) ==="
dmesg 2>/dev/null | tail -18

echo "=== detach ==="
/usr/local/bin/usbip detach -p 00 2>&1; echo "detach rc=$?"
sleep 1
kill "$SRV" 2>/dev/null

echo "=== hid-triton control-transfer log during enumeration ==="
cat /tmp/hid-triton.log
