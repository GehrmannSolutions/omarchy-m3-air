#!/usr/bin/env bash
# Undo install-bootbin-c114.sh: the clamshell boot.bin (730f8718), the pinned sources in
# /usr/local/lib/fay-boot and /etc/default/update-m1n1 as they were before the first install.
set -euo pipefail
CLAMSHELL_BOOTBIN=730f8718a71e4fc789ee526bed53db5ce551d5a0996570fe91e078f5f92653f8
B=$(cat /var/lib/fay-backup/bootbin-c114-LATEST)
[[ -f $B/boot.bin && -f $B/update-m1n1.default && -d $B/fay-boot.previous ]] ||
  { echo "no backup in $B" >&2; exit 1; }
[[ $(sha256sum "$B"/boot.bin | cut -d' ' -f1) == "$CLAMSHELL_BOOTBIN" ]] ||
  { echo "backup boot.bin in $B is not the clamshell boot.bin" >&2; exit 1; }
sudo -v
sudo cp "$B"/boot.bin /boot/m1n1/boot.bin.restore
sudo mv -f /boot/m1n1/boot.bin.restore /boot/m1n1/boot.bin
sudo cp -a "$B"/update-m1n1.default /etc/default/update-m1n1
sudo rm -rf /usr/local/lib/fay-boot
sudo cp -a "$B"/fay-boot.previous /usr/local/lib/fay-boot
sync
cmp -s "$B"/boot.bin /boot/m1n1/boot.bin &&
  echo "restored from $B: boot.bin $(sha256sum /boot/m1n1/boot.bin | cut -c1-16)"
