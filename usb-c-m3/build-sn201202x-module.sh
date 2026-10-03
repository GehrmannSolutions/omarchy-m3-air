#!/usr/bin/env bash
# Build the Apple M3 USB-C fix modules for the running linux-asahi 7.1.13 kernel,
# WITHOUT installing anything and WITHOUT root. Context: ./README.md.
#
# Builds:
#   tps6598x-core.ko, tps6598x.ko, sn201202x.ko  (PD controller, LKML 2607.3 v2)
#   phy-apple-atc.ko                              (retry + WARN fix, PR #503 parts)
#
# Requires: git, gcc, make, flex, bison, bc (for timeconst.h), patch.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${WORK:-$HOME/.cache/fay-build/work}"
mkdir -p "$work"; cd "$work"

KVER_TAG="v7.1.13"                                        # uname -r 7.1.13-3-2-ARCH
BASE_COMMIT="0ce37745d4bfbc493f718169c3974898ffec8ee7"    # series base (mainline)
EXTRAVERSION="-3-2"                                       # must match uname -r for vermagic
P="$here/patches"

command -v bc >/dev/null || { echo "bc missing: sudo pacman -S --needed bc"; exit 1; }

# 1. Asahi tree at the running version. .git removed: otherwise setlocalversion appends '+'.
rm -rf asahi                      # always fresh: the patches below must apply to a clean tree
git clone -q --depth 1 --branch "$KVER_TAG" https://github.com/AsahiLinux/linux.git asahi
rm -rf asahi/.git

# 2. Mainline base, tipd only; apply the series 0002, 0003, 0004 in order.
if [ ! -d base ]; then
  git init -q base && cd base
  git remote add origin https://github.com/torvalds/linux.git
  git fetch -q --depth 1 --filter=blob:none origin "$BASE_COMMIT"
  git checkout -q FETCH_HEAD && git sparse-checkout set drivers/usb/typec/tipd MAINTAINERS
  cd ..
fi
cd base
git reset -q --hard && git clean -fdq          # clean tree before applying the series
git apply "$P/0002-usb-typec-tipd-factor-out-i2c-specifics.patch"
git apply "$P/0003-usb-typec-tipd-add-sn201202x-support.patch"
git apply "$P/0004-tipd-tps6598x.h-add-missing-interrupt-include.patch"
cd ..

# 3. Copy patched tipd into the Asahi tree (its core.c differs from base only in one i2c id line).
cp base/drivers/usb/typec/tipd/* asahi/drivers/usb/typec/tipd/
cp base/MAINTAINERS asahi/MAINTAINERS

# 4. PHY: retry the pipehandler lock (0005), then scope the WARN in atcphy_mux_set (0006).
cd asahi
patch -s -p1 < "$P/0005-phy-apple-atc-retry-pipehandler-lock.patch"
patch -s -p1 < "$P/0006-phy-apple-atc-mux-set-clear-pipehandler-scope-warn.patch"

# 5. Config from the running kernel; enable the new symbol; no BTF (pahole not installed).
zcat /proc/config.gz > .config
./scripts/config --file .config --set-val TYPEC_SN201202X m --disable DEBUG_INFO_BTF --disable DEBUG_INFO_BTF_MODULES
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" olddefconfig
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" -j"$(nproc)" modules_prepare

# 6. Build the two directories. KBUILD_MODPOST_WARN: the Module.symvers of the running
#    kernel is not available here; the running kernel's exports were checked separately.
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" KBUILD_MODPOST_WARN=1 -j"$(nproc)" M=drivers/usb/typec/tipd modules
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" KBUILD_MODPOST_WARN=1 -j"$(nproc)" M=drivers/phy/apple modules

# 7. Report: vermagic and hashes for comparison with the installed modules.
for ko in drivers/usb/typec/tipd/*.ko drivers/phy/apple/phy-apple-atc.ko; do
  echo "$(sha256sum "$ko" | cut -c1-16)  $(modinfo -F vermagic "$ko")  $ko"
done
echo "built in $work/asahi. Installing needs root, see README.md."
