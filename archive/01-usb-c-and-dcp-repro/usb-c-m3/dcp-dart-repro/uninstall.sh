#!/bin/bash
# uninstall.sh - full rollback of the DCP test kit. Run with sudo.
# Safe to run again: each step checks what is still there.
#
#   sudo ./uninstall.sh                   remove entry, unit, script; unmask
#                                          linux-modules-cleanup.service
#   sudo ./uninstall.sh --remove-modules  also delete /usr/lib/modules/7.2.2-fay-dcp
#
# Collected results in /var/lib/fay-dcptest/<boot_id>/ and the grub.cfg
# backups there are kept. Without --remove-modules the module folder stays
# until the unmasked cleanup service removes it at the next daily-kernel boot
# (it copies it to /usr/lib/modules/.old first).
#
# GRUB: the snippet is only disabled (chmod -x) while the new grub.cfg is
# generated and checked; it is deleted after the new grub.cfg is in place
# and synced. If anything fails, the snippet is made executable again and
# grub.cfg stays as it was, so a second run starts from the same state.

set -Eeuo pipefail
export LC_ALL=C

KIT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KREL=7.2.2-fay-dcp
STATE=/var/lib/fay-dcptest
SNIPPET=/etc/grub.d/42_fay-dcptest
UNIT=/etc/systemd/system/fay-dcptest.service
SCRIPT=/usr/local/sbin/fay-dcptest
GRUBCFG=/boot/grub/grub.cfg
GRUBENV=/boot/grub/grubenv
ENTRY_TITLE='fay-dcp DCP test'
CLEANUP=linux-modules-cleanup.service
NEW=/boot/grub/grub.cfg.fay-new
SNIPPET_DISABLED=0

say() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
run() {
	printf '    $'
	printf ' %q' "$@"
	printf '\n'
	"$@"
}
# undo a half-done GRUB step (grub.cfg is only replaced by install_grubcfg,
# after all checks passed); a second run of uninstall.sh then starts over
restore_grub_step() {
	rm -f -- "$NEW" "$NEW.new"
	if [[ $SNIPPET_DISABLED == 1 && -f $SNIPPET ]]; then
		chmod 0755 "$SNIPPET" || true
		SNIPPET_DISABLED=0
		printf '    (snippet %s re-enabled; fix the error and run uninstall.sh again)\n' "$SNIPPET" >&2
	fi
}
die() {
	restore_grub_step
	printf '\nERROR: %s\n' "$*" >&2
	exit 1
}
trap 'die "uninstall.sh stopped at line $LINENO: $BASH_COMMAND"' ERR

[[ -r $KIT_DIR/lib-grub.sh ]] || die "kit file $KIT_DIR/lib-grub.sh is missing"
# shellcheck source=lib-grub.sh
. "$KIT_DIR/lib-grub.sh"

REMOVE_MODULES=0
case ${1:-} in
"") ;;
--remove-modules) REMOVE_MODULES=1 ;;
*) die "usage: sudo $0 [--remove-modules]" ;;
esac
[[ $EUID -eq 0 ]] || die "please run with sudo: sudo $0"
mountpoint -q /boot || die "/boot is not mounted"
for t in grub-mkconfig grub-editenv grub-script-check diff; do
	command -v "$t" > /dev/null || die "required tool '$t' is not installed"
done

say "Disarming"
run rm -f -- "$STATE/armed" "$STATE/armed.tmp"
ENV_LIST=$(grub-editenv "$GRUBENV" list 2> /dev/null || true)
if grep -qx "next_entry=$ENTRY_TITLE" <<< "$ENV_LIST"; then
	run grub-editenv "$GRUBENV" unset next_entry
	run sync -f "$GRUBENV"
fi

say "Removing the GRUB entry"
if [[ -f $SNIPPET ]] || grep -q "^menuentry '$ENTRY_TITLE'" "$GRUBCFG"; then
	install -d -m 0755 "$STATE"
	run cp -a "$GRUBCFG" "$STATE/grub.cfg.before-uninstall.$(date +%Y%m%d-%H%M%S)"
	if [[ -f $SNIPPET ]]; then
		# grub-mkconfig skips scripts that are not executable
		SNIPPET_DISABLED=1
		run chmod a-x "$SNIPPET"
	fi
	rm -f -- "$NEW"
	run grub-mkconfig -o "$NEW" || die "grub-mkconfig failed"
	verify_grubcfg "$NEW" absent
	grubcfg_diff_ok "$GRUBCFG" "$NEW"
	install_grubcfg "$NEW"
	verify_grubcfg "$GRUBCFG" absent
	# from here on grub.cfg no longer needs the snippet
	SNIPPET_DISABLED=0
	if [[ -f $SNIPPET ]]; then
		run rm -f -- "$SNIPPET"
	fi
	run rm -f -- "$GRUBCFG_PREV"
	info "test entry removed; grub.cfg regenerated, checked and synced"
else
	info "no snippet and no test entry in $GRUBCFG - nothing to do"
fi

say "Removing the systemd unit and the script"
if [[ -f $UNIT ]]; then
	run systemctl disable fay-dcptest.service || true
	run rm -f -- "$UNIT"
	run systemctl daemon-reload
else
	info "no unit installed"
fi
run rm -f -- "$SCRIPT"

say "Restoring $CLEANUP"
PREV=""
if [[ -f $STATE/install-state ]]; then
	PREV=$(awk -F= '$1 == "cleanup_prev" { print $2; exit }' "$STATE/install-state")
fi
if [[ $PREV == masked ]]; then
	info "it was already masked before install.sh - left masked"
elif [[ $(systemctl is-enabled "$CLEANUP" 2> /dev/null || true) == masked ]]; then
	run systemctl unmask "$CLEANUP"
fi
info "$CLEANUP is now: $(systemctl is-enabled "$CLEANUP" 2> /dev/null || true) (before install: ${PREV:-unknown})"

say "Removing kit state (results are kept)"
run rm -f -- "$STATE/config" "$STATE/System.map-$KREL" "$STATE/install-state" \
	"$STATE/grubenv-test" "$STATE/grubenv-ok"

if [[ $REMOVE_MODULES == 1 ]]; then
	say "Removing /usr/lib/modules/$KREL"
	[[ $(uname -r) != "$KREL" ]] || die "refusing to remove the modules of the running kernel"
	run rm -rf -- "/usr/lib/modules/$KREL"
fi

say "Done"
info "results kept in $STATE/<boot_id>/ (if any)"
