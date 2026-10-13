# Desktop helpers

| Folder | What | Install |
|---|---|---|
| [display-busy-notify/](display-busy-notify/) | desktop notification when a second external display has to wait for the single external display pipeline (kernel patch 0012 logs it) | script to `~/.local/bin/`, unit to `~/.config/systemd/user/`, `systemctl --user enable --now fay-display-busy-notify` |
| [lid-policy/](lid-policy/) | takes the lid switch from logind (`handle-lid-switch` inhibitor): lid closed and no external display for 10 s → lock and suspend; a display that is briefly gone while it changes pipeline no longer suspends the laptop | same, `fay-lid-policy` |
| [lid-open-safety/](lid-open-safety/) | Omarchy sometimes misses a lid-open event and the panel stays off ([omacom/omarchy#15307](https://github.com/omacom/omarchy/issues/15307)); this re-runs Omarchy's clamshell script 1 s after the lid opened if its flag is still set | same, `fay-lid-open-safety` |
| [omarchy-qt612/](omarchy-qt612/) | Omarchy shell fix for Qt 6.12 (same change as omacom/omarchy PR #14553); `omarchy update` overwrites it, re-run `apply.sh` until the package has it | `./apply.sh`, undo `./undo.sh` |

They only use Omarchy's own commands, logind and the kernel log; nothing touches the boot chain.
`lid-policy` replaces logind's lid handling while it runs (logind takes over again when it stops).
