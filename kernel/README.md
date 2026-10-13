# Kernel: external displays on the MacBook Air M3

A 12-patch series on top of the Aurora kernel that drives the T8122 `dcpext` display coprocessor
through both USB-C ports of the J613 (MacBook Air 13" M3).

- **Base:** `omacom/linux-aurora`, branch `integration/aurora`, commit `80ee1e97`.
  Also applies cleanly to `67d8e916` (not built there).
- **Git branch:** [`GehrmannSolutions/linux-aurora` `fay/aurora-j613-dp-v2`](https://github.com/GehrmannSolutions/linux-aurora/tree/fay/aurora-j613-dp-v2)
  (same patches, review in [PR #1 there](https://github.com/GehrmannSolutions/linux-aurora/pull/1)).
- **Kernel release we run:** `7.1.12-fay-v2`.

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
