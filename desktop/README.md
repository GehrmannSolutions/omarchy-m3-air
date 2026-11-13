# Desktop helpers

| Folder | What | Install |
|---|---|---|
| [display-busy-notify/](display-busy-notify/) | desktop notification when a second external display has to wait for the single external display pipeline (kernel patch 0012 logs it) | script to `~/.local/bin/`, unit to `~/.config/systemd/user/`, `systemctl --user enable --now tars-display-busy-notify` |
| [lid-policy/](lid-policy/) | takes the lid switch from logind (`handle-lid-switch` inhibitor): lid closed and no external display for 10 s → lock and suspend; a display that is briefly gone while it changes pipeline no longer suspends the laptop | same, `tars-lid-policy` |
| [lid-open-safety/](lid-open-safety/) | Omarchy sometimes misses a lid-open event and the panel stays off ([omacom/omarchy#15307](https://github.com/omacom/omarchy/issues/15307)); this re-runs Omarchy's clamshell script 1 s after the lid opened if its flag is still set | same, `tars-lid-open-safety` |
| [iso-keyboard/](iso-keyboard/) | swaps the `<>` key and the key left of 1 on the internal ISO keyboard, which `hid_apple` does not detect ([omacom/linux-aurora#350](https://github.com/omacom/linux-aurora/issues/350)); **ISO keyboards only**, it swaps the wrong keys on an ANSI (US) Mac | copy both files to `/etc/modprobe.d/` and `/etc/tmpfiles.d/`, then `sudo systemd-tmpfiles --create` |
| [omarchy-qt612/](omarchy-qt612/) | Omarchy shell fix for Qt 6.12 (same change as omacom/omarchy PR #14553); `omarchy update` overwrites it, re-run `apply.sh` until the package has it | `./apply.sh`, undo `./undo.sh` |

They only use Omarchy's own commands, logind and the kernel log; nothing touches the boot chain.
`lid-policy` replaces logind's lid handling while it runs (logind takes over again when it stops).

On the official packages (2026-11) `lid-policy` and `lid-open-safety` still run here.
`display-busy-notify` also matches the wait line of the packaged aurora16 kernel ("display on USB-C
... waits for a free external display pipeline"); it promises the lid-closed takeover only when the
kernel says so (a kernel with #127).
