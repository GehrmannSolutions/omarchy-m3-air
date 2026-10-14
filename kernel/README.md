# Kernel: external displays on the MacBook Air M3

A 12-patch series (plus an experimental 10-patch set for the lid-closed case) on top of the Aurora kernel that drives the T8122 `dcpext` display coprocessor
through both USB-C ports of the J613 (MacBook Air 13" M3).

- **Base:** `omacom/linux-aurora`, branch `integration/aurora`, commit `80ee1e97`.
  Also applies cleanly to `67d8e916` (not built there).
- **Git branch:** [`GehrmannSolutions/linux-aurora` `fay/aurora-j613-dp-v2`](https://github.com/GehrmannSolutions/linux-aurora/tree/fay/aurora-j613-dp-v2)
  (same patches, review in [PR #1 there](https://github.com/GehrmannSolutions/linux-aurora/pull/1)).
- **Upstream:** the maintainer carries the 12 patches, reworked, as draft
  [omacom/linux-aurora#114](https://github.com/omacom/linux-aurora/pull/114): there the kernel turns
  `dcpext` on only when m1n1 sets `apple,t8122-dcpext-firmware-ready` ([../boot/](../boot/)).
- **Kernel release we run:** `7.1.12-fay-v2` = `patches/` + `patches-clamshell/` + `patches-local/0003`
  (since 2026-10-14).

## Patches (`patches/`)

| # | What |
|---|---|
| 0001 | pmdomain: request T8122 devices from the PMP by their record bits |
| 0002 | dts t8122: add `dcpext` and its display crossbars |
| 0003 | dts j613: wire `dcpext` to both USB-C ports |
| 0004 | drm/apple: bring back the 14.7 IOMFB template |
| 0005 | drm/apple: map a RAM page for the bandwidth scratch in dashboard mode |
| 0006 | drm/apple: drive the T8122 `dcpext` through the 14.7 IOMFB |
| 0007 | drm/apple: a failed `dcpext` never holds up the internal panel |
| 0008 | rtkit: honour `apple,sync-syslog-ack` |
| 0009 | display-gate: enable the T8122 `dcpext` after its power domains |
| 0010 | drm/apple: start and connect the T8122 `dcpext` as its own display |
| 0011 | drm/apple: a late power-off of the old display leaves the next one alone (port switching) |
| 0012 | drm/apple: log when a Type-C display waits for the single external pipeline |

`patches-local/` holds patches we use on our own machine but would not propose:
`0001`/`0002` (runtime front-port route, only needed with the stock boot.bin; superseded by
[boot/](../boot/)), `0003` (opt-in DPE block that makes the M3 GPU start; enable with
`asahi.t8122_dpe_leak=1`).

## Lid closed with two external displays (`patches-clamshell/`, experimental)

Eleven more patches on top of `patches/` that let the **internal** display pipeline drive a second
external display on the left-front port while the lid is closed, as macOS does
(background and test results: [../docs/clamshell.md](../docs/clamshell.md)). They are **unsigned
work in progress** (no `Signed-off-by` yet), tested on one machine with the test kernel `r12` (2026-10-13/14: all lid-closed tests
passed, see the docs) and in our daily kernel since 2026-10-14, and not part of a release.

| # | What |
|---|---|
| 0013 | drm/apple: the panel never waits for the internal pipe's Type-C route (needed by any kernel that boots with the new device tree) |
| 0014 | dts j613: give the internal `dcp` a (disabled) Type-C route to the front port; the front connector gets one endpoint per pipeline |
| 0015 | drm/apple: tell the internal DCP firmware the lid state (A475) |
| 0016 | drm/apple: the internal pipe drives a Type-C display while the lid is closed and the panel is off |
| 0017 | display-gate: enable the internal `dcp`'s route together with `dcpext` |
| 0018 | drm/apple: the "waits for a pipeline" log line says the display takes over by itself |
| 0019 | drm/apple: the panel reads disconnected while the lid is closed and is never powered then |
| 0020 | drm/apple: move the front display to the internal pipe when a rear display needs `dcpext` |
| 0021 | drm/apple: the panel comes back at once on lid open when its CRTC is already off |
| 0022 | drm/apple: route the front display to the pipeline the compositor pairs it with (internal pipe first while the lid is closed) |
| 0023 | drm/apple: when the lid closes and a rear display waits for `dcpext`, the front display moves to the internal pipe and the rear one takes `dcpext`; the boot-time move no longer runs under a running compositor |

Apply after `patches/` (`git am ../omarchy-m3-air/kernel/patches-clamshell/*.patch`). The device-tree
change is patch 0014, so boot.bin has to be rebuilt with the new J613 DTB
([../boot/](../boot/)). **A kernel without 0013 fails to start the internal panel on that device
tree**, so put 0013 into every kernel you might boot first. Use it together with
[../desktop/lid-policy/](../desktop/lid-policy/): without it logind suspends the closed laptop while
a display moves between pipelines.

Open items: after a resume the display that comes back first gets `dcpext`; a late power-off after
a quick unplug/replug of the rear display can still drop the new connection; the 3440x1440 test
display renegotiates once after every plug.

## Building

```sh
git clone -b integration/aurora https://github.com/omacom/linux-aurora && cd linux-aurora
git checkout 80ee1e97
git am ../omarchy-m3-air/kernel/patches/*.patch          # + patches-local/0003 for the GPU
zcat /proc/config.gz > .config                          # start from the running Aurora config
make LLVM=1 olddefconfig && make LLVM=1 -j8
```

The scripts in `scripts/` are the ones we use on our machine (paths under `~/.cache/fay-build/`,
kernel installed next to the packaged one with its own GRUB entry, original kept as fallback). They
check hashes and refuse to run on anything they do not expect; read them before adapting them.

The series also needs the device tree with `dcpext` in **boot.bin**, see [../boot/](../boot/).
Without it the kernel works as before and the USB-C ports carry no display.

## Kernel command line we use

`asahi.t8122_start=1` (set by the Aurora installer's `--m3-gpu`) and `asahi.t8122_dpe_leak=1`
(with `patches-local/0003`) for the GPU. Nothing else is needed for the displays.
