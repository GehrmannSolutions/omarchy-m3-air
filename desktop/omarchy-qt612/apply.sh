#!/usr/bin/env bash
# Fix the Omarchy shell for Qt 6.12 (QtQuick's new Color type shadows omarchy's Color
# singleton -> bar/menus/lock/polkit colors undefined). Same change as omacom/omarchy PR #14553,
# applied to the installed /usr/share/omarchy/shell. A later omarchy package update replaces it.
# Undo: undo.sh
set -euo pipefail
F=$(cd "$(dirname "$0")" && pwd)
B=/var/lib/fay-backup/omarchy-shell-$(date +%Y%m%d-%H%M%S)
sudo cp -a /usr/share/omarchy/shell "$B"
echo "$B" | sudo tee /var/lib/fay-backup/omarchy-shell-LATEST >/dev/null
echo "backup: $B"
sudo python3 -I "$F/qt612-color-fix.py" --write /usr/share/omarchy/shell | tail -1
omarchy-restart-shell
