#!/usr/bin/env bash
# Fay: build the daily kernel from the consolidated series v2 + the local DPE block
# (branch fay/aurora-j613-dp-v2-daily) into build-v2/stage-v2, kernel release 7.1.12-fay-v2.
set -uo pipefail
E=$(cd "$(dirname "$0")" && pwd)
source "$E/env.sh"
O=$E/build-v2
cd "$SRC" && git checkout -q fay/aurora-j613-dp-v2-daily || exit 1
git log --oneline -1
mkdir -p "$O"
[[ -e $O/.config ]] || cp "$E/build3/.config" "$O/.config"
sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-fay-v2"/' "$O/.config"
make O=$O olddefconfig > "$E/logs/olddefconfig-v2.log" 2>&1 || { echo olddefconfig failed; exit 1; }
{ time make O=$O W=1 -j8 all; echo BUILD_EXIT=$?; } > "$E/logs/build-v2.log" 2>&1
grep -q BUILD_EXIT=0 "$E/logs/build-v2.log" || { echo build failed; exit 1; }
KVER=$(cat $O/include/config/kernel.release)
rm -rf "$E/stage-v2/lib/modules/$KVER"
make O=$O INSTALL_MOD_PATH=$E/stage-v2 INSTALL_MOD_STRIP=1 modules_install > "$E/logs/modules_install-v2.log" 2>&1 || { echo modules_install failed; exit 1; }
cd "$E" && { sha256sum build-v2/arch/arm64/boot/Image; find stage-v2/lib/modules/$KVER -type f | sort | xargs sha256sum; } > SHA256SUMS.v2
git -C "$SRC" checkout -q fay/aurora-j613-dp-v2
echo DONE $KVER $(sha256sum build-v2/arch/arm64/boot/Image | cut -c1-16) $(wc -l < SHA256SUMS.v2)
