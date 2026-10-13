# lid-open-safety (active, 2026-10-13)

User service `fay-lid-open-safety.service` + script `fay-lid-open-safety`. Listens to logind's
`LidClosed`; if Omarchy's clamshell flag is still there 1 s after the lid opened, it runs
`omarchy-hyprland-monitor-clamshell` again and logs it (`journalctl --user -t fay-lid-open`).
Background: Omarchy missed 4 of 11 lid opens (omacom/omarchy#15307). Remove once fixed upstream.
