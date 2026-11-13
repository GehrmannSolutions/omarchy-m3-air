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

## Status (2026-11-13)

**Since 2026-11-04 this Mac runs Omarchy's official packages** (Omarchy Mac, `linux-aurora`,
`m1n1-aurora`, Limine), moved over with `omarchy-mac-migrate`
([omacom/omarchy-mac#690](https://github.com/omacom/omarchy-mac/pull/690)). Since 2026-11-12 it is on
the **edge** channel: Omarchy 4.5, `linux-aurora` 7.2.11.aurora16, `m1n1-aurora` 1.6.1.aurora23.
Our own kernel, our boot.bin and most of this repo are no longer needed for daily use: external
displays over USB-C now come from the packages (our series landed upstream as
[omacom/linux-aurora#114](https://github.com/omacom/linux-aurora/pull/114)). What is still ours: the
lid-closed second display ([#127](https://github.com/omacom/linux-aurora/pull/127), open) and a few
desktop helpers.

| Area | Status on the official packages (edge, aurora16) |
|---|---|
| Internal panel, GPU (M3 G15G) | works; GPU capped at 618 MHz by the package |
| Panel brightness keys | works (`apple-panel-bl`) |
| Keyboard backlight | works (Ctrl+F1/F2) |
| Speakers, microphone | works |
| Touch ID | works with Omarchy's own setup (`omarchy setup security fingerprint`), incl. sudo and the lock screen |
| External display over USB-C, either port | works, **one at a time**: a second display waits for the single external pipeline and lights up when the first one is unplugged |
| Lid closed, two external displays | not in the packages yet: works with our open PR [#127](https://github.com/omacom/linux-aurora/pull/127) (tested on aurora16 on 2026-11-12) |
| Sound over DisplayPort | not working yet |
| USB-C data, hubs, Ethernet adapters, charging | works; a monitor's USB hub stays dead if it is plugged in while another display holds the pipeline ([#163](https://github.com/omacom/linux-aurora/pull/163) fixes it; until then unplug one display before plugging the other, a reboot clears it) |
| Wi-Fi, Bluetooth | works; Wi-Fi with wpa_supplicant (iwd fails on this chip, [omarchy-mac#781](https://github.com/omacom/omarchy-mac/issues/781)) |
| Suspend (s2idle) | works, but drains the battery overnight with the lid closed on battery ([#403](https://github.com/omacom/linux-aurora/issues/403)) |
| CPU temperature limit | works (CPU thermal zones in the packaged device tree) |
| Clock | starts at 1970 on every boot until NTP corrects it ([omarchy-mac#782](https://github.com/omacom/omarchy-mac/issues/782)) |
| ISO keyboard | the `<>` key and the key left of 1 are swapped ([#350](https://github.com/omacom/linux-aurora/issues/350)); fixed here with `hid_apple` `iso_layout=1` ([desktop/iso-keyboard](desktop/iso-keyboard/)) |

Details and the older test record: [docs/status.md](docs/status.md).

## Layout

| Folder | What |
|---|---|
| [install/](install/) | how the machine was installed, and the move to the official packages |
| [kernel/](kernel/) | history: our patch series on top of Aurora (now upstream as #114) and the lid-closed patches |
| [boot/](boot/) | history: how our boot.bin was built; not needed with `m1n1-aurora` aurora23 and later |
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
