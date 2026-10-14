# boot.bin: device tree with dcpext on both USB-C ports

On Asahi/Aurora systems the device tree reaches the kernel through **boot.bin** (m1n1 stage 2 +
device trees + U-Boot), which `update-m1n1` rebuilds on package updates. The stock Aurora device
trees have no `dcpext`, so the USB-C ports carry no display. We build boot.bin with our own J613
device tree and pin it so package updates rebuild the same thing.

**We do not publish a prebuilt boot.bin.** A broken boot.bin means Linux does not start until you
restore the old one (from another boot entry or from macOS recovery). Only do this if you know how
to get back.

## What changes

- `m1n1-aurora-t8122-dcpext.patch` (against the Aurora m1n1 `d05ba17d`): on T8122 m1n1 reserves the
  `dcpext` firmware and sets its firmware version, leaves the node **disabled** and marks it
  `apple,t8122-dcpext-firmware-ready = <1>`. The kernel's display gate enables `dcpext`, its
  DARTs, mailbox, crossbars and routes only when it finds that marker, so a kernel that cannot
  drive `dcpext` never sees it. m1n1 enables nothing else. Not submitted to m1n1 (its rules do not
  accept AI-assisted contributions; we asked the Aurora maintainers how to handle that).
- The device trees come from the kernel tree: since 2026-10-14 from
  [omacom/linux-aurora#114](https://github.com/omacom/linux-aurora/pull/114) plus kernel patch 0002
  of [../kernel/patches-clamshell/](../kernel/patches-clamshell/). #114 already wires `dcpext` to
  both USB-C ports, so `j613-front-route.dts.patch` (our earlier front-port route for the
  `patches/` series) is kept only for that older series.

## How we build and install it (`scripts/`)

1. Build m1n1 with the patch, build the DTBs from the patched kernel tree.
2. `build-bootbin.sh M1N1_BIN OUT DTB...` builds boot.bin the same way `update-m1n1` does
   (m1n1 + DTBs + gzipped U-Boot + the options from `/etc/m1n1.conf`), writing only to `OUT`.
3. `install-bootbin-front.sh` (as used on our machine): checks the current boot.bin hash, backs up
   boot.bin and `/etc/default/update-m1n1` to `/var/lib/fay-backup/`, installs m1n1 and the DTBs to
   `/usr/local/lib/fay-boot`, points `/etc/default/update-m1n1` there (`M1N1=`, `DTBS=`) and
   rebuilds boot.bin. `uninstall-bootbin-front.sh` restores the backup.

The install script refuses to run unless the hashes match our machine. Adapt it consciously or do
the steps by hand.

## Our current boot.bin (2026-10-14)

Our m1n1 (patch above) + every DTB built from #114 + `patches-clamshell/`, built with
`scripts/build-bootbin-c114.sh`, installed with `scripts/install-bootbin-c114.sh` (same pinned
`/usr/local/lib/fay-boot` and `/etc/default/update-m1n1`; backup and hash checks as above);
`scripts/uninstall-bootbin-c114.sh` restores the backup. In these device trees `dcpext`, its DARTs,
mailbox and crossbars, and the internal `dcp`'s new route are all disabled; the gate turns them on.

**Read before installing it:** every kernel you boot with this device tree needs kernel patch 0001
of `patches-clamshell/` (without it the internal DCP refuses the empty route container and the
panel stays on the boot framebuffer) and #114's gate (without it no external display). The
`install-bootbin-clamshell.sh`/`-front.sh` scripts are the earlier steps for the `patches/` series.

## Notes

- After this, `update-m1n1` (pacman hook) keeps building boot.bin from the pinned files. When
  Aurora's m1n1 or device trees change, the pinned files have to be rebuilt by hand.
- The packaged device tree has no SEP node either, so Touch ID does not work with or without this.
