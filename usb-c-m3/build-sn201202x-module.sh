#!/usr/bin/env bash
# Build the tipd / sn201202x (Apple M3 USB-C PD controller) modules for the
# running linux-asahi kernel, WITHOUT installing anything and WITHOUT root.
# Context: docs in ./README.md. Patches: ./patches/ (LKML 2607.3, v2 2/3, 3/3).
#
# Requires: git, gcc, make, flex, bison, bc (for timeconst.h). Install of
# modules and insmod need root and are NOT done here.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${WORK:-$HOME/work/sn201202x}"
mkdir -p "$work"; cd "$work"

KVER_TAG="v7.1.13"                 # AsahiLinux/linux tag matching uname -r 7.1.13-3-2-ARCH
BASE_COMMIT="0ce37745d4bfbc493f718169c3974898ffec8ee7"   # series base (mainline)
EXTRAVERSION="-3-2"                # from uname -r; must match for vermagic

command -v bc >/dev/null || { echo "bc missing: sudo pacman -S --needed bc"; exit 1; }

# 1. Asahi kernel source at the running version (shallow).
[ -d asahi ] || git clone -q --depth 1 --branch "$KVER_TAG" https://github.com/AsahiLinux/linux.git asahi

# 2. Mainline base commit, tipd only (blobs on demand).
if [ ! -d base ]; then
  git init -q base && cd base
  git remote add origin https://github.com/torvalds/linux.git
  git fetch -q --depth 1 --filter=blob:none origin "$BASE_COMMIT"
  git checkout -q FETCH_HEAD && git sparse-checkout set drivers/usb/typec/tipd MAINTAINERS
  cd ..
fi

# 3. Apply the series on the exact base (verified 2026-10-03: both apply cleanly).
cd base
git apply "$here/patches/0002-usb-typec-tipd-factor-out-i2c-specifics.patch"
git apply "$here/patches/0003-usb-typec-tipd-add-sn201202x-support.patch"
cd ..

# 4. Copy patched tipd into the Asahi tree. Asahi's tipd/core.c differs from
#    the base only in one i2c id line (cosmetic, lives in i2c.c after the series).
cp base/drivers/usb/typec/tipd/* asahi/drivers/usb/typec/tipd/
cp base/MAINTAINERS asahi/MAINTAINERS

# 5. Config from the running kernel; enable the new symbol; no BTF (pahole not installed).
cd asahi
zcat /proc/config.gz > .config
./scripts/config --file .config --set-val TYPEC_SN201202X m --disable DEBUG_INFO_BTF --disable DEBUG_INFO_BTF_MODULES
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" olddefconfig
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" -j"$(nproc)" modules_prepare

# 6. Build only the tipd directory.
make ARCH=arm64 EXTRAVERSION="$EXTRAVERSION" -j"$(nproc)" M=drivers/usb/typec/tipd modules
find drivers/usb/typec/tipd -name '*.ko' -exec modinfo -F vermagic -F filename {} \;
echo "built in $work/asahi/drivers/usb/typec/tipd (install needs root, see README.md)"
