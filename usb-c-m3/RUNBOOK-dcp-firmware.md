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
