# display-busy-notify (active, 2026-10-13)

User service `fay-display-busy-notify.service` + script `fay-display-busy-notify` (install to
`~/.config/systemd/user/` and `~/.local/bin/`). Follows the kernel log and shows a desktop
notification when a second external display has to wait for the single dcpext pipeline
(kernel line "… waits for an external display pipeline …", older kernels: tipd "-16").
