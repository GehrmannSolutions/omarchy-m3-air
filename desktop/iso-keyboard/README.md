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
