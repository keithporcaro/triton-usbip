#!/bin/bash
# start|stop|log the refactored Voidlink triton-server (Tier-1 canned-feed) in WSL.
DIR=/home/keith/dev/steamcontroller-test/Voidlink/VoidLink/Triton/usbip
case "$1" in
  start)
    cd "$DIR" || exit 1
    pkill -9 -x triton-server 2>/dev/null; sleep 0.5
    rm -f /tmp/triton-server.log
    setsid ./triton-server >/tmp/triton-server.log 2>&1 </dev/null &
    sleep 1
    PID=$(pgrep -x triton-server | head -1)   # setsid forks: find the real pid
    if [ -n "$PID" ] && ss -ltn 2>/dev/null | grep -q ':3240'; then
      echo "started triton-server pid=$PID, listening on :3240"
    else
      echo "FAILED to start / not listening:"; cat /tmp/triton-server.log
    fi
    ;;
  stop) pkill -x triton-server 2>/dev/null; echo "stopped triton-server" ;;
  log)  cat /tmp/triton-server.log 2>/dev/null ;;
esac
