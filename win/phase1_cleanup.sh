#!/bin/bash
echo "=== before: listeners on 3240 ==="
ss -ltnp 2>/dev/null | grep ':3240' || echo "  (nothing on 3240)"
echo "=== triton-server procs ==="
ps -eo pid,comm 2>/dev/null | grep triton-server || echo "  (none)"
echo "=== WSL vhci ports ==="
/usr/local/bin/usbip port 2>/dev/null | grep -E 'Port [0-9]|usbip://' || echo "  (no imported devices)"
echo "=== detach all WSL vhci ports ==="
for p in $(/usr/local/bin/usbip port 2>/dev/null | grep -oE 'Port [0-9]+' | grep -oE '[0-9]+$'); do
  echo "detach port $p"; /usr/local/bin/usbip detach -p "$p" 2>&1
done
echo "=== kill all triton-server ==="
pkill -9 -x triton-server 2>/dev/null; sleep 1
echo "=== after ==="
ss -ltnp 2>/dev/null | grep ':3240' && echo "  STILL on 3240" || echo "  3240 free in WSL"
ps -eo pid,comm 2>/dev/null | grep triton-server || echo "  no triton-server procs"
