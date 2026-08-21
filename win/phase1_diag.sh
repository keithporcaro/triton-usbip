#!/bin/bash
echo "=== triton-server processes ==="
ps -eo pid,ppid,comm,etimes 2>/dev/null | grep -E 'triton-server|PID' | grep -v grep
echo "=== ALL sockets on :3240 (listen + established, with peer) ==="
ss -tnap 2>/dev/null | grep ':3240' || echo "  (no :3240 sockets)"
echo "=== WSL vhci imported devices ==="
/usr/local/bin/usbip port 2>/dev/null | grep -E 'Port [0-9]|usbip://|remote' || echo "  (none)"
