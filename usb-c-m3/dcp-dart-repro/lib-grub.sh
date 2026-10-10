# lib-grub.sh - GRUB helpers shared by install.sh and uninstall.sh.
# Sourced, not run. The caller defines: ENTRY_TITLE, GRUBCFG, die(), run().
#
# Every grub.cfg change goes the same way:
#   grub-mkconfig into grub.cfg.fay-new  ->  verify_grubcfg (syntax, default
#   entry, test entry present/absent)  ->  grubcfg_diff_ok (old and new may
#   differ ONLY in the /etc/grub.d/42_fay-dcptest block)  ->  install_grubcfg
#   (copy of the old file as grub.cfg.fay-prev, replace, sync).
# /boot is vfat: without the sync a power loss within ~30 s could leave a
# missing or half-written grub.cfg, and the only other backup lies on the
# LUKS root, which GRUB cannot read. grub.cfg.fay-prev can be loaded from the
# grub> prompt with:  configfile $prefix/grub.cfg.fay-prev

FAY_SNIPPET_NAME=/etc/grub.d/42_fay-dcptest
GRUBCFG_PREV=/boot/grub/grub.cfg.fay-prev

# verify_grubcfg <file> <present|absent>
verify_grubcfg() {
	local f=$1 want=$2 first n entry w
	grub-script-check "$f" || die "grub-script-check rejected $f"
	first=$(awk '/^menuentry / { m = 1 } m && /^[ \t]*linux[ \t]/ { print; exit }' "$f")
	if [[ $first != *"/vmlinuz-linux-asahi "* ]]; then
		die "the first GRUB entry in $f would not boot linux-asahi any more"
	fi
	n=$(grep -c "^menuentry '$ENTRY_TITLE'" "$f" || true)
	if [[ $want == present ]]; then
		[[ $n == 1 ]] || die "expected exactly one '$ENTRY_TITLE' entry in $f, found $n"
		entry=$(awk -v t="^menuentry '$ENTRY_TITLE'" '$0 ~ t { m = 1 } m && /^[ \t]*linux[ \t]/ { print; exit }' "$f")
		for w in /vmlinuz-fay-dcp fay.dcptest=1 modprobe.blacklist=appledrm systemd.unit=multi-user.target log_buf_len=16M panic=10; do
			[[ $entry =~ (^|[[:space:]])"$w"([[:space:]]|$) ]] || die "test entry lacks '$w'"
		done
		if [[ " $entry " == *" quiet "* || " $entry " == *" splash "* ]]; then
			die "test entry must not contain quiet/splash"
		fi
	else
		[[ $n == 0 ]] || die "'$ENTRY_TITLE' is still present in $f"
	fi
	return 0
}

# strip_fay_block <file>: the file without the 42_fay-dcptest block and
# without empty lines (grub-mkconfig adds one before every block).
strip_fay_block() {
	awk -v b="### BEGIN $FAY_SNIPPET_NAME ###" -v e="### END $FAY_SNIPPET_NAME ###" '
		$0 == b { skip = 1; next }
		$0 == e { skip = 0; next }
		!skip && NF' "$1"
}

# grubcfg_diff_ok <old> <new>: old and new must be identical apart from the
# 42_fay-dcptest block. Anything else (root=, cryptdevice=, rootflags=,
# initrd, entry order, a grub.d script that changed since grub.cfg was last
# generated) stops here. ALLOW_GRUB_DIFF=1 accepts other differences after
# showing them (only after checking them by hand).
grubcfg_diff_ok() {
	local old=$1 new=$2
	if diff -u <(strip_fay_block "$old") <(strip_fay_block "$new") > /dev/null; then
		return 0
	fi
	printf '\nThe regenerated GRUB config differs from %s in more than the fay-dcptest block:\n' "$old" >&2
	diff -u <(strip_fay_block "$old") <(strip_fay_block "$new") >&2 || true
	if [[ ${ALLOW_GRUB_DIFF:-0} == 1 ]]; then
		printf '\nALLOW_GRUB_DIFF=1 is set: accepting these differences.\n' >&2
		return 0
	fi
	die "refusing to replace $old (re-run with ALLOW_GRUB_DIFF=1 only after checking the diff above)"
}

# install_grubcfg <new>: keep the current grub.cfg as grub.cfg.fay-prev,
# move <new> into place, and flush both to the vfat /boot.
install_grubcfg() {
	local new=$1
	run cp -p "$GRUBCFG" "$GRUBCFG_PREV"
	run sync -f "$GRUBCFG_PREV"
	run mv -f "$new" "$GRUBCFG"
	run sync -f "$GRUBCFG"
}
