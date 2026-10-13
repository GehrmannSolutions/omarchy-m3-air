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

## Status (2026-10-13)

| Area | Status |
|---|---|
| Internal panel | works (Aurora DCP, firmware 14.7 interface) |
| GPU (M3 G15G) | works on Aurora with the DPE block (`asahi.t8122_dpe_leak=1`) and mesa-m3 |
| External display over USB-C, either port | works with our series ([kernel/](kernel/)) and our boot.bin DT ([boot/](boot/)) |
| Switching the display between the two ports | works both ways without replugging |
| Second external display at the same time | not possible with the lid open (one external pipeline); the second display waits and the desktop says so |
| Lid closed, one external display | works ([desktop/lid-open-safety](desktop/lid-open-safety/) covers missed lid-open events) |
| Lid closed, two external displays | works in a development kernel; clean version in progress ([docs/clamshell.md](docs/clamshell.md)) |
| USB-C data (USB 2/3), Ethernet adapters, hubs, charging | works |
| Wi-Fi, Bluetooth, suspend (s2idle) | works |
| Touch ID | not working (no SEP node in the device tree) |

Details and test criteria: [docs/status.md](docs/status.md).

## Layout

| Folder | What |
|---|---|
| [install/](install/) | how the machine was installed (Asahi Alarm, Omarchy, Aurora) |
| [kernel/](kernel/) | the patch series on top of Aurora (12 patches) and the scripts we build it with |
| [boot/](boot/) | how our boot.bin is built: m1n1 change and device-tree change, no prebuilt binary |
| [desktop/](desktop/) | small user services and fixes for Omarchy on this Mac |
| [docs/](docs/) | status, lid-closed work, upstream reports |
| [archive/](archive/) | the first attempts before the Aurora kernel (2026-10-02 to 10-11), kept as they were |

## Releases

Releases are snapshots of a state that ran on the machine. The first ones are source only (patches,
recipes, scripts); later ones may add a packaged kernel. There will be no prebuilt boot.bin.

## Credits

Built on the work of the Asahi Linux project (m1n1, kernel drivers, installer), the Aurora kernel
(omacom/linux-aurora, formerly iconidentify/aurora-linux) and Omarchy. All bugs here are ours.
