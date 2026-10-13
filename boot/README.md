# boot.bin: device tree with dcpext on both USB-C ports

On Asahi/Aurora systems the device tree reaches the kernel through **boot.bin** (m1n1 stage 2 +
device trees + U-Boot), which `update-m1n1` rebuilds on package updates. The stock Aurora device
trees have no `dcpext`, so the USB-C ports carry no display. We build boot.bin with our own J613
device tree and pin it so package updates rebuild the same thing.

**We do not publish a prebuilt boot.bin.** A broken boot.bin means Linux does not start until you
restore the old one (from another boot entry or from macOS recovery). Only do this if you know how
to get back.

## What changes

- `m1n1-aurora-t8122-dcpext.patch` (against the Aurora m1n1 `d05ba17d`): m1n1 reserves the
  `dcpext` firmware and enables the node on T8122, as it already does on T8112. Not submitted to
  m1n1 (Asahi does not accept AI-assisted contributions).
- `j613-front-route.dts.patch`: the J613 device-tree source gets the left-front USB-C port as a
  second `dcpext` route (ATC1 crossbar). Kernel patches 0002/0003 in [../kernel/](../kernel/) add
  the rest of `dcpext`.

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

## Notes

- After this, `update-m1n1` (pacman hook) keeps building boot.bin from the pinned files. When
  Aurora's m1n1 or device trees change, the pinned files have to be rebuilt by hand.
- The packaged device tree has no SEP node either, so Touch ID does not work with or without this.
