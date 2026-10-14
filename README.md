# Omarchy on the MacBook Air M3 (J613)

Unofficial notes, patches and snapshots from running [Omarchy](https://omarchy.org) on a
MacBook Air 13" M3 (2024, J613 / T8122) with Arch Linux ARM and the
[Aurora kernel](https://github.com/omacom/linux-aurora). This is the development record of one
machine: what works, how we got there, and the state we run every day.

> **Unofficial and experimental.** Nothing here is supported by Asahi Linux, Aurora or Omarchy.
> The kernel patches and the boot.bin recipe change how the Mac boots. A wrong boot.bin can leave
> the Mac unable to start Linux until you repair it from macOS recovery. Read the folder READMEs
> before you use anything, and keep a working fallback boot entry.
>
> This work was done with AI assistance (Claude Code). It is **not** submitted to Asahi Linux or
> m1n1, whose policies forbid AI-assisted contributions. Upstream reports go only to projects that
> accept disclosed AI-assisted work (see [docs/upstream.md](docs/upstream.md)).

## Status (2026-10-14)

| Area | Status |
|---|---|
| Internal panel | works (Aurora DCP, firmware 14.7 interface) |
| GPU (M3 G15G) | works on Aurora and mesa-m3 (the #114 base writes the power block itself; older bases need our DPE patch, `asahi.t8122_dpe_leak=1`) |
| External display over USB-C, either port | works with our series ([kernel/](kernel/)) and our boot.bin DT ([boot/](boot/)) |
| Switching the display between the two ports | works both ways without replugging |
| Second external display at the same time | not possible with the lid open (one external pipeline); the second display waits and the desktop says so |
| Lid closed, one external display | works ([desktop/lid-open-safety](desktop/lid-open-safety/) covers missed lid-open events) |
| Lid closed, two external displays | works in our daily kernel with the [lid-policy](desktop/lid-policy/) helper; experimental patches in [kernel/patches-clamshell/](kernel/patches-clamshell/), not in a release yet ([docs/clamshell.md](docs/clamshell.md)) |
| USB-C data (USB 2/3), Ethernet adapters, hubs, charging | works |
| Wi-Fi, Bluetooth, suspend (s2idle) | works (Bluetooth logs a few command timeouts when entering suspend) |
| Panel brightness keys | not working: no backlight control on the 14.x firmware path ([omacom/linux-aurora#32](https://github.com/omacom/linux-aurora/issues/32)) |
| Touch ID | not working (no SEP node in the device tree) |
| CPU temperature limit | works since 2026-10-14 with thermal zones in our boot.bin device tree; before, nothing throttled and the P cores reached 111 C ([docs/power-and-thermal.md](docs/power-and-thermal.md)) |
| Battery life | about 7 h of mixed use, about 9 h idle with the screen on; GPU capped at 618 MHz for now ([docs/power-and-thermal.md](docs/power-and-thermal.md)) |

Details and test criteria: [docs/status.md](docs/status.md).

## Layout

| Folder | What |
|---|---|
| [install/](install/) | how the machine was installed (Asahi Alarm, Omarchy, Aurora) |
| [kernel/](kernel/) | the patch series on top of Aurora (12 patches, plus 10 experimental ones for the lid-closed case) and the scripts we build it with |
| [boot/](boot/) | how our boot.bin is built: m1n1 change and device-tree change, no prebuilt binary |
| [desktop/](desktop/) | small user services and fixes for Omarchy on this Mac |
| [docs/](docs/) | status, lid-closed work, power and temperatures, upstream reports |
| [archive/](archive/) | the first attempts before the Aurora kernel (2026-10-02 to 10-11), kept as they were |

## Releases

Releases are snapshots of a state that ran on the machine. The first ones are source only (patches,
recipes, scripts); later ones may add a packaged kernel. There will be no prebuilt boot.bin.

## License

Our own scripts, units and documentation are under the [MIT license](LICENSE) unless a file says
otherwise (scripts carry `SPDX-License-Identifier` headers). Patches stay under the license of the
project and file they change; the full texts are in [LICENSES/](LICENSES/):

| Files | License |
|---|---|
| everything we wrote (scripts, systemd units, READMEs, docs) | MIT |
| driver changes in `kernel/patches*/` and the DCP/display diffs in `archive/` | GPL-2.0-only OR MIT, as the changed files in `drivers/gpu/drm/apple`, `drivers/gpu/drm/asahi`, `drivers/soc/apple`, `drivers/pmdomain/apple` |
| device-tree changes (`*.dts`, `*.dtsi`, `*.dtso` in any patch, `boot/j613-front-route.dts.patch`) | GPL-2.0-or-later OR MIT, as `arch/arm64/boot/dts/apple/` |
| other Linux kernel changes in `archive/` (e.g. `drivers/usb/typec/tipd`, `drivers/iommu`) | GPL-2.0-only, as the Linux kernel |
| `boot/m1n1-aurora-t8122-dcpext.patch`, m1n1 drafts in `archive/` | MIT, as m1n1 |
| `archive/02-fay-dcp-kernel/aquamarine/` | BSD-3-Clause, as aquamarine |

The files in `archive/` were left unchanged and carry no headers; the table above applies to them.

## Credits

Built on the work of the Asahi Linux project (m1n1, kernel drivers, installer), the Aurora kernel
(omacom/linux-aurora, formerly iconidentify/aurora-linux) and Omarchy. All bugs here are ours.
