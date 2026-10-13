# display-busy-notify (active, 2026-10-13)

User service `fay-display-busy-notify.service` + script `fay-display-busy-notify` (install to
`~/.config/systemd/user/` and `~/.local/bin/`). Follows the kernel log and shows a desktop
notification when a second external display has to wait for the single dcpext pipeline
(kernel line "… waits for an external display pipeline …", older kernels: tipd "-16").

Notification texts (English since 2026-10-13):

| Kernel | Text |
|---|---|
| clamshell set (`kernel/patches-clamshell/`, "… unplug that one and this one takes over") | "With the lid open, this Mac drives one external display at a time. This one turns on when you close the lid (then both work) or when you unplug the other one." |
| v2 series or older | "This Mac drives one external display at a time. To switch, unplug the other one, then plug this one in again." |
