# Steps for the hypervisor trace (target = Fay's Air, host = P15)

Two machines: the M3 Air (target, runs macOS 14.8.x under m1n1) and the P15 (host, Omarchy
Linux, USB-C cable to the Air's right-hand port). The employer-managed Air is not involved.

## A. On the Air, booted into macOS 27 (Marius)
1. Disk Utility (or Terminal) – free space in the macOS container ≥ ~25 GB:
   `diskutil apfs list` → note the container (diskN) of "Macintosh HD".
2. `sudo diskutil apfs addVolume diskN APFS macOSTest`
3. `softwareupdate --fetch-full-installer --full-installer-version 14.8.7`
   (14.8.3, the version Asahi pins for the HV, is no longer offered by Apple; oldest is 14.8.7 23J520.
   If the HV run fails on 14.8.7: signed 14.8.3 InstallAssistant.pkg from the archive linked on Asahi's
   m1n1-hypervisor page, verified with `pkgutil --check-signature`.)
   → "Install macOS Sonoma" in /Applications; run it and choose the volume macOSTest; delete the
   installer app afterwards (space is tight: 36.6 GB free).
4. Finish the setup assistant on macOSTest once (local account, no Apple ID, no FileVault needed).

## B. Still in macOSTest (14.8.x), copy its kernel to the EFI partition (Marius)
    sudo diskutil mount disk0s4          # partition label "EFI - M3 OM"
    cd /System/Volumes/Preboot/*/boot && cat active   # the active hash
    sudo cp /System/Volumes/Preboot/*/boot/$(cat /System/Volumes/Preboot/*/boot/active)/System/Library/Caches/com.apple.kernelcaches/kernelcache "/Volumes/EFI - M3 OM/kc-14.8.x.im4p"
(Fay converts it on Linux to a Mach-O and hands it to the P15.)

## C. Recovery (1TR) for macOSTest only (Marius)
1. Make macOSTest the startup disk (System Settings → Startup Disk), shut down.
2. Hold the power button → Options → Terminal.
3. `csrutil disable`   (choose macOSTest when asked)
4. `bputil -nkcas`     (choose macOSTest when asked)
5. `diskutil mount disk0s4`
6. `kmutil configure-boot -c "/Volumes/EFI - M3 OM/m1n1-hv-v1.9.9.bin" --raw --entry-point 2048 --lowest-virtual-address 0 -v /Volumes/macOSTest`
   (sha256 of the file: 2af681ed385434c0…)
7. Afterwards: set the startup disk back to the Linux entry (Asahi) so normal boots stay on Linux.

## D. Trace (P15 + Air)
1. P15: `git clone --branch v1.9.9 https://github.com/AsahiLinux/m1n1`, venv with `construct pyserial`,
   copy `trace_atc0_dp_t8122.py` and the kernelcache Mach-O from Fay.
2. Air: boot macOSTest from the boot picker → m1n1 waits on USB (no picture beyond the logo is normal).
3. P15: `sudo M1N1DEVICE=/dev/ttyACM0 venv/bin/python proxyclient/tools/run_guest.py -l fay-atc0-dp.log -m trace_atc0_dp_t8122.py kc-14.8.x.macho`
4. When macOS is up: unplug/replug the monitor (Air left-rear port), keep it in ~30 s; stop; keep the log.
5. Air: reboot into Linux (boot picker → the Asahi entry). Fay picks up the log.

## Undo
In macOS 27: delete the macOSTest volume (`sudo diskutil apfs deleteVolume <macOSTest volume>`).
The boot policy of macOS 27 and the Asahi entry are separate and stay unchanged.
