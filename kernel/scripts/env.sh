# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
# Build environment for the cleaned upstream series (fay-up); same as ext/env.sh, other tree and O=
export ARCH=arm64 LLVM=1
export KBUILD_BUILD_HOST=archlinux KBUILD_BUILD_USER=linux-aurora
export SRC=$HOME/.cache/fay-build/aurora/upstream/linux O=$HOME/.cache/fay-build/aurora/upstream/build3
export LOCALVERSION=
