# Install the WIP kernel 7.2.2-fay-dcp (run by Marius in a terminal, needs sudo)

Kernel: `asahi-wip-7.2` (head 236788cd) + PR #608, built 2026-10-03, `BUILD_EXIT=0`.
Tree: `~/.cache/fay-build/wip`. Config copy: memory stick `fay-backup-20261003/kernel-config/`.

The module folder name `7.2.2-fay-dcp` has no `-ARCH` suffix, so `update-m1n1` ignores it.
The current kernel 7.1.13-3-2-ARCH stays installed and stays the first GRUB entry.

## Commands

```
# 1. Modules into /usr/lib/modules/7.2.2-fay-dcp (also runs depmod)
cd ~/.cache/fay-build/wip && sudo make ARCH=arm64 modules_install

# 2. Kernel image
sudo install -m 0644 ~/.cache/fay-build/wip/arch/arm64/boot/Image /boot/vmlinuz-fay-dcp

# 3. Initramfs (LUKS root needs the encrypt hook from mkinitcpio.conf)
sudo mkinitcpio -k 7.2.2-fay-dcp -g /boot/initramfs-fay-dcp.img

# 4. Regenerate the GRUB menu
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 5. Check
ls -la /boot | grep -E 'fay-dcp'
grep -n "menuentry 'Omarchy" /boot/grub/grub.cfg
```

Check step 4: the first `Omarchy Linux` entry must still boot the 7.1.13 kernel
(`linux /vmlinuz-linux-asahi`). If the new kernel is first, boot the old one from the GRUB menu
within 5 seconds (menu style). Do not change `GRUB_DEFAULT` without reading the result first.

## Rollback

```
sudo rm -f /boot/vmlinuz-fay-dcp /boot/initramfs-fay-dcp.img
sudo rm -rf /usr/lib/modules/7.2.2-fay-dcp
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Boot blob rollback: `sudo install -m 0644 /var/lib/fay-backup/bootchain-20261003/boot.bin.orig /boot/m1n1/boot.bin`
(sha256 must be 566227f96ea94baf...). Also on the stick `recovery/`.
