#!/bin/bash
set -e
ROOT=/home/keith/dev/steamcontroller-test

echo "=== Voidlink repo (branch triton-steam-controller): logging gate ==="
cd "$ROOT/Voidlink"
git add VoidLink/Triton/usbip/usbip.c
git commit -q -m "Triton: gate usbip.c per-URB logging behind TRITON_VERBOSE" \
  -m "The lcgamboa core printed ~13 lines per interrupt-IN URB (1.6M polls -> 21M-line log on a live Steam stream). Silence usbip.c unless TRITON_VERBOSE; triton_device.c keeps its low-volume control-transfer trace. Tier-1 Steam GREEN-parity confirmed with the refactored queue-fed server." \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
git log --oneline -1

echo "=== root repo (branch phase0-bench-scaffold): plan + Phase-1 helper scripts ==="
cd "$ROOT"
git add docs/superpowers/plans/2026-06-07-phase1-voidlink-ipad-port.md tools/triton-usbip/win/
git commit -q -m "phase1: plan doc + Tier-1 helpers; Steam GREEN-parity confirmed for the queue-fed Voidlink port" \
  -m "Phase-1 design/plan from the multi-agent code map (decision: keep SDL2, hand-write the BLE bridge). Adds WSL helper scripts to build/serve/regression-test the refactored Voidlink triton-server, which enumerates on a real kernel AND Steam claims + renders the swept 0x42 (parity with Phase-0 b256da5). The Phase-1 C core itself lives in the Voidlink repo." \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
git log --oneline -1
