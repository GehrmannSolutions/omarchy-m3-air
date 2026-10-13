#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Undo install-bootbin-clamshell.sh: the front-port boot.bin, the pinned
# sources in /usr/local/lib/fay-boot and /etc/default/update-m1n1 as they were.
set -euo pipefail
B=$(cat /var/lib/fay-backup/bootbin-clamshell-LATEST)
[[ -f $B/boot.bin && -f $B/update-m1n1.default && -d $B/fay-boot.previous ]] ||
  { echo "no backup in $B" >&2; exit 1; }
sudo -v
sudo cp "$B"/boot.bin /boot/m1n1/boot.bin.restore
sudo mv -f /boot/m1n1/boot.bin.restore /boot/m1n1/boot.bin
sudo cp -a "$B"/update-m1n1.default /etc/default/update-m1n1
sudo rm -rf /usr/local/lib/fay-boot
sudo cp -a "$B"/fay-boot.previous /usr/local/lib/fay-boot
sync
cmp -s "$B"/boot.bin /boot/m1n1/boot.bin &&
  echo "restored from $B: boot.bin $(sha256sum /boot/m1n1/boot.bin | cut -c1-16)"
