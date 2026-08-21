#!/bin/bash
# Commit the Phase-1 Triton C core into Voidlink's repo on a dedicated feature branch.
set -e
cd /home/keith/dev/steamcontroller-test/Voidlink || exit 1
git switch -c triton-steam-controller 2>/dev/null || git switch triton-steam-controller
git add VoidLink/Triton
echo "=== staged ==="
git status --short VoidLink/Triton
git commit -q -m "Triton USB/IP emulator core (Phase 1 Tier-1): vendored+ported C, BLE->USB queue" \
  -m "Ports the Phase-0-GREEN USB/IP Steam-Controller emulator into Voidlink/VoidLink/Triton/usbip:" \
  -m "- usbip.{c,h}: platform gates widened for __APPLE__, exit()->return, usbip_run made start/stoppable (usbip_stop)." \
  -m "- triton_device.c (from hid-triton.c): interrupt-IN now pops from triton_input_queue; SET_REPORT/interrupt-OUT forward to a write sink (BLE on iOS); synthetic GET_ATTRIBUTES/echo responder kept verbatim; main() removed." \
  -m "- triton_input_queue.{c,h}: NEW BLE->USB seam (0x45/45B -> 0x42/53B, latest-wins, pthread). Unit-tested." \
  -m "- triton_main.c + Makefile: Tier-1 standalone harness (excluded from Xcode)." \
  -m "Verified on WSL: builds clean, queue unit test PASS, descriptor bytes byte-identical to the genuine capture, and the refactored queue-fed server enumerates on a real kernel with the swept 0x42 state reaching /dev/hidraw0." \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
echo "=== result ==="
git log --oneline -1
git rev-parse --abbrev-ref HEAD
