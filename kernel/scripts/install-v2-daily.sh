#!/usr/bin/env bash
# Fay (2026-10-13): make the consolidated series v2 the daily kernel.
# Kernel 7.1.12-fay-v2 (branch fay/aurora-j613-dp-v2-daily = the 12 v2 patches + the local DPE
# block for the GPU, build-v2/stage-v2) is installed side by side:
#   /boot/vmlinuz-linux-aurora-fay-v2, /boot/initramfs-linux-aurora-fay-v2.img,
#   /usr/lib/modules/7.1.12-fay-v2, /etc/mkinitcpio.conf.d/zz-fay-v2.conf.
# /etc/grub.d/44_fay_daily then has two entries:
#   'fay-daily'       -> fay-v2 (command line of the old fay-daily minus the four dev-series knobs,
#                        which v2 does not have; the front USB-C port comes from the boot.bin DT)
#   'fay-daily-ext2'  -> the previous daily entry, unchanged (fallback; the clamshell test entries
#                        in 46_fay_ext2 stay too)
# GRUB_DEFAULT stays "fay-daily", so the next normal boot starts fay-v2. Does not touch boot.bin,
# m1n1, the ESP, fay-ext2, fay-up. Does not reboot.
# Undo: bash uninstall-v2-daily.sh
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd)
die() { echo "install-v2-daily: $*" >&2; exit 1; }

O=$E/build-v2
STAGE=$E/stage-v2
KVER=$(cat "$O/include/config/kernel.release")
[[ $KVER == 7.1.12-fay-v2 ]] || die "unexpected kernel release $KVER"
[[ $(uname -r) != "$KVER" ]] || die "$KVER is the running kernel"
grep -q 'BUILD_EXIT=0' "$E/logs/build-v2.log" || die "no successful build log (logs/build-v2.log)"
( cd "$E" && sha256sum --quiet -c SHA256SUMS.v2 ) || die "SHA256SUMS.v2 does not match build-v2/stage-v2"
[[ -d $STAGE/lib/modules/$KVER/kernel ]] || die "stage-v2 has no modules for $KVER"
DAILY=/etc/grub.d/44_fay_daily
sudo test -f $DAILY || die "$DAILY missing"
grep -q '^GRUB_DEFAULT="fay-daily"' /etc/default/grub || die "GRUB_DEFAULT is not fay-daily"
# the front port must come from the boot.bin device tree (install-bootbin-front.sh)
[[ -e /sys/firmware/devicetree/base/soc/dcp@31ac00000/typec-routes/route@1 ]] || die "the device tree has no dcpext route@1 (boot.bin without the front port?)"

need=$(( $(stat -c %s "$O/arch/arm64/boot/Image") / 1048576 + 30 ))
free=$(df -Pm /boot | awk 'NR==2 {print $4}')
old=0
for f in /boot/vmlinuz-linux-aurora-fay-v2 /boot/initramfs-linux-aurora-fay-v2.img; do
  [[ -f $f ]] && old=$(( old + $(stat -c %s "$f") / 1048576 ))
done
(( free + old > need )) || die "/boot has ${free} MiB free (+${old} MiB of an old fay-v2), need ${need} MiB"

sudo -v
B=/var/lib/fay-backup/v2-daily-$(date +%Y%m%d-%H%M%S)
sudo mkdir -p "$B"
sudo cp -a /boot/grub/grub.cfg $DAILY "$B"/
sudo cp -a /boot/grub/grubenv "$B"/ 2>/dev/null || true
echo "$B" | sudo tee /var/lib/fay-backup/v2-daily-LATEST >/dev/null

# modules
sudo rm -rf "/usr/lib/modules/$KVER"
sudo cp -a "$STAGE/lib/modules/$KVER" /usr/lib/modules/
sudo depmod "$KVER"
# kernel
sudo rm -f /boot/vmlinuz-linux-aurora-fay-v2 /boot/initramfs-linux-aurora-fay-v2.img
sudo install -m 0644 "$O/arch/arm64/boot/Image" /boot/vmlinuz-linux-aurora-fay-v2
printf '%s\n' \
  '# Fay (install-v2-daily.sh, removed by uninstall-v2-daily.sh): the T8122 dcpext Type-C routes' \
  '# need the display crossbar driver in the initramfs, or the panel'"'"'s DRM device waits for it.' \
  'if [[ ${KERNELVERSION:-} == *-fay-v2 ]]; then' \
  '  MODULES+=(mux-apple-display-crossbar)' \
  'fi' | sudo tee /etc/mkinitcpio.conf.d/zz-fay-v2.conf >/dev/null
sudo mkinitcpio -k "$KVER" -g /boot/initramfs-linux-aurora-fay-v2.img >/dev/null 2>&1 || die "mkinitcpio failed (backup: $B)"
LIST=$(sudo lsinitcpio /boot/initramfs-linux-aurora-fay-v2.img)
for m in appledrm mux-apple-display-crossbar phy-apple-atc; do
  grep -qE "/$m\.ko(\.[a-z]+)?$" <<<"$LIST" || die "initramfs lacks $m"
done

# GRUB: the old daily entry becomes 'fay-daily-ext2'; a new 'fay-daily' boots fay-v2
ENTRY=$(sudo awk '/\$menuentry_id_option .fay-daily. \{/{p=1} p{print} p&&/^\}/{exit}' $DAILY)
[[ -n $ENTRY ]] || die "no 'fay-daily' entry in $DAILY"
grep -q 'vmlinuz-linux-aurora-fay-ext2 ' <<<"$ENTRY" || die "'fay-daily' does not boot fay-ext2 (already switched?)"
OLD=$(sed -E \
  -e "s/^menuentry '[^']*'/menuentry 'Fay: previous daily, dev series (fay-ext2)'/" \
  -e "s/\\\$menuentry_id_option 'fay-daily'/\$menuentry_id_option 'fay-daily-ext2'/" <<<"$ENTRY")
NEW=$(sed -E \
  -e "s/^menuentry '[^']*'/menuentry 'Fay: Aurora + GPU + external DP, series v2 (fay-v2)'/" \
  -e 's#vmlinuz-linux-aurora-fay-ext2 #vmlinuz-linux-aurora-fay-v2 #' \
  -e 's#initramfs-linux-aurora-fay-ext2\.img#initramfs-linux-aurora-fay-v2.img#' \
  -e 's#linux-aurora-fay-ext2 \.\.\.#linux-aurora-fay-v2 ...#' \
  -e 's# (apple_t8122_display\.dcpext_pmp_record|apple_t8122_display\.dcpext_front|appledrm\.t8122_dcpext_trace|apple_rtkit\.sync_syslog_print)=[^ ]*##g' <<<"$ENTRY")
grep -q 'vmlinuz-linux-aurora-fay-v2 ' <<<"$NEW" && grep -q 'initramfs-linux-aurora-fay-v2.img' <<<"$NEW" || die "could not build the new entry"
! grep -qE 'fay-ext2|dcpext_pmp_record|dcpext_front|t8122_dcpext_trace|sync_syslog_print' <<<"$NEW" || die "new entry still has fay-ext2 bits"
grep -q 'asahi.t8122_dpe_leak=1' <<<"$NEW" || die "new entry lacks asahi.t8122_dpe_leak=1"
{ printf '#!/bin/sh\n# Fay: daily entry on fay-v2 (install-v2-daily.sh; undo: uninstall-v2-daily.sh), previous daily as fallback\nexec tail -n +4 $0\n'
  printf '%s\n' "$NEW" "$OLD"; } | sudo tee $DAILY >/dev/null
sudo chmod 0755 $DAILY
sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || die "grub-mkconfig failed (backup: $B)"
for id in fay-daily fay-daily-ext2 fay-up; do
  sudo grep -q "\$menuentry_id_option '$id'" /boot/grub/grub.cfg || die "$id not in grub.cfg (backup: $B)"
done
sudo awk "/menuentry_id_option 'fay-daily' /{p=1} p&&/^\s*linux/{print; exit}" /boot/grub/grub.cfg | grep -q 'vmlinuz-linux-aurora-fay-v2 ' || die "fay-daily in grub.cfg does not boot fay-v2 (backup: $B)"
grep -E '^GRUB_DEFAULT=' /etc/default/grub
sudo grub-editenv list
df -h /boot | tail -1
echo "installed $KVER as fay-daily; the previous daily is 'fay-daily-ext2' (backup: $B)"
