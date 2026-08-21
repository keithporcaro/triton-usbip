#!/bin/bash
# Condense the huge hid-triton gate log into a committable record.
L=/tmp/hid-triton.log
O=/home/keith/dev/steamcontroller-test/docs/superpowers/captures/0b-steam-hid-triton-log.txt
[ -f "$L" ] || { echo "no $L"; exit 1; }
{
  echo "# hid-triton control-transfer log during the Steam gate (condensed from full run)"
  echo
  echo "## counts (whole run)"
  echo "GET_FEATURE/GET_REPORT : $(grep -c 'GET_FEATURE/GET_REPORT' "$L")"
  echo "SET_REPORT             : $(grep -c '> SET_REPORT' "$L")"
  echo "interrupt-IN polls     : $(grep -c '#data requests' "$L")"
  echo "INTR-OUT               : $(grep -c 'INTR-OUT' "$L")"
  echo
  echo "## distinct control transfers (first-seen order)"
  grep '^CTRL ' "$L" | awk '!seen[$0]++'
  echo
  echo "## distinct SET_REPORT payloads Steam wrote (feature 0x01 commands)"
  grep '> SET_REPORT' "$L" | sed 's/   *<==.*//' | awk '!seen[$0]++'
  echo
  echo "## first 60 lines (enumeration + start of Steam init handshake)"
  head -60 "$L"
} > "$O"
echo "wrote $O ($(wc -l < "$O") lines)"
