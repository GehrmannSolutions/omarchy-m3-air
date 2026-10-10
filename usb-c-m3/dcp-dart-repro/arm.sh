#!/bin/bash
# arm.sh - arm exactly the next boot as a DCP test boot. Run with sudo.
#
#   sudo ./arm.sh grubenv-test           one-time check that GRUB can clear its
#                                        one-shot boot choice (harmless reboot)
#   sudo ./arm.sh grubenv-check          after that reboot: record the result
#   sudo ./arm.sh dry  [delay_seconds]   trace + owner verdict, never blanks
#   sudo ./arm.sh full [delay_seconds]   as dry, then blanks the screen (repro)
#   sudo ./arm.sh disarm                 undo an arm that has not booted yet
#
# delay_seconds (default 20, max 3600): wait after the boot capture before the
# late snapshot and, in full mode, before the first blank. Use 360 to match
# the uptime of the original crash.
# Optional environment: REPEATS=1..5 (blank cycles in full mode when nothing
# crashes, default 3), REBOOT=auto|clean|sysrq (default auto: clean reboot
# unless the DCP crashed, a blank cycle did not finish or a kernel call hung),
# SKIP_GRUBENV_CHECK=1 (arm without a passed GRUB check - not recommended).
#
# arm.sh does NOT reboot. It writes /var/lib/fay-dcptest/armed and runs
# grub-reboot 'fay-dcp DCP test', then tells you to reboot.

set -Eeuo pipefail
export LC_ALL=C

KIT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KREL=7.2.2-fay-dcp
DAILY_KREL=7.1.13-3-2-ARCH
STATE=/var/lib/fay-dcptest
ARMED=$STATE/armed
GE_TEST=$STATE/grubenv-test
GE_OK=$STATE/grubenv-ok
SCRIPT=/usr/local/sbin/fay-dcptest
GRUBCFG=/boot/grub/grub.cfg
GRUBENV=/boot/grub/grubenv
ENTRY_TITLE='fay-dcp DCP test'
CLEANUP=linux-modules-cleanup.service

die() {
	printf '\nERROR: %s\n' "$*" >&2
	exit 1
}
info() { printf '    %s\n' "$*"; }
trap 'die "arm.sh stopped at line $LINENO: $BASH_COMMAND"' ERR

usage() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
}

next_entry_value() {
	{ grub-editenv "$GRUBENV" list 2> /dev/null || true; } | sed -n 's/^next_entry=//p'
}

# Title of the first top-level GRUB entry, if it boots the daily kernel.
default_entry_title() {
	local title linux
	title=$(awk -F"'" '/^menuentry / { print $2; exit }' "$GRUBCFG")
	linux=$(awk '/^menuentry / { m = 1 } m && /^[ \t]*linux[ \t]/ { print; exit }' "$GRUBCFG")
	if [[ -n $title && $linux == *"/vmlinuz-linux-asahi "* ]]; then
		printf '%s\n' "$title"
	fi
}

# A GRUB check armed in an earlier boot: did GRUB clear next_entry by itself?
grubenv_check_pending() {
	local then_boot now_boot
	[[ -f $GE_TEST ]] || return 0
	then_boot=$(sed -n 's/^boot_id=//p' "$GE_TEST")
	now_boot=$(cat /proc/sys/kernel/random/boot_id)
	if [[ $then_boot == "$now_boot" ]]; then
		die "the GRUB check is armed, but this is still the same boot. Run 'systemctl reboot' first, then: sudo $0 grubenv-check"
	fi
	if [[ -n $(next_entry_value) ]]; then
		grub-editenv "$GRUBENV" unset next_entry
		rm -f -- "$GE_TEST"
		sync -f "$GRUBENV"
		die "GRUB did NOT clear its one-shot boot choice (next_entry) during the last boot: save_env does not work on this setup. A test boot that fails before the test script starts would then be chosen again and again. Do not arm a test boot (see README, 'GRUB check'). next_entry has been cleared now."
	fi
	printf 'checked_at=%s\n' "$(date -Is)" > "$GE_OK"
	rm -f -- "$GE_TEST"
	sync -f "$GE_OK"
	info "GRUB check passed: GRUB cleared next_entry by itself at the last boot."
}

[[ $EUID -eq 0 ]] || die "please run with sudo: sudo $0 $*"
MODE=${1:-}
[[ -n $MODE ]] || usage

if [[ $MODE == disarm ]]; then
	rm -f -- "$ARMED" "$GE_TEST"
	grub-editenv "$GRUBENV" unset next_entry
	sync -f "$GRUBENV"
	sync -f "$STATE" 2> /dev/null || true
	info "disarmed: $ARMED removed, GRUB next_entry cleared (a pending GRUB check was cancelled too)"
	exit 0
fi

[[ $(uname -r) == "$DAILY_KREL" ]] ||
	die "running kernel is $(uname -r); run arm.sh from the daily kernel $DAILY_KREL"
install -d -m 0755 "$STATE"

if [[ $MODE == grubenv-test ]]; then
	if [[ -f $ARMED ]]; then
		die "a test boot is armed; run 'sudo $0 disarm' first"
	fi
	[[ -z $(next_entry_value) ]] || die "GRUB next_entry is already set; run 'sudo $0 disarm' first"
	TITLE=$(default_entry_title)
	[[ -n $TITLE ]] || die "could not find the default GRUB entry (first entry booting linux-asahi) in $GRUBCFG"
	if ! grub-reboot "$TITLE"; then
		die "grub-reboot failed"
	fi
	if [[ $(next_entry_value) != "$TITLE" ]]; then
		grub-editenv "$GRUBENV" unset next_entry || true
		die "grub-reboot did not set next_entry"
	fi
	printf 'boot_id=%s\narmed_at=%s\n' "$(cat /proc/sys/kernel/random/boot_id)" "$(date -Is)" > "$GE_TEST"
	sync -f "$GE_TEST"
	sync -f "$GRUBENV"
	cat << EOF

GRUB check armed: the next boot is your NORMAL system ('$TITLE'), chosen
through the same one-shot mechanism the test boot uses. Nothing else changes.

  1. Run:  systemctl reboot   (type your passphrase as usual)
  2. After logging in, run:  sudo $0 grubenv-check
EOF
	exit 0
fi

if [[ $MODE == grubenv-check ]]; then
	if [[ ! -f $GE_TEST ]]; then
		if [[ -f $GE_OK ]]; then
			info "GRUB check already passed ($(cat "$GE_OK"))"
			exit 0
		fi
		die "no GRUB check is pending; run: sudo $0 grubenv-test"
	fi
	grubenv_check_pending
	info "Next step: sudo $0 dry"
	exit 0
fi

[[ $MODE == dry || $MODE == full ]] || usage
DELAY=${2:-20}
[[ $DELAY =~ ^[0-9]{1,4}$ ]] && (( 10#$DELAY <= 3600 )) || die "delay must be 0..3600 seconds"
DELAY=$(( 10#$DELAY ))
REPEATS=${REPEATS:-3}
[[ $REPEATS =~ ^[1-5]$ ]] || die "REPEATS must be 1..5"
REBOOT_PREF=${REBOOT:-auto}
[[ $REBOOT_PREF =~ ^(auto|clean|sysrq)$ ]] || die "REBOOT must be auto, clean or sysrq"
OWNER=${SUDO_USER:-}
[[ -z $OWNER || $OWNER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || OWNER=""

# everything install.sh set up must be in place
[[ -x $SCRIPT ]] || die "$SCRIPT missing - run install.sh first"
cmp -s "$SCRIPT" "$KIT_DIR/fay-dcptest" || die "$SCRIPT differs from the kit copy - re-run install.sh"
cmp -s /etc/systemd/system/fay-dcptest.service "$KIT_DIR/fay-dcptest.service" ||
	die "fay-dcptest.service differs from the kit copy - re-run install.sh"
[[ $(systemctl is-enabled fay-dcptest.service 2> /dev/null || true) == enabled ]] ||
	die "fay-dcptest.service is not enabled - run install.sh"
[[ $(systemctl is-enabled "$CLEANUP" 2> /dev/null || true) == masked ]] ||
	die "$CLEANUP is not masked - the $KREL modules would be deleted; run install.sh"
[[ -f /usr/lib/modules/$KREL/modules.dep && -f /usr/lib/modules/$KREL/kernel/drivers/gpu/drm/apple/appledrm.ko ]] ||
	die "/usr/lib/modules/$KREL is missing or incomplete - run install.sh"
[[ -f /boot/vmlinuz-fay-dcp && -f /boot/initramfs-fay-dcp.img ]] || die "fay-dcp kernel or initramfs missing in /boot"
grep -q "^menuentry '$ENTRY_TITLE'" "$GRUBCFG" || die "GRUB entry '$ENTRY_TITLE' missing - run install.sh"
awk -v t="^menuentry '$ENTRY_TITLE'" '$0 ~ t { m = 1 } m && /^[ \t]*linux[ \t]/ { print; exit }' "$GRUBCFG" |
	grep -qE '(^|[[:space:]])panic=10([[:space:]]|$)' ||
	die "the GRUB test entry has no panic=10 (old kit version) - re-run install.sh"
[[ -r $STATE/config ]] || die "$STATE/config missing - run install.sh"

# The GRUB check (README step 2) must have passed once
grubenv_check_pending
[[ -z $(next_entry_value) ]] || die "GRUB next_entry is already set ('$(next_entry_value)'); run 'sudo $0 disarm' first"
if [[ ! -f $GE_OK ]]; then
	if [[ ${SKIP_GRUBENV_CHECK:-0} == 1 ]]; then
		info "WARNING: SKIP_GRUBENV_CHECK=1 - arming without a passed GRUB check"
	else
		die "the one-time GRUB check has not passed yet. Run: sudo $0 grubenv-test (README step 2)"
	fi
fi

TMP=$STATE/armed.tmp
{
	printf 'mode=%s\n' "$MODE"
	printf 'delay=%s\n' "$DELAY"
	printf 'repeats=%s\n' "$REPEATS"
	printf 'reboot=%s\n' "$REBOOT_PREF"
	if [[ -n $OWNER ]]; then printf 'owner=%s\n' "$OWNER"; fi
	printf 'armed_at=%s\n' "$(date -Is)"
} > "$TMP"
chmod 0644 "$TMP"
mv -f "$TMP" "$ARMED"
# from here on any failure must remove the armed file again: an armed file
# without a fresh grub-reboot would run the test on a later manual choice
# of the test entry
trap 'rm -f -- "$ARMED"; die "arm.sh stopped at line $LINENO: $BASH_COMMAND (armed file removed again)"' ERR
if ! grub-reboot "$ENTRY_TITLE"; then
	rm -f -- "$ARMED"
	die "grub-reboot failed; disarmed again"
fi
if [[ $(next_entry_value) != "$ENTRY_TITLE" ]]; then
	rm -f -- "$ARMED"
	grub-editenv "$GRUBENV" unset next_entry || true
	die "grub-reboot did not set next_entry; disarmed again"
fi
sync -f "$ARMED"
sync -f "$GRUBENV"
trap 'die "arm.sh stopped at line $LINENO: $BASH_COMMAND"' ERR

WD_MIN=$(( (1200 + DELAY + REPEATS * 120 + 59) / 60 ))
cat << EOF

Armed: mode=$MODE delay=${DELAY}s repeats=$REPEATS reboot=$REBOOT_PREF
  $ARMED written, GRUB will boot '$ENTRY_TITLE' once.

Next step:
  1. Save your work and close programs. Keep the charger connected, lid open.
  2. Run:  systemctl reboot
  3. GRUB starts '$ENTRY_TITLE' by itself. Type your disk passphrase.
  4. Text console only (no desktop). Do not type anything. Lines starting
     with '*** fay-dcptest:' appear; during the ${DELAY}s wait one appears
     every minute. The machine reboots by itself into the normal system
     (passphrase again).
  If the screen is on but no new '***' line appears for more than 5 minutes,
  or the screen stays black for more than 5 minutes after "blanking the
  screen now": hold the power button ~10 s. Otherwise the safety timer
  forces a reboot at the latest about $WD_MIN minutes after the test started.
  If GRUB keeps choosing '$ENTRY_TITLE' on every boot: pick the normal
  entry in the GRUB menu (5 s), then run: sudo $0 disarm
  To cancel before rebooting:  sudo $0 disarm
EOF
