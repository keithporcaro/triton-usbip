#!/bin/bash
# Tier-1 regression: attach the REFACTORED, queue-fed Voidlink triton-server to the local
# Linux USB stack over loopback and confirm it enumerates identically to Phase 0, and that
# the canned-feed-through-the-queue 0x42 state reports actually reach a hidraw consumer.
# Run as root in WSL with TCP 3240 free (usbipd stopped).
set +e
DIR=/home/keith/dev/steamcontroller-test/Voidlink/VoidLink/Triton/usbip
cd "$DIR" || exit 1

echo "=== vhci_hcd ==="; modprobe vhci_hcd 2>&1; echo "(rc=$?)"
echo "=== start refactored triton-server (queue-fed) ==="
pkill -x triton-server 2>/dev/null; sleep 0.3
rm -f /tmp/triton-server.log
setsid ./triton-server >/tmp/triton-server.log 2>&1 </dev/null &
SRV=$!
sleep 1
if ! kill -0 "$SRV" 2>/dev/null; then echo "SERVER DIED:"; cat /tmp/triton-server.log; exit 1; fi
echo "server pid=$SRV"

echo "=== usbip list -r 127.0.0.1 ==="
/usr/local/bin/usbip list -r 127.0.0.1 2>&1
echo "=== attach -r 127.0.0.1 -b 1-1 ==="
/usr/local/bin/usbip attach -r 127.0.0.1 -b 1-1 2>&1; echo "(rc=$?)"
sleep 2

echo "=== lsusb (expect 28de:1302 Valve) ==="
lsusb -d 28de:1302 2>&1
echo "=== dmesg tail ==="
dmesg 2>/dev/null | tail -14
echo "=== report_descriptor size ==="
for RD in /sys/bus/usb/devices/*/[0-9]*:28DE:1302.*/report_descriptor; do
  [ -e "$RD" ] && echo "$RD -> $(od -An -tx1 -v "$RD" | wc -w) bytes"
done

echo "=== hidraw peek: proves queue-fed 0x42 state reaches the host (LSX should sweep) ==="
HR=$(ls -t /dev/hidraw* 2>/dev/null | head -1)
echo "reading $HR for ~1.5s ..."
timeout 1.5 dd if="$HR" bs=64 count=4 2>/dev/null | od -An -tx1 | head -6

echo "=== detach + stop ==="
/usr/local/bin/usbip detach -p 00 2>&1; echo "(rc=$?)"
sleep 1
kill "$SRV" 2>/dev/null
echo "=== server log: control-transfer trace (enumeration) ==="
grep -E 'Device|Configuration|String|handle_get_descriptor|GET_DESCRIPTOR|SET_REPORT|GET_FEATURE|on :3240' /tmp/triton-server.log | head -40
