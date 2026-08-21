#!/bin/bash
# Install usbip userspace in WSL (no Windows admin needed). Idempotent.
set -e
export DEBIAN_FRONTEND=noninteractive
echo "--- apt-get update ---"
apt-get update -qq 2>&1 | tail -2 || true
echo "--- install linux-tools-virtual hwdata ---"
apt-get install -y -qq linux-tools-virtual hwdata 2>&1 | tail -5 || true
echo "--- locate usbip binary ---"
UB=$(ls /usr/lib/linux-tools/*/usbip 2>/dev/null | head -1)
if [ -n "$UB" ]; then
  ln -sf "$UB" /usr/local/bin/usbip
  echo "linked $UB -> /usr/local/bin/usbip"
else
  echo "ERROR: usbip binary not found under /usr/lib/linux-tools"
fi
echo "--- usbip version ---"
/usr/local/bin/usbip version 2>&1 || true
echo "--- usbhid-dump / lsusb ---"
command -v usbhid-dump lsusb || true
