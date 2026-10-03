# Runbook: DCP display firmware from macOS (MacBook Air M3, J613)

Purpose: get the DCP (display controller) firmware out of macOS, so that the
Asahi tools can build the vendor firmware tarball for Linux. Needed for external
displays over USB-C and for internal display output. Prerequisite for any display
driver work. See `README.md` and `STATE-2026-10-03.md` in this folder.

Status: prepared, not started.

## Safety rules

- Do NOT run the Asahi installer again on macOS. It repartitions the disk.
- Only the firmware extraction step is needed. Change nothing else in macOS.
- The Linux install stays. The next normal boot goes to Omarchy.

## Steps

1. **Boot macOS once.** Power on, hold the power button until the startup options
   appear, choose macOS.
2. **Check the macOS version.** Apple menu, About This Mac. Note it in the
   runbook result.
3. **Get the extraction instructions from the Asahi documentation** (asahilinux.org,
   current docs). The exact command is not written here on purpose: take it from the
   docs and check it before running.
4. **Run only the extraction step.** The result is a firmware tarball with the DCP
   files (`dcp*`) for J613.
5. **Copy the tarball to an exFAT USB stick.** Use the stick `FAYTESTa` (empty,
   labelled by us). Do not use `GS-Data` or the other sticks.
6. **Reboot into Omarchy** (boot picker, Linux).
7. **Tell Fay.** Then: mount the stick, check the tarball contents, run
   `asahi-fwextract` on it, and compare with the firmware survey in the plan.

## After extraction (separate decisions)

- DCP device-tree node for J613. Check against the mainline and Asahi device trees first.
- DCP driver for the 7.1 tree. The Asahi DCP branches are from 2022–2023 and need porting.
