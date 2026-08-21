#!/bin/bash
L=/tmp/triton-server.log
echo "server alive pid: $(pgrep -x triton-server | head -1)"
echo "log lines        : $(wc -l < "$L" 2>/dev/null)"
echo "SET_REPORT       : $(grep -c '> SET_REPORT' "$L" 2>/dev/null)"
echo "GET_FEATURE 0x83 : $(grep -c 'last cmd=0x83' "$L" 2>/dev/null)"
echo "interrupt-IN     : $(grep -c '#data requests' "$L" 2>/dev/null)"
echo "distinct SET_REPORT cmds (Steam writes):"
grep '> SET_REPORT' "$L" 2>/dev/null | grep -oE 'cmd=0x[0-9a-f][0-9a-f]' | sort | uniq -c | sort -rn | head
