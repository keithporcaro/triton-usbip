#!/bin/bash
echo "=== [1] usbip/attach/triton processes (the phantom?) ==="
ps -eo pid,comm,args 2>/dev/null | grep -iE 'usbip|triton-server' | grep -v grep || echo "  (none)"
echo "=== [2] kill by EXACT name (no -f, avoids self-kill) ==="
pkill -9 -x triton-server 2>/dev/null
pkill -9 -x usbip 2>/dev/null
sleep 0.6
echo "=== [3] vhci status header + nonzero ports ==="
sed -n '1,3p' /sys/devices/platform/vhci_hcd.0/status 2>/dev/null
echo "=== [4] start ONE server, monitor 5s in isolation ==="
cd /home/keith/dev/steamcontroller-test/Voidlink/VoidLink/Triton/usbip || exit 1
rm -f /tmp/triton-server.log
setsid ./triton-server >/tmp/triton-server.log 2>&1 </dev/null &
for i in 1 2 3 4 5; do
  sleep 1
  alive=$(pgrep -x triton-server | head -1)
  listen=$(ss -ltn 2>/dev/null | grep -c ':3240')
  estab=$(ss -tn state established 2>/dev/null | grep -c ':3240')
  echo "  t=${i}s server=${alive:-DEAD} listen=$listen established=$estab"
done
echo "=== [5] server log: lines + tail ==="
wc -l /tmp/triton-server.log 2>/dev/null
tail -4 /tmp/triton-server.log 2>/dev/null
