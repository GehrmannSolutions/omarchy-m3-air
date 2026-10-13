# Archive: the first attempts before the Aurora kernel (2026-10-02 to 2026-10-11)

Kept as they were, for the record. **Superseded** — do not use these on a current system.

| Folder | Period | What |
|---|---|---|
| [01-usb-c-and-dcp-repro/](01-usb-c-and-dcp-repro/) | 10-02 to 10-11 | install notes, USB-C bring-up on Asahi 7.1 (sn201202x PD controller, ATC PHY patches), DCP/DART fault analysis and repro kit (patches 0007–0022), macOS ioreg extracts, m1n1 hypervisor trace, failed DP AUX experiments. Git history from the former `GehrmannSolutions/Omarchy` folder `Tools/arch-arm-apple-silicon/`. |
| [02-fay-dcp-kernel/](02-fay-dcp-kernel/) | 10-09 to 10-11 | the 7.2.2-fay-dcp kernel (DCP 14.x port on asahi-wip 7.2: diff, config, debug instrumentation, review patches), the aquamarine hotplug fix, the DART fault analysis, the hypervisor trace steps, the display README of 2026-10-11. |

What came out of it and lives on: the USB-C driver work (USB-C data, charging), the bandwidth
scratch fix (kernel patch 0005), the understanding of `dcpext` and the display crossbars. What did
not: the DP AUX power-up experiments, the DART instrumentation, the 7.2.2 DCP port (replaced by
Aurora's own DCP support).
