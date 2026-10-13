# omarchy-qt612

Fix for the Omarchy shell under Qt 6.12 (Color singleton shadowed), same as omacom/omarchy PR #14553,
applied to `/usr/share/omarchy/shell`. An `omarchy update` overwrites it: re-run `apply.sh` until
the package ships the fix. `undo.sh` restores the backup.
