# Runbook: DCP display firmware (MacBook Air M3, J613)

Purpose: find out what the DCP (display controller) needs on Linux. Needed for
external displays over USB-C and for internal display output. Prerequisite for any
display driver work. See `README.md` and `STATE-2026-10-03.md` in this folder.

Status: premise corrected 2026-10-03. There is nothing to extract from macOS.

## Corrected premise

The first version of this runbook assumed the DCP firmware had to be extracted from
macOS into a tarball for `asahi-fwextract`. That is wrong:

- **iBoot loads the DCP firmware before Linux starts.** It comes from the boot
  firmware of the macOS stub container that the Asahi installer created ("M3 Omarchy",
  `disk3`, 2.5 GB). Only a small set of blobs is passed on to Linux through the
  vendorfw `firmware.cpio`; DCP is not one of them. Source: Asahi docs, "Open OS
  interop", Firmware provisioning
  (<https://asahilinux.org/docs/platform/open-os-interop/>).
- **`asahi-fwextract` has no DCP collector.** `asahi_firmware/` in the Asahi installer
  collects only WiFi, Bluetooth, multitouch, ISP, ALS and kernel firmware. No `dcp*`
  files are ever produced.
- **The real gap is the firmware ABI version.** The DCP driver
  (`drivers/gpu/drm/apple/dcp.c`, AsahiLinux/linux `asahi` branch) reads
  `apple,firmware-compat` from the device tree (set by m1n1) and only knows
  `DCP_FIRMWARE_V_12_3` and `DCP_FIRMWARE_V_13_5`. The M3 stub runs 14.x boot
  firmware (Asahi Alarm enabled 14.8.3 for M3, see `../README.md`). This matches the
  Asahi M3 announcement: full DCP support is still missing, which is why sleep and
  HDMI are disabled.

So the work is driver work (DCP support for the 14.x firmware), not a missing file.

## Safety rules

- Do NOT run the Asahi installer again on macOS. It repartitions the disk.
- Change nothing in macOS. Nothing in this runbook needs macOS any more.
- The Linux install stays. The next normal boot goes to Omarchy.

## Steps

1. ~~Boot macOS once.~~ Done 2026-10-03.
2. ~~Check the macOS version.~~ Done 2026-10-03: **macOS 27.0 (26A428)**, model
   Mac15,12 (J613). This is the main macOS install, not the stub; the stub's boot
   firmware is what DCP runs, and it is read in step 3.
3. **In Omarchy, read the DCP firmware version** that m1n1 put in the device tree:

   ```bash
   find /proc/device-tree -name 'apple,firmware-*' -exec sh -c 'printf "%s: " "$1"; tr -d "\0" < "$1"; echo' _ {} \;
   ```

   Record `apple,firmware-version` and `apple,firmware-compat` for the DCP node(s)
   here. If there is no DCP node, record that too.
4. **Tell Fay** the result.

Steps 3–5 of the first version (extraction, exFAT stick `FAYTESTa`, `asahi-fwextract`)
are dropped. The stick is not needed for this.

## After that (separate decisions)

- DCP device-tree node for J613. Check against the mainline and Asahi device trees first.
- DCP driver support for the 14.x firmware ABI on the 7.1 tree. The driver currently
  handles only 12.3 and 13.5; check the Asahi tree and mailing lists for ongoing M3
  DCP work before starting a port.

## Result of step 3 (2026-10-03, 15:55, booted Omarchy 7.1.13)

- `find /proc/device-tree -name 'apple,firmware-*'`: **no matches**. m1n1 did not provide
  `apple,firmware-version` or `apple,firmware-compat` on this system.
- DCP or DPTX node under `/proc/device-tree`: **none**.
- `/proc/device-tree/chosen` contains the boot strings `mBoot-20457.1.29`,
  `iBoot-10151.140.19.700.2`, `v1.6.1` (m1n1) and `14.7`. The meaning of `14.7` is not
  confirmed; check before relying on it.
- So the DCP firmware-ABI question is still open, and there is no DCP node to bind to.

## Draft m1n1 patch for t8122 (2026-10-03, DRAFT, not installed)

`patches/m1n1-t8122-carveout-DRAFT.patch` adds the t8122 carveout table with the DCP
segment regions 49, 50, 57, 94, 95 (from the ADT segment-ranges of the DCP nubs). It follows
the M2 table. It compiles (`BUILDSTD=1`). Not verified on hardware.

Update 2026-10-03, 22:30: the DCPEXT regions 73/74 are now in the draft, using the M1
(t8103) table as precedent (same IDs, flags copied). Builds.

Open before any install:
- Region 14 is /vram (boot framebuffer), already reserved by m1n1 `dt_vram_reserved_region()`. Not needed in the table.
- `dt_reserve_dcpext_firmware()` does not list t8122. Decide whether to add it (PR #608 added t6030 only).
- The t8112 flags (`map_dcp`, `map_disp`, `map_piodma`) are copied, not confirmed for t8122.
- `dt_reserve_dcpext_firmware` is not added for t8122.
- Boot chain layout of `/boot/m1n1/boot.bin` (6.2 MB) is not yet checked.
