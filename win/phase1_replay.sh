#!/bin/bash
# Start the Tier-1 replay server (feeds the captured frozen-IMU controller frame through the
# real queue). Arg: 'fix' (default, IMU zeroed) or 'nofix' (IMU passed through, for A/B).
DIR=/home/keith/dev/steamcontroller-test/Voidlink/VoidLink/Triton/usbip
cd "$DIR" || exit 1
pkill -9 -x triton-server 2>/dev/null; pkill -9 -x triton-server-nofix 2>/dev/null; sleep 0.5
BIN=triton-server
[ "$1" = "nofix" ] && BIN=triton-server-nofix
rm -f /tmp/triton-replay.log
setsid ./"$BIN" --replay >/tmp/triton-replay.log 2>&1 </dev/null &
sleep 1
if pgrep -x "$BIN" >/dev/null && ss -ltn 2>/dev/null | grep -q ':3240'; then
  echo "started $BIN --replay, listening on :3240"
else
  echo "FAILED:"; cat /tmp/triton-replay.log
fi
