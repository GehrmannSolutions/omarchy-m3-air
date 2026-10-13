# Apple M3 USB-C fix: sn201202x PD controller driver

Problem: on the MacBook Air M3 running linux-asahi 7.1.13.asahi3, no USB device
is enumerated and `/sys/class/typec` is empty. The USB-C PD controllers
(`usb-pd@a`, `usb-pd@c`) have compatible `apple,sn201202x`, and no driver
binds to it.

Fix candidate: the LKML patch series "usb: typec: tipd: Add sn201202x (ACE3)
support", v2, 27 Jul 2026 (LKML 2607.3). Not yet merged upstream.

## Verified 2026-10-03

- `patches/0002` and `patches/0003` apply cleanly to the exact base commit
  `0ce37745d4bf` (mainline).
- Earlier failure was caused by the mailing-list archive obfuscating an email
  address in a context line (`heikki.krogerus@xxxxxxxxxxxxxxx`). Repaired to
  `heikki.krogerus@linux.intel.com`, which matches the tree. The patch files in
  `patches/` are repaired copies, not the raw mail.
- The patched base applies to the Asahi 7.1.13 tree with a three-way merge.
  Asahi's `core.c` differs from the base only in one i2c id line.
- The first patch (dt-bindings) is not in `patches/`. It is documentation only and
  does not affect the module build. Not yet recovered from the archive.

## Not yet verified

- Module build: blocked on `bc` (needed for `include/generated/timeconst.h`).
  Install needs root: `sudo pacman -S --needed bc`.
- vermagic of the new module versus `7.1.13-3-2-ARCH`.
- Load on the running kernel (`insmod` needs root).
- Actual USB enumeration after load (needs a device plugged in).

## Steps

1. `sudo pacman -S --needed bc` (root, not done by the script).
2. `./build-sn201202x-module.sh` (no root).
3. Compare vermagic with the installed `tps6598x.ko` (`modinfo -F vermagic`).
4. As root: copy `sn201202x.ko` and `tps6598x-core.ko` to
   `/usr/lib/modules/7.1.13-3-2-ARCH/kernel/drivers/usb/typec/tipd/`, `depmod`,
   `modprobe sn201202x`. Keep the old state for rollback: `rmmod`, remove the copies.
5. Check `/sys/class/typec`, then plug in a USB stick and check `/sys/bus/usb/devices`.

Rollback: `rmmod sn201202x` and delete the copied modules, then `depmod`.

## Status 2026-10-03

- Build succeeded with patches 0002 and 0003, plus local fix 0004 (missing
  `<linux/interrupt.h>` in `tps6598x.h`). Note: patch 0004 is applied after the
  series, so the build script must add it too. The script is not yet updated for it.
- Module vermagic matches the running kernel. Loaded with `modprobe sn201202x`.
  Type-C ports `port0` and `port1` now register.
- USB enumeration after a device is plugged in: not yet verified.

## Second blocker found 2026-10-03: PHY pipehandler lock

After the PD driver was loaded and port0 saw a partner (YubiKey), the xHCI hosts
came up, but no device enumerated. Kernel log:

    phy-apple-atc 703000000.phy: Pipehandler lock not acked.
    phy-apple-atc 703000000.phy: Failed to lock pipehandler

Fix candidate: patch 0005 (retry the lock up to 10 times with 5–10 ms backoff).
It is the minimal part of upstream PR AsahiLinux/linux #503 ("Fix/atcphy
pipehandler", open, base `asahi`). That PR was written for an M1 MacBook Air
with a USB-C hub. Its teardown change is not included here.

- Built `phy-apple-atc.ko` with vermagic `7.1.13-3-2-ARCH SMP preempt mod_unload aarch64`.
  All undefined symbols are provided by the running kernel.
- Not installed. The PHY is in use by dwc3-apple, so swapping it needs either a
  reboot or unbinding the drivers. Both need root and a decision from Marius.
