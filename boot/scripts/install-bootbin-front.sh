#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Fay (2026-10-13), decision A in agents/fay/plans/2026-10-13-DECISION-boot-dt.md:
# 1. boot.bin gets the J613 device trees with the left-front USB-C port (dcpext
#    route@1, ATC1 crossbar). Same m1n1, same u-boot, same /etc/m1n1.conf
#    options; the other 113 DTBs and everything else unchanged.
# 2. /etc/default/update-m1n1 pins m1n1 and the DTBs to /usr/local/lib/fay-boot,
#    so that the pacman hook (95-m1n1-install.hook) rebuilds this same boot.bin
#    on a linux-aurora or asahi-boot update instead of the stock one without
#    dcpext.
# Run by Marius. Undo: uninstall-bootbin-front.sh
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd)
F=$E/bootbin-front
P=/usr/local/lib/fay-boot
OLD_BOOTBIN=56d282f89121930275299794ff1a799a8c6beb2c2c079beca98153f749614b4d   # boot.bin.ext, installed 2026-10-12 00:45
die() { echo "install-bootbin-front: $*" >&2; exit 1; }

# what is there now must be what we expect, and the new files what we built
cur=$(sha256sum /boot/m1n1/boot.bin | cut -d' ' -f1)
[[ $cur == "$OLD_BOOTBIN" ]] || die "/boot/m1n1/boot.bin is not the expected boot.bin.ext ($cur...)"
( cd "$F" && sha256sum --quiet -c SHA256SUMS ) || die "bootbin-front does not match its SHA256SUMS"
[[ $(tr -d '\0' < /proc/device-tree/chosen/asahi,efi-system-partition) == \
   $(lsblk -no PARTUUID "$(findmnt -no SOURCE /boot)") ]] || die "/boot is not the system ESP"
(( $(df --output=avail -k /boot | tail -1) > 30000 )) || die "less than 30 MB free in /boot"

sudo -v
B=/var/lib/fay-backup/bootbin-front-$(date +%Y%m%d-%H%M%S)
sudo mkdir -p "$B"
sudo cp -a /boot/m1n1/boot.bin "$B"/boot.bin
sudo cp -a /etc/default/update-m1n1 "$B"/update-m1n1.default
[[ -e $P ]] && sudo cp -a "$P" "$B"/fay-boot.previous
echo "$B" | sudo tee /var/lib/fay-backup/bootbin-front-LATEST >/dev/null

# pinned sources for update-m1n1
sudo rm -rf "$P.new"
sudo install -d -m 0755 "$P.new/dtbs"
sudo install -m 0644 "$F"/m1n1.bin "$P.new"/m1n1.bin
sudo install -m 0644 "$F"/dtbs/*.dtb "$P.new"/dtbs/
sudo install -m 0644 "$F"/SHA256SUMS "$P.new"/SHA256SUMS
sudo rm -rf "$P" && sudo mv "$P.new" "$P"

sudo tee /etc/default/update-m1n1 >/dev/null <<'EOF'
# Fay (2026-10-13): m1n1 and the device trees are pinned to the Fay build, so
# that a package update rebuilds the boot.bin with dcpext and both USB-C display
# routes (J613). The stock linux-aurora DTBs have no dcpext.
# Undo: ~/.cache/fay-build/aurora/ext/uninstall-bootbin-front.sh
# Previous content (aurora-sep) is in /var/lib/fay-backup/bootbin-front-*/update-m1n1.default
M1N1=/usr/local/lib/fay-boot/m1n1.bin
DTBS="/usr/local/lib/fay-boot/dtbs/*.dtb"
EOF

# build and install boot.bin exactly as the pacman hook will
sudo update-m1n1
sync

new=$(sha256sum /boot/m1n1/boot.bin | cut -d' ' -f1)
want=$(grep ' boot.bin$' "$F"/SHA256SUMS | cut -d' ' -f1)
if [[ $new == "$want" ]]; then
  echo "OK: /boot/m1n1/boot.bin is the new boot.bin (${new:0:16}), backup in $B"
else
  echo "MISMATCH: /boot/m1n1/boot.bin is ${new:0:16}, expected ${want:0:16}" >&2
  echo "restore with uninstall-bootbin-front.sh before rebooting" >&2
  exit 1
fi
