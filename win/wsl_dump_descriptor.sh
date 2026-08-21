#!/bin/bash
# Dump the usbip-attached Steam Controller's descriptors (run as root in WSL).
set +e
echo "=== waiting for 28de:1302 to enumerate in WSL ==="
DEV=""
for i in $(seq 1 30); do
  DEV=$(lsusb -d 28de:1302 2>/dev/null | head -1)
  [ -n "$DEV" ] && break
  sleep 0.5
done
echo "lsusb: ${DEV:-<not found>}"
echo
echo "=== usbip port ==="
/usr/local/bin/usbip port 2>/dev/null
echo
echo "=== sysfs report_descriptor (od -tx1) ==="
shopt -s nullglob
found=0
for RD in /sys/bus/usb/devices/*/[0-9]*:28DE:1302.*/report_descriptor; do
  found=1
  echo "FILE: $RD"
  SIZE=$(stat -c %s "$RD" 2>/dev/null)
  echo "SIZE: $SIZE bytes"
  od -An -tx1 -v "$RD" | tr -s ' ' | sed 's/^ //'
  echo "---"
done
[ "$found" = 0 ] && echo "(no report_descriptor found in sysfs)"
echo
echo "=== usbhid-dump (raw report descriptor) ==="
usbhid-dump -d 28de:1302 2>&1
echo
echo "=== lsusb -v (parsed) ==="
lsusb -v -d 28de:1302 2>/dev/null
