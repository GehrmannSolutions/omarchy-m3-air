#!/bin/bash
# install.sh - install the fay DCP/DART test kit. Run with sudo, from the
# daily kernel (7.1.13-3-2-ARCH). Safe to run again (idempotent).
#
# What it does (each command is printed before it runs):
#   1. make modules_install for 7.2.2-fay-dcp from the build tree (this also
#      installs the instrumented appledrm.ko if it was built), then depmod
#   2. masks linux-modules-cleanup.service for the test period, so the
#      7.2.2-fay-dcp module folder is not deleted again at the next boot
#   3. /var/lib/fay-dcptest: config, a copy of System.map, install state
#   4. /usr/local/sbin/fay-dcptest + fay-dcptest.service (enabled; it only
#      runs with fay.dcptest=1 on the kernel command line AND an armed file)
#   5. GRUB entry "fay-dcp DCP test" (/etc/grub.d/42_fay-dcptest), then
#      grub-mkconfig into a temporary file, checks (syntax, default entry
#      first, and NO difference to the current grub.cfg except the new
#      block), and only then replaces /boot/grub/grub.cfg (old copy kept as
#      /boot/grub/grub.cfg.fay-prev, both synced to the vfat /boot).
#
# Environment: FAY_BUILD=<tree> (default ~mg/.cache/fay-build/wip),
#              FAY_STRIP=1 to strip debug info from the installed modules,
#              ALLOW_GRUB_DIFF=1 to accept other grub.cfg differences after
#              checking the diff that is shown (see lib-grub.sh).

set -Eeuo pipefail
export LC_ALL=C

KIT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BUILD=${FAY_BUILD:-/home/mg/.cache/fay-build/wip}
KREL=7.2.2-fay-dcp
DAILY_KREL=7.1.13-3-2-ARCH
STATE=/var/lib/fay-dcptest
SNIPPET=/etc/grub.d/42_fay-dcptest
UNIT=/etc/systemd/system/fay-dcptest.service
SCRIPT=/usr/local/sbin/fay-dcptest
GRUBCFG=/boot/grub/grub.cfg
GRUBENV=/boot/grub/grubenv
ENTRY_TITLE='fay-dcp DCP test'
CLEANUP=linux-modules-cleanup.service
UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

say() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
run() {
	printf '    $'
	printf ' %q' "$@"
	printf '\n'
	"$@"
}
die() {
	printf '\nERROR: %s\n' "$*" >&2
	exit 1
}
trap 'die "install.sh stopped at line $LINENO: $BASH_COMMAND"' ERR

[[ -r $KIT_DIR/lib-grub.sh ]] || die "kit file $KIT_DIR/lib-grub.sh is missing"
# shellcheck source=lib-grub.sh
. "$KIT_DIR/lib-grub.sh"

# ------------------------------------------------------------ preconditions
[[ $EUID -eq 0 ]] || die "please run with sudo: sudo $0"
[[ $(uname -r) == "$DAILY_KREL" ]] ||
	die "running kernel is $(uname -r); run install.sh only from the daily kernel $DAILY_KREL"

say "Checking preconditions"
for f in fay-dcptest fay-dcptest.service grub-40_custom-fay-dcptest.template lib-grub.sh; do
	[[ -r $KIT_DIR/$f ]] || die "kit file $KIT_DIR/$f is missing"
done
bash -n "$KIT_DIR/fay-dcptest" || die "$KIT_DIR/fay-dcptest has a syntax error"
for t in make depmod modinfo python3 gawk gdb readelf nm diff grub-mkconfig grub-editenv grub-probe grub-script-check grub-reboot; do
	command -v "$t" > /dev/null || die "required tool '$t' is not installed"
done
mountpoint -q /boot || die "/boot is not mounted"
AVAIL_KB=$(df --output=avail -k /usr/lib/modules | tail -n 1 | tr -d ' ')
(( AVAIL_KB > 4 * 1024 * 1024 )) || die "less than 4 GiB free under /usr/lib/modules"
[[ -f /boot/vmlinuz-fay-dcp && -f /boot/initramfs-fay-dcp.img ]] ||
	die "/boot/vmlinuz-fay-dcp or /boot/initramfs-fay-dcp.img is missing (see KERNEL-INSTALL-fay-dcp.md)"
[[ -r $BUILD/include/config/kernel.release ]] || die "build tree $BUILD not found"
[[ $(< "$BUILD/include/config/kernel.release") == "$KREL" ]] ||
	die "build tree release is $(< "$BUILD/include/config/kernel.release"), expected $KREL"
for f in vmlinux System.map modules.order; do
	[[ -r $BUILD/$f ]] || die "$BUILD/$f is missing"
done
KO=$BUILD/drivers/gpu/drm/apple/appledrm.ko
[[ -r $KO ]] || die "$KO is missing"
VM=$(modinfo -F vermagic "$KO")
[[ $VM == "$KREL "* ]] || die "appledrm.ko vermagic '$VM' does not match $KREL"
if pgrep -f 'M=drivers/gpu/drm/apple' > /dev/null; then
	die "an appledrm build is running right now; wait until it has finished"
fi
AGE=$(( $(date +%s) - $(stat -c %Y "$KO") ))
(( AGE >= 30 )) || die "appledrm.ko was written ${AGE}s ago; wait until the build has finished"
if nm "$KO" 2> /dev/null | grep -c 'fay_dcp_record_map' > /dev/null; then
	INSTRUMENTED=yes
else
	INSTRUMENTED=no
fi
info "build tree:       $BUILD ($KREL)"
info "appledrm.ko:      sha256 $(sha256sum "$KO" | cut -c1-16)..., $(stat -c '%y' "$KO" | cut -d. -f1), instrumented (fay patch 0008): $INSTRUMENTED"

# UUIDs come from the running system, never from the kit.
read -r -a TOKS < /proc/cmdline
ROOT_UUID="" CRYPT_UUID="" CRYPT_REST="" ROOTFLAGS=""
for tok in "${TOKS[@]}"; do
	case $tok in
	root=UUID=*) ROOT_UUID=${tok#root=UUID=} ;;
	cryptdevice=UUID=*)
		cd_val=${tok#cryptdevice=UUID=}
		CRYPT_UUID=${cd_val%%:*}
		CRYPT_REST=${cd_val#*:}
		;;
	rootflags=*) ROOTFLAGS=${tok#rootflags=} ;;
	esac
done
[[ $ROOT_UUID =~ $UUID_RE ]] || die "could not read root=UUID=... from /proc/cmdline"
[[ $CRYPT_UUID =~ $UUID_RE ]] || die "could not read cryptdevice=UUID=... from /proc/cmdline"
[[ $CRYPT_REST == "root:allow-discards" ]] ||
	die "cryptdevice options are '$CRYPT_REST', the template expects ':root:allow-discards'"
[[ $ROOTFLAGS == "subvol=@" ]] || die "rootflags are '$ROOTFLAGS', the template expects 'subvol=@'"
BOOT_UUID=$(grub-probe --target=fs_uuid /boot 2> /dev/null || true)
# the existing 'with Linux fay-dcp' entry has the same search line
CFG_BOOT_UUID=$(awk "/^[ \t]*menuentry 'Omarchy Linux, with Linux fay-dcp'/ { m = 1 }
	m && /search .*--set=root/ { print \$NF; exit }" "$GRUBCFG")
if [[ -z $BOOT_UUID ]]; then
	BOOT_UUID=$CFG_BOOT_UUID
fi
[[ $BOOT_UUID =~ ^[0-9A-Fa-f-]{4,36}$ ]] || die "could not determine the /boot filesystem UUID"
if [[ -n $CFG_BOOT_UUID && $CFG_BOOT_UUID != "$BOOT_UUID" ]]; then
	die "grub-probe and the existing fay-dcp GRUB entry disagree about the /boot UUID; refusing to guess"
fi
grep -q -- "--set=root $BOOT_UUID" "$GRUBCFG" ||
	die "the /boot UUID does not appear in $GRUBCFG; refusing to guess"
info "root, cryptdevice and /boot UUIDs read from the running system (not printed)"

# ------------------------------------------------------------ 1 modules
say "1/5 Installing the kernel modules of $KREL (about 2 GB unless FAY_STRIP=1)"
STRIP=()
if [[ ${FAY_STRIP:-0} == 1 ]]; then
	STRIP=(INSTALL_MOD_STRIP=1)
fi
run make -C "$BUILD" ARCH=arm64 "${STRIP[@]}" modules_install
run depmod -a "$KREL"
MODDIR=/usr/lib/modules/$KREL
[[ -f $MODDIR/modules.dep && -f $MODDIR/kernel/drivers/gpu/drm/apple/appledrm.ko ]] ||
	die "$MODDIR is incomplete after modules_install"
if [[ ${FAY_STRIP:-0} != 1 ]]; then
	cmp -s "$KO" "$MODDIR/kernel/drivers/gpu/drm/apple/appledrm.ko" ||
		die "installed appledrm.ko differs from $KO"
fi
# the fay-dcp initramfs carries its own copy of appledrm.ko (loaded early on the
# desktop entry), so rebuild it whenever the modules change
run mkinitcpio -k "$KREL" -g /boot/initramfs-fay-dcp.img
run sync -f /boot/initramfs-fay-dcp.img
# make ran as root inside the user's tree: give back anything it created
OWNER=$(stat -c %U:%G "$BUILD")
run find "$BUILD" -xdev -user root -exec chown -h "$OWNER" {} +

# ------------------------------------------------------------ 2 cleanup service
say "2/5 Masking $CLEANUP for the test period"
install -d -m 0755 "$STATE"
PREV=$(systemctl is-enabled "$CLEANUP" 2> /dev/null || true)
if [[ ! -f $STATE/install-state ]] || ! grep -q '^cleanup_prev=' "$STATE/install-state"; then
	printf 'cleanup_prev=%s\n' "${PREV:-unknown}" >> "$STATE/install-state"
fi
if [[ $PREV != masked ]]; then
	run systemctl mask "$CLEANUP"
else
	info "already masked"
fi

# ------------------------------------------------------------ 3 state + config
say "3/5 State directory $STATE"
run install -m 0644 "$BUILD/System.map" "$STATE/System.map-$KREL"
BANNER=$(gdb -batch -nx -ex 'printf "%s", linux_banner' "$BUILD/vmlinux" 2> /dev/null || true)
[[ $BANNER == "Linux version $KREL "* ]] || die "could not read linux_banner from $BUILD/vmlinux"
BANNER_SHA=$(printf '%s\n' "$BANNER" | sha256sum | cut -d' ' -f1)
{
	printf 'VMLINUX=%s\n' "$BUILD/vmlinux"
	printf 'SYSMAP=%s\n' "$STATE/System.map-$KREL"
	printf 'BANNER_SHA256=%s\n' "$BANNER_SHA"
	printf 'INSTRUMENTED=%s\n' "$INSTRUMENTED"
	printf 'INSTALLED_AT=%s\n' "$(date -Is)"
} > "$STATE/config"
chmod 0644 "$STATE/config"
info "config written (vmlinux banner hash for the run-time build check)"

# ------------------------------------------------------------ 3b kernel image
# Installs the build tree's Image as /boot/vmlinuz-fay-dcp when it differs, so a
# rebuilt test kernel (e.g. a DART logging patch) needs no separate copy step.
IMG=$BUILD/arch/arm64/boot/Image
if [[ -r $IMG ]] && ! cmp -s "$IMG" /boot/vmlinuz-fay-dcp; then
	say "3b Installing the test kernel image from the build tree"
	run cp -p /boot/vmlinuz-fay-dcp "$STATE/vmlinuz-fay-dcp.prev-$(date +%Y%m%d-%H%M%S)"
	run install -m 0755 "$IMG" /boot/vmlinuz-fay-dcp.fay-new
	run mv -f /boot/vmlinuz-fay-dcp.fay-new /boot/vmlinuz-fay-dcp
	run sync -f /boot/vmlinuz-fay-dcp
	cmp -s "$IMG" /boot/vmlinuz-fay-dcp || die "/boot/vmlinuz-fay-dcp differs from $IMG after install"
else
	info "test kernel image unchanged"
fi

# ------------------------------------------------------------ 4 script + unit
say "4/5 Test script and systemd unit"
run install -D -m 0755 "$KIT_DIR/fay-dcptest" "$SCRIPT"
run install -m 0644 "$KIT_DIR/fay-dcptest.service" "$UNIT"
run systemctl daemon-reload
run systemctl enable fay-dcptest.service

# ------------------------------------------------------------ 5 GRUB
say "5/5 GRUB entry '$ENTRY_TITLE'"
TMP=$(mktemp)
sed -e "s/__BOOT_FS_UUID__/$BOOT_UUID/" -e "s/__ROOT_UUID__/$ROOT_UUID/" \
	-e "s/__CRYPT_UUID__/$CRYPT_UUID/" "$KIT_DIR/grub-40_custom-fay-dcptest.template" > "$TMP"
if grep -q '__[A-Z_]*__' "$TMP"; then
	rm -f "$TMP"
	die "a placeholder was not filled in the GRUB snippet"
fi
BACKUP="$STATE/grub.cfg.before-install.$(date +%Y%m%d-%H%M%S)"
run cp -a "$GRUBCFG" "$BACKUP"
run install -m 0755 "$TMP" "$SNIPPET"
rm -f "$TMP"
NEW=/boot/grub/grub.cfg.fay-new
rm -f "$NEW"
if ! run grub-mkconfig -o "$NEW"; then
	rm -f "$NEW" "$SNIPPET"
	die "grub-mkconfig failed; $GRUBCFG is unchanged and the snippet was removed"
fi
( verify_grubcfg "$NEW" present && grubcfg_diff_ok "$GRUBCFG" "$NEW" ) || {
	rm -f "$NEW" "$SNIPPET"
	die "the generated GRUB config did not pass the checks; $GRUBCFG is unchanged and the snippet was removed"
}
install_grubcfg "$NEW"
verify_grubcfg "$GRUBCFG" present

ENV_LIST=$(grub-editenv "$GRUBENV" list 2> /dev/null || true)
if grep -q '^next_entry=' <<< "$ENV_LIST"; then
	info "NOTE: GRUB next_entry is currently set: $(grep '^next_entry=' <<< "$ENV_LIST")"
fi

# ------------------------------------------------------------ summary
say "Installed"
info "modules:   $MODDIR (appledrm instrumented: $INSTRUMENTED)"
info "cleanup:   $CLEANUP is $(systemctl is-enabled "$CLEANUP" 2> /dev/null || true) (uninstall.sh restores it)"
info "script:    $SCRIPT, unit fay-dcptest.service $(systemctl is-enabled fay-dcptest.service 2> /dev/null || true)"
info "GRUB:      '$ENTRY_TITLE' added; default entry is still linux-asahi"
info "           backups: $BACKUP, $GRUBCFG_PREV (loadable from the grub> prompt)"
info ""
if [[ -f $STATE/grubenv-ok ]]; then
	info "Next step: sudo $KIT_DIR/arm.sh dry     (then: systemctl reboot)"
else
	info "Next step: the one-time GRUB check (README step 2):"
	info "           sudo $KIT_DIR/arm.sh grubenv-test   (then: systemctl reboot)"
fi
