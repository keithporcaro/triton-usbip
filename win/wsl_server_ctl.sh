#!/bin/bash
# Control a lcgamboa USB/IP server in the background within the persistent WSL distro.
# usage: wsl_server_ctl.sh start <bin> | stop <bin> | log <bin> | status <bin>
CMD="$1"; SRV="$2"
DIR=/home/keith/dev/steamcontroller-test/tools/triton-usbip/c
case "$CMD" in
  start)
    cd "$DIR" || exit 1
    pkill -x "$SRV" 2>/dev/null; sleep 0.3
    rm -f "/tmp/$SRV.log"
    setsid ./"$SRV" >"/tmp/$SRV.log" 2>&1 </dev/null &
    echo $! >"/tmp/$SRV.pid"
    sleep 1
    if kill -0 "$(cat /tmp/$SRV.pid)" 2>/dev/null; then
      echo "started $SRV pid=$(cat /tmp/$SRV.pid) on :3240"
    else
      echo "FAILED to start $SRV:"; cat "/tmp/$SRV.log"
    fi
    ;;
  stop)   pkill -x "$SRV" 2>/dev/null; echo "stopped $SRV" ;;
  log)    cat "/tmp/$SRV.log" 2>/dev/null ;;
  status) if kill -0 "$(cat /tmp/$SRV.pid 2>/dev/null)" 2>/dev/null; then echo "$SRV running pid=$(cat /tmp/$SRV.pid)"; else echo "$SRV not running"; fi ;;
esac
