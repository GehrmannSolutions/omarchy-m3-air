# Installation (how this machine was set up)

1. **Asahi Alarm** from macOS (`curl https://asahi-alarm.org/installer-bootstrap.sh | sh`, Expert
   mode on the M3, minimal macOS kept for firmware updates), then Omarchy on top. The guided script
   [`omarchy-apple-silicon.sh`](omarchy-apple-silicon.sh) (run on the Mac) prints the right path
   for each chip; its background notes are in
   [../archive/01-usb-c-and-dcp-repro/README.md](../archive/01-usb-c-and-dcp-repro/README.md)
   (state 2026-10-02, the M3 caveats there are outdated).
2. **Aurora kernel** (2026-10-11) with the Aurora installer from
   [omacom/linux-aurora](https://github.com/omacom/linux-aurora) (`--m3-gpu`), which replaces
   `linux-asahi` with `linux-aurora` and adds the M3 GPU start. Run `omarchy update` first; the
   installer refuses with pending upgrades.
3. **Our kernel and boot.bin** for external displays: [../kernel/](../kernel/), [../boot/](../boot/).
4. **Desktop helpers:** [../desktop/](../desktop/).

Keep a backup of `/boot` (boot.bin, kernels, GRUB config) before steps 2 and 3, and never run the
Asahi installer a second time on an installed system.
