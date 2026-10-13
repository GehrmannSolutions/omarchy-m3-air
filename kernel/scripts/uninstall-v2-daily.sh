#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Undo install-v2-daily.sh: fay-daily boots fay-ext2 again; the fay-v2 kernel, initramfs,
# modules and mkinitcpio snippet are removed. Run from a kernel other than fay-v2.
set -euo pipefail
die() { echo "uninstall-v2-daily: $*" >&2; exit 1; }
KVER=7.1.12-fay-v2
[[ $(uname -r) != "$KVER" ]] || die "$KVER is the running kernel; boot fay-daily-ext2 first"
B=$(cat /var/lib/fay-backup/v2-daily-LATEST)
[[ -f $B/44_fay_daily ]] || die "no backup in $B"
sudo -v
sudo cp -a "$B"/44_fay_daily /etc/grub.d/44_fay_daily
sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || die "grub-mkconfig failed"
sudo rm -f /boot/vmlinuz-linux-aurora-fay-v2 /boot/initramfs-linux-aurora-fay-v2.img /etc/mkinitcpio.conf.d/zz-fay-v2.conf
sudo rm -rf "/usr/lib/modules/$KVER"
sudo awk "/menuentry_id_option 'fay-daily' /{p=1} p&&/^\s*linux/{print; exit}" /boot/grub/grub.cfg | grep -o 'vmlinuz-[^ ]*'
df -h /boot | tail -1
echo "restored fay-daily from $B"
