#!/usr/bin/env bash
# Build a boot blob the way update-m1n1 does, but write it to a staging folder only.
# It does NOT install anything. Installing needs root and an explicit OK from Marius.
#
# Recipe (checked 2026-10-03 against /boot/m1n1/boot.bin, same size, one dtb block differs by 4 bytes):
#   blob = m1n1.bin + dtbs/*.dtb (sorted glob) + gzip -n (u-boot-nodtb.bin) + m1n1 options
set -euo pipefail
OUT="${OUT:-$HOME/.cache/fay-build/bootchain}"
M1N1_BIN="${M1N1_BIN:-$HOME/.cache/fay-build/m1n1/build/m1n1.bin}"   # draft build with t8122 carveout
DTB_DIR="${DTB_DIR:-$OUT/dtbs}"                                       # staged device trees
UBOOT="${UBOOT:-/usr/lib/asahi-boot/u-boot-nodtb.bin}"
mkdir -p "$OUT"
cat "$M1N1_BIN" "$DTB_DIR"/*.dtb > "$OUT/boot.bin.new"
gzip -n -c "$UBOOT" >> "$OUT/boot.bin.new"
echo "staged: $OUT/boot.bin.new ($(stat -c %s "$OUT/boot.bin.new") bytes)"
echo "NOT installed. Original on the system: sha256 566227f96ea94baf..."
