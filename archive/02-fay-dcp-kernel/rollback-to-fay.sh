#!/usr/bin/env bash
# Back from an Aurora test install to the pre-Aurora state of 2026-10-11 (fay-dcp + m1n1 main).
# Run after Aurora's own `bash install-aurora-sep.sh --uninstall` if that works; this script
# also works on its own. It restores boot.bin, the update-m1n1 freeze, /etc/default/grub and the
# package set (added packages removed, changed versions put back from the pacman cache).
set -euo pipefail
B=$(cat /var/lib/fay-backup/pre-aurora-LATEST)
echo "backup: $B"

# 1. packages: remove what was added; put back only the packages Aurora replaces or changes
#    (a normal system update in between is kept)
AURORA_TOUCHED='^(linux-asahi|m1n1|libfprint|aquamarine|grub|hyprtoolkit|hyprland-guiutils)$'
# package list taken right before the Aurora install (after the system update), else the first one
Q=$B/pacman-Q-before-install.txt; [[ -f $Q ]] || Q=$B/pacman-Q.txt
mapfile -t added < <(comm -13 <(cut -d' ' -f1 "$Q" | sort) <(pacman -Q | cut -d' ' -f1 | sort))
if ((${#added[@]})); then
  echo "removing added packages: ${added[*]}"
  sudo pacman -Rdd --noconfirm "${added[@]}"
fi
while read -r name ver; do
  [[ $name =~ $AURORA_TOUCHED ]] || continue
  cur=$(pacman -Q "$name" 2>/dev/null | cut -d' ' -f2) || cur=""
  [[ $cur == "$ver" ]] && continue
  f=$(ls "$B"/pkgs/"$name-$ver"-*.pkg.tar.* "$B"/pkgs/"$name-${ver/:/.}"-*.pkg.tar.* \
        /var/cache/pacman/pkg/"$name-$ver"-*.pkg.tar.* /var/cache/pacman/pkg/"$name-${ver/:/.}"-*.pkg.tar.* \
        2>/dev/null | grep -v '\.sig$' | head -1 || true)
  if [[ -n $f ]]; then
    echo "restoring $name $ver (was ${cur:-missing})"
    sudo pacman -Udd --noconfirm "$f"
  else
    echo "WARNING: no cached package for $name $ver (now ${cur:-missing})"
  fi
done < "$Q"

# Aurora's own state and m1n1 config
sudo rm -f /etc/m1n1.conf /etc/modprobe.d/aurora-sep.conf /etc/grub.d/43_fay_gpu_exp /etc/grub.d/44_fay_gpu_sweep /etc/systemd/system/fay-gpu-sweep.service /usr/local/sbin/fay-gpu-sweep
sudo systemctl disable --now aurora-sep-fallback-modules.service apple-sep.path apple-sep.service 2>/dev/null || true

# fay-dcp kernel moved out of /boot by bootclean.sh (2026-10-12)
if [[ -f /var/lib/fay-backup/bootclean-LATEST ]]; then
  C=$(cat /var/lib/fay-backup/bootclean-LATEST)
  for f in vmlinuz-fay-dcp initramfs-fay-dcp.img; do
    [[ -e $C/boot/$f && ! -e /boot/$f ]] && sudo cp -a "$C/boot/$f" /boot/
  done
fi

# 2. boot config: update-m1n1 freeze and GRUB defaults
sudo tar -C / -xpf "$B/etc-boot-config.tar" etc/default/update-m1n1 etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 3. m1n1 stage 2 last
sudo install -m 0755 "$B/boot.bin.m1n1main" /boot/m1n1/boot.bin
sync
sha256sum /boot/m1n1/boot.bin | cut -c1-16
echo "done: boot.bin = m1n1 main (01d657a4...), GRUB default restored. Pick fay-dcp with grub-reboot."
