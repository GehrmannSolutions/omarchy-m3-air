# ISO keyboard: swap `<>` and the key left of 1

`hid_apple` auto-detects ISO keyboards, but not the internal MTP keyboard of the MacBook Air M3
([omacom/linux-aurora#350](https://github.com/omacom/linux-aurora/issues/350)), so the `<>` key and
the key left of 1 come out swapped. `iso_layout=1` forces the swap. **Only for ISO keyboards**: on an
ANSI (US) Mac it swaps keys that were right.

- `tmpfiles.d-90-tars-hid-apple-iso.conf` sets the parameter at every boot; this works at once
  and needs no new boot image.
- `modprobe.d-90-tars-hid-apple-iso.conf` sets it when `hid_apple` loads; `hid_apple` is in the
  boot image, so this takes effect with the next kernel update (or a rebuilt boot image).

Install: copy them to `/etc/tmpfiles.d/90-tars-hid-apple-iso.conf` and `/etc/modprobe.d/90-tars-hid-apple-iso.conf`,
then `sudo systemd-tmpfiles --create`. Undo: remove both files and reboot.

Checked on 2026-11-13 on a German ISO J613: without the setting the key left of 1 sends `KEY_102ND`
(`<`) and the key next to left Shift sends `KEY_GRAVE` (`^`); with `iso_layout=1` both are right.

## External Logitech keyboard (Mac variant)

A Logitech keyboard in the Mac layout on a Logitech USB receiver sends the same two keys swapped, and
`hid_apple` does not handle it (it is a `usbhid` device). `hwdb-90-tars-logitech-iso.hwdb` swaps them
back for the receiver `046d:c548` (Bolt); change the product id for another receiver (`lsusb`).
It applies to every keyboard paired with that receiver, so leave it out for a PC-layout Logitech.

Install: copy it to `/etc/udev/hwdb.d/90-tars-logitech-iso.hwdb`, then
`sudo systemd-hwdb update && sudo udevadm trigger -s input`. Undo: remove it and run the same two commands.
