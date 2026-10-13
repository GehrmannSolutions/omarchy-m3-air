# HV trace of DP alt mode on the M3 Air (Fay ↔ Mika)

Roles (updated 2026-10-10): target = Fay's Air (private Mac15,12; the other Air is employer-managed,
no changes there) with an extra APFS volume running macOS 14.8.3, the only macOS the m1n1 hypervisor
supports as a guest on M3. Host = Marius's PC (Linux) or, user-level only, the other Mac; it runs the
m1n1 v1.9.9 proxyclient over a USB-C cable to the target's right-hand port. Monitor in the target's
left-rear port (atc0).

- `m1n1-v1.9.9-8095415.bin`: non-release build of tag v1.9.9 (commit 8095415), for
  `kmutil configure-boot -c m1n1.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v /Volumes/macOSTest`
  in 1TR on the target. Check SHA256SUMS first.
- `trace_atc0_dp_t8122.py`: hypervisor script, run by the host with
  `run_guest.py -l fay-atc0-dp.log -m trace_atc0_dp_t8122.py <14.8.3 kernelcache.macho>`.

Target steps (Marius/Mika on the target Mac):
1. `diskutil apfs addVolume <container> APFS macOSTest` (container of the internal disk, see
   `diskutil list`); needs ~25 GB free.
2. `softwareupdate --fetch-full-installer --full-installer-version 14.8.3`, then install
   macOS 14.8.3 onto the volume "macOSTest" (finish the setup assistant once).
3. Shut down, hold the power button → Options (1TR). Pick the macOSTest volume where asked:
   `bputil -nkcas` (macOSTest only), `csrutil disable`, then the `kmutil configure-boot` line above
   with the m1n1 binary copied to a reachable path.
4. Kernelcache: /System/Volumes/Preboot/<uuid>/boot/<active hash>/System/Library/Caches/
   com.apple.kernelcaches/kernelcache of macOSTest → IM4P → Mach-O; hand it to Fay.
5. Boot macOSTest: m1n1 starts and waits for the host (proxy mode). Fay runs run_guest.py.
Undo: in 1TR delete the macOSTest volume (main macOS keeps its own boot policy).
