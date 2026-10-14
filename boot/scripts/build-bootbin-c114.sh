#!/usr/bin/env bash
# Fay (2026-10-14): test boot.bin for Phase 2 consolidated on #114 (plan:
# agents/fay/plans/2026-10-14-PLAN-phase2-consolidation.md) into bootbin-c114/. No root.
#   m1n1: ours (0dc65ef9, sets apple,t8122-dcpext-firmware-ready), the m1n1.bin of bootbin-clamshell
#   DTBs: every DTB of the installed set, from upstream/build3 built from upstream/pr114-src on
#         branch fay/aurora-j613-clamshell-on-114 (#114 + P1-P6). A name the build lacks is an error.
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd)
S=$E/../upstream/pr114-src
D=$E/../upstream/build3/arch/arm64/boot/dts/apple
INSTALLED=/usr/local/lib/fay-boot/dtbs
F=$E/bootbin-c114
die() { echo "build-bootbin-c114: $*" >&2; exit 1; }

[[ $(git -C "$S" rev-parse --abbrev-ref HEAD) == fay/aurora-j613-clamshell-on-114 ]] || die "pr114-src is not on the c114 branch"
[[ -z $(git -C "$S" status --porcelain) ]] || die "pr114-src has local changes"
grep -q BUILD_EXIT=0 "$E/../upstream/logs/build-up.log" || die "no successful build"
(( $(strings "$E/bootbin-clamshell/m1n1.bin" | grep -c dcpext-firmware-ready) > 0 )) || die "our m1n1 lacks the marker"

rm -rf "$F" && mkdir -p "$F/dtbs"
cp "$E/bootbin-clamshell/m1n1.bin" "$F/m1n1.bin"
for f in "$INSTALLED"/*.dtb; do
  n=$(basename "$f")
  [[ -f $D/$n ]] || die "the build has no $n"
  cp "$D/$n" "$F/dtbs/$n"
done
"$E/build-bootbin.sh" "$F/m1n1.bin" "$F/boot.bin" "$F"/dtbs/*.dtb
( cd "$F" && sha256sum boot.bin m1n1.bin dtbs/*.dtb > SHA256SUMS )
git -C "$S" rev-parse HEAD > "$F/SOURCE-COMMIT"
echo "c114: boot.bin $(sha256sum "$F/boot.bin" | cut -c1-16), m1n1 $(sha256sum "$F/m1n1.bin" | cut -c1-16), $(ls "$F"/dtbs | wc -l) DTBs, source $(cut -c1-12 "$F/SOURCE-COMMIT")"
