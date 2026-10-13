# Status and test criteria (2026-10-13)

Kernel `7.1.12-fay-v2` ([../kernel/](../kernel/)) with our boot.bin device tree ([../boot/](../boot/)).
Test displays: a 3440x1440 ultrawide with a USB hub (60 Hz over two DP lanes) and a portable 1080p
display. "Rear" = rear-left USB-C port, "front" = left-front USB-C port.

| # | Criterion | Result |
|---|---|---|
| K1 | Internal panel + GPU | ✅ |
| K2 | USB-C data (USB 2/3), Ethernet adapter, hub, charging | ✅ |
| K3 | Ultrawide on the rear port, USB devices on its hub | ✅ |
| K4 | Portable display alone on the front port | ✅ |
| K5 | Switch front → rear (unplug, plug) | ✅ twice without replugging |
| K6 | Switch rear → front | ✅ twice without replugging |
| K7 | After a failed plug, a replugged display comes back without a reboot | ✅ |
| K8 | Lid closed, two external displays | 🟡 works in the test kernel r11 with [desktop/lid-policy](../desktop/lid-policy/), not in a release yet ([clamshell.md](clamshell.md)) |
| K9 | No soft lockups, RCU stalls or "failed to acknowledge" | ✅ |
| K10 | Panel after a lid-closed boot + suspend | ❌ dark once on the development kernel; not yet tested on v2 |
| K11 | Screen is locked before suspend | 🟡 3 of 9 suspends unlocked on 10-11/12, the last three were fine |
| K12 | Front-port USB controller stays clean while a second display is refused | ✅ |
| K13 | Series: checkpatch clean (except trailers), W=1 clean | ✅ |
| K14 | PMP record-bit unit tests | ✅ 10/10 (user-space shim) |
| K15 | Reported upstream | 🟡 issues filed, see [upstream.md](upstream.md) |
| K16 | Room in /boot for the next kernel | ✅ |

## Known limits

- With the lid open only one external display works at a time: T8122 has one external display
  pipeline (`dcpext`). A second display waits; the kernel logs it and
  [desktop/display-busy-notify](../desktop/display-busy-notify/) shows a notification.
- Touch ID: no SEP node in the device tree.
- Omarchy sometimes misses a lid-open event: [desktop/lid-open-safety](../desktop/lid-open-safety/).
