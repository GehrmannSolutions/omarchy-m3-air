#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Undo install-bootbin-front.sh: previous boot.bin and /etc/default/update-m1n1 back,
# pinned sources in /usr/local/lib/fay-boot removed (or the previous ones restored).
set -euo pipefail
B=$(cat /var/lib/fay-backup/bootbin-front-LATEST)
[[ -f $B/boot.bin && -f $B/update-m1n1.default ]] || { echo "no backup in $B" >&2; exit 1; }
sudo -v
sudo cp "$B"/boot.bin /boot/m1n1/boot.bin.restore
sudo mv -f /boot/m1n1/boot.bin.restore /boot/m1n1/boot.bin
sudo cp -a "$B"/update-m1n1.default /etc/default/update-m1n1
sudo rm -rf /usr/local/lib/fay-boot
[[ -e $B/fay-boot.previous ]] && sudo cp -a "$B"/fay-boot.previous /usr/local/lib/fay-boot
sync
cmp -s "$B"/boot.bin /boot/m1n1/boot.bin && echo "restored from $B: boot.bin $(sha256sum /boot/m1n1/boot.bin | cut -c1-16)"
