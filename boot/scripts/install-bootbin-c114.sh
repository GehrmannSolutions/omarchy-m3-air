#!/usr/bin/env bash
# Fay (2026-10-14): test boot.bin for Phase 2 consolidated on omacom/linux-aurora#114
# (plan: agents/fay/plans/2026-10-14-PLAN-phase2-consolidation.md):
#   our m1n1 (0dc65ef9, sets apple,t8122-dcpext-firmware-ready) + the DTBs built from
#   fay/aurora-j613-clamshell-on-114 (#114 + P1-P6). Built by build-bootbin-c114.sh.
#
# Same u-boot, same /etc/m1n1.conf options; /etc/default/update-m1n1 stays pinned to
# /usr/local/lib/fay-boot, whose m1n1.bin and DTBs this replaces.
#
# READ FIRST: these DTBs leave the dcpext DARTs, mailbox, crossbars and the internal DCP's route
# disabled; only the c114 kernel (fay-up after install-up.sh with the c114 build) expects that.
# fay-daily (r3) and r12 expect them enabled: the panel should still come up, external displays
# likely not. Boot only fay-up while this is installed (sudo grub-reboot fay-up), and run
# uninstall-bootbin-c114.sh before booting anything else.
#
# Run by Marius. Undo: uninstall-bootbin-c114.sh
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd)
F=$E/bootbin-c114
P=/usr/local/lib/fay-boot
CLAMSHELL_BOOTBIN=730f8718a71e4fc789ee526bed53db5ce551d5a0996570fe91e078f5f92653f8   # installed 2026-10-13
die() { echo "install-bootbin-c114: $*" >&2; exit 1; }

cur=$(sha256sum /boot/m1n1/boot.bin | cut -d' ' -f1)
[[ $cur == "$CLAMSHELL_BOOTBIN" ]] || die "/boot/m1n1/boot.bin is not the clamshell boot.bin ($cur)"
( cd "$F" && sha256sum --quiet -c SHA256SUMS ) || die "bootbin-c114 does not match its SHA256SUMS"
grep -q '^M1N1=/usr/local/lib/fay-boot/m1n1.bin$' /etc/default/update-m1n1 &&
  grep -q '^DTBS="/usr/local/lib/fay-boot/dtbs/\*.dtb"$' /etc/default/update-m1n1 ||
  die "/etc/default/update-m1n1 does not pin $P"
[[ $(tr -d '\0' < /proc/device-tree/chosen/asahi,efi-system-partition) == \
   $(lsblk -no PARTUUID "$(findmnt -no SOURCE /boot)") ]] || die "/boot is not the system ESP"
(( $(df --output=avail -k /boot | tail -1) > 30000 )) || die "less than 30 MB free in /boot"

cat <<EOF
Test boot.bin for Phase 2 on #114 (source $(cut -c1-12 "$F/SOURCE-COMMIT")).
While it is installed, boot only fay-up (the c114 kernel):
  sudo grub-reboot fay-up && reboot
fay-daily, r12 and linux-aurora are untested with these DTBs.
Undo before booting one of those: uninstall-bootbin-c114.sh
EOF
read -r -p "Install? Type yes: " answer
[[ $answer == yes ]] || die "not installed"

sudo -v
B=/var/lib/fay-backup/bootbin-c114-$(date +%Y%m%d-%H%M%S)
sudo mkdir -p "$B"
sudo cp -a /boot/m1n1/boot.bin "$B"/boot.bin
sudo cp -a /etc/default/update-m1n1 "$B"/update-m1n1.default
sudo cp -a "$P" "$B"/fay-boot.previous
echo "$B" | sudo tee /var/lib/fay-backup/bootbin-c114-LATEST >/dev/null

sudo rm -rf "$P.new"
sudo install -d -m 0755 "$P.new/dtbs"
sudo install -m 0644 "$F"/m1n1.bin "$P.new"/m1n1.bin
sudo install -m 0644 "$F"/dtbs/*.dtb "$P.new"/dtbs/
sudo install -m 0644 "$F"/SHA256SUMS "$P.new"/SHA256SUMS
sudo rm -rf "$P" && sudo mv "$P.new" "$P"

sudo update-m1n1
sync

new=$(sha256sum /boot/m1n1/boot.bin | cut -d' ' -f1)
want=$(grep ' boot.bin$' "$F"/SHA256SUMS | cut -d' ' -f1)
if [[ $new == "$want" ]]; then
  echo "OK: /boot/m1n1/boot.bin is the c114 boot.bin (${new:0:16}), clamshell backup in $B"
else
  echo "MISMATCH: /boot/m1n1/boot.bin is ${new:0:16}, expected ${want:0:16}" >&2
  echo "restore with uninstall-bootbin-c114.sh before rebooting" >&2
  exit 1
fi
