# display-busy-notify (active, 2026-10-13)

User service `fay-display-busy-notify.service` + script `fay-display-busy-notify` (install to
`~/.config/systemd/user/` and `~/.local/bin/`). Follows the kernel log and shows a desktop
notification when a second external display has to wait for the single dcpext pipeline
(kernel line "display on … waits for … external display pipeline …", older kernels: tipd "-16").

Notification texts (English since 2026-10-13):

| Kernel | Text |
|---|---|
| lid-closed set: `kernel/patches-clamshell/` with the `fay-lid-policy` user service running (or our earlier set's "… unplug that one and this one takes over") | "With the lid open, this Mac drives one external display at a time. This one turns on when you close the lid (then both work) or when you unplug the other one." |
| Aurora `integration/aurora` since #114 was merged (2026-10-15: "… waits for a free external display pipeline …; it lights up on its own …"), the v2 series and #114 before the merge | "This Mac drives one external display at a time. This one turns on when you unplug the other one." |
| older kernels (only the USB-C controller's -EBUSY) | "This Mac drives one external display at a time. To switch, unplug the other one, then plug this one in again." |
