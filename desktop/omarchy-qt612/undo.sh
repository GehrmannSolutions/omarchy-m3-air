#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
set -euo pipefail
B=$(cat /var/lib/fay-backup/omarchy-shell-LATEST)
sudo rm -rf /usr/share/omarchy/shell
sudo cp -a "$B" /usr/share/omarchy/shell
omarchy-restart-shell
echo "restored from $B"
