#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Builds an m1n1 stage-2 boot.bin exactly as /usr/bin/update-m1n1 does
# (m1n1.bin + DTBs + gzipped u-boot + the chosen.*/display=/mitigations= lines
# of /etc/m1n1.conf), writing only to OUT. Needs no root.
#
# Why not "update-m1n1 OUT" with DTBS=...: update-m1n1 sources
# /etc/default/update-m1n1, which on this machine (aurora-sep) sets DTBS to the
# linux-aurora package's DTBs unconditionally, so a DTBS from the environment
# is ignored and the result would carry the stock DTBs.
#
# usage: build-bootbin.sh M1N1_BIN OUT DTB...
set -euo pipefail
M1N1=$1; OUT=$2; shift 2
CONFIG=${CONFIG:-/etc/m1n1.conf}
UBOOT=${UBOOT:-/usr/lib/asahi-boot/u-boot-nodtb.bin}
(($#)) || { echo "no DTBs given" >&2; exit 1; }
cfg=$(mktemp); trap 'rm -f "$cfg"' EXIT
if [[ -e $CONFIG ]]; then
  while read line; do
    case "$line" in
      "") ;;
      \#*) ;;
      chosen.*=*|display=*|mitigations=*) echo "$line" >>"$cfg"; echo "  option: $line" >&2 ;;
      *) echo "  ignoring unknown option: $line" >&2 ;;
    esac
  done <"$CONFIG"
fi
{ cat "$M1N1" "$@"; gzip -c "$UBOOT"; cat "$cfg"; } >"$OUT.new"
mv -f "$OUT.new" "$OUT"
echo "built $OUT ($(stat -c %s "$OUT") bytes, $# DTBs)" >&2
