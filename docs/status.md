# Status and test criteria (2026-10-14)

Kernel `7.1.12-fay-v2` ([../kernel/](../kernel/)): since 2026-10-14 the 12-patch series, the lid-closed set
(`patches-clamshell/`) and the local GPU patch, with our boot.bin device tree ([../boot/](../boot/)).
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
| K8 | Lid closed, two external displays | ✅ in our daily kernel since 2026-10-14 (all lid-closed tests passed on r12) with [desktop/lid-policy](../desktop/lid-policy/); experimental, not in a release yet ([clamshell.md](clamshell.md)) |
| K9 | No soft lockups, RCU stalls or "failed to acknowledge" | ✅ |
| K10 | Panel after a lid-closed boot + suspend | ✅ r12: lid-closed boot, lid opened hours later, panel on |
| K11 | Screen is locked before suspend | 🟡 3 of 9 suspends unlocked on 10-11/12; once more on 10-13 while the shell's lock state was stuck (fixed by restarting the shell) |
| K12 | Front-port USB controller stays clean while a second display is refused | ✅ |
| K13 | Series: checkpatch clean (except trailers), W=1 clean | ✅ |
| K14 | PMP record-bit unit tests | ✅ 10/10 (user-space shim) |
| K15 | Reported upstream | 🟡 the 12-patch series is carried as draft [omacom/linux-aurora#114](https://github.com/omacom/linux-aurora/pull/114); both requested test boots passed (2026-10-14); the m1n1 part is open, see [upstream.md](upstream.md) |
| K16 | Room in /boot for the next kernel | ✅ |
| K17 | Panel brightness keys | ❌ never worked: no backlight device on the 14.x firmware path ([omacom/linux-aurora#32](https://github.com/omacom/linux-aurora/issues/32)) |
| K18 | No Bluetooth timeouts when entering suspend | ❌ a few `hci0: command 0x0c01 tx timeout` on every lid-open suspend; Bluetooth stays on |

## Known limits

- With the lid open only one external display works at a time: T8122 has one external display
  pipeline (`dcpext`). A second display waits; the kernel logs it and
  [desktop/display-busy-notify](../desktop/display-busy-notify/) shows a notification.
- Touch ID: no SEP node in the device tree.
- Omarchy sometimes misses a lid-open event: [desktop/lid-open-safety](../desktop/lid-open-safety/).
- When the desktop blanks the screens (DPMS off, e.g. on the lock screen), the internal panel goes
  black but keeps its backlight on (since the first Omarchy start on this Mac).
- Brightness keys do nothing (K17); the panel keeps the brightness the firmware chose at power-on.
- Booting with the lid closed: nothing is shown on external displays before the desktop starts, so a
  disk-encryption password prompt is not visible; open the lid to type it.
