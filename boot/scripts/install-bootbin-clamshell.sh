#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Fay (2026-10-13), Phase 2 of the clamshell work (decision A, device tree):
# agents/fay/plans/2026-10-13-DECISION-phase2-dt.md.
# boot.bin gets J613 device trees whose internal DCP has a (disabled) Type-C
# route to the left-front port, and a second endpoint on that port's port@3.
# Same m1n1, same u-boot, same /etc/m1n1.conf options, same
# /etc/default/update-m1n1 (already pinned to /usr/local/lib/fay-boot); only
# t8122-j613.dtb and t8122-j613-25g83.dtb change, the other 113 DTBs are the
# installed ones.
#
# READ FIRST: kernels without patch "drm: apple: Never let the internal panel's
# Type-C route hold up the panel" (fay-v2, fay-ext2, stock linux-aurora) fail
# to probe the internal DCP with this device tree ("Type-C route container is
# empty"): no appledrm, the panel stays on the boot framebuffer, no external
# display. Only fay-up r7 (or a later kernel with that patch) works with it.
#
# Run by Marius. Undo: uninstall-bootbin-clamshell.sh
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd)
F=$E/bootbin-clamshell
P=/usr/local/lib/fay-boot
OLD_BOOTBIN=64ebdea88510763210829542936a7df5ec32aa977545f25ec6d57eb22aeb4ba3   # front-port boot.bin, installed 2026-10-13 ~12:30
die() { echo "install-bootbin-clamshell: $*" >&2; exit 1; }

# what is there now must be what we expect, and the new files what we built
cur=$(sha256sum /boot/m1n1/boot.bin | cut -d' ' -f1)
[[ $cur == "$OLD_BOOTBIN" ]] || die "/boot/m1n1/boot.bin is not the expected front-port boot.bin ($cur)"
( cd "$F" && sha256sum --quiet -c SHA256SUMS ) || die "bootbin-clamshell does not match its SHA256SUMS"
cmp -s "$F"/m1n1.bin "$P"/m1n1.bin || die "$P/m1n1.bin is not the m1n1 this boot.bin was built with"
grep -q '^M1N1=/usr/local/lib/fay-boot/m1n1.bin$' /etc/default/update-m1n1 &&
  grep -q '^DTBS="/usr/local/lib/fay-boot/dtbs/\*.dtb"$' /etc/default/update-m1n1 ||
  die "/etc/default/update-m1n1 does not pin $P (install-bootbin-front.sh first)"
[[ $(tr -d '\0' < /proc/device-tree/chosen/asahi,efi-system-partition) == \
   $(lsblk -no PARTUUID "$(findmnt -no SOURCE /boot)") ]] || die "/boot is not the system ESP"
(( $(df --output=avail -k /boot | tail -1) > 30000 )) || die "less than 30 MB free in /boot"

cat <<'EOF'
With this boot.bin only kernels with the Phase 2 patch 1 keep appledrm:
  fay-up (7.1.12-fay-up, r7)         works (the kernel to test Phase 2 with)
  fay-daily (fay-v2), fay-daily-ext2,
  linux-aurora                       internal DCP fails to probe: panel on the
                                     boot framebuffer only, no external display
Undo before booting one of those: uninstall-bootbin-clamshell.sh
EOF
read -r -p "Install anyway? Type yes: " answer
[[ $answer == yes ]] || die "not installed"

sudo -v
B=/var/lib/fay-backup/bootbin-clamshell-$(date +%Y%m%d-%H%M%S)
sudo mkdir -p "$B"
sudo cp -a /boot/m1n1/boot.bin "$B"/boot.bin
sudo cp -a /etc/default/update-m1n1 "$B"/update-m1n1.default
sudo cp -a "$P" "$B"/fay-boot.previous
echo "$B" | sudo tee /var/lib/fay-backup/bootbin-clamshell-LATEST >/dev/null

# pinned sources for update-m1n1: the same m1n1, the new DTB set
sudo rm -rf "$P.new"
sudo install -d -m 0755 "$P.new/dtbs"
sudo install -m 0644 "$F"/m1n1.bin "$P.new"/m1n1.bin
sudo install -m 0644 "$F"/dtbs/*.dtb "$P.new"/dtbs/
sudo install -m 0644 "$F"/SHA256SUMS "$P.new"/SHA256SUMS
sudo rm -rf "$P" && sudo mv "$P.new" "$P"

# build and install boot.bin exactly as the pacman hook will
sudo update-m1n1
sync

new=$(sha256sum /boot/m1n1/boot.bin | cut -d' ' -f1)
want=$(grep ' boot.bin$' "$F"/SHA256SUMS | cut -d' ' -f1)
if [[ $new == "$want" ]]; then
  echo "OK: /boot/m1n1/boot.bin is the clamshell boot.bin (${new:0:16}), backup in $B"
else
  echo "MISMATCH: /boot/m1n1/boot.bin is ${new:0:16}, expected ${want:0:16}" >&2
  echo "restore with uninstall-bootbin-clamshell.sh before rebooting" >&2
  exit 1
fi
