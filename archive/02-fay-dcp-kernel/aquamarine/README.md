# aquamarine 0.15.1-1.2 (fay)

Arch PKGBUILD (gitlab.archlinux.org/archlinux/packaging/packages/aquamarine @ 33bf60a) plus
aq-renderless-hotplug.patch: on a DRM backend without a primary, a failing initMgpu() no longer
makes updateSecondaryRendererState() fail, so connect() keeps hotplugged outputs (DP-1 coming up
after Hyprland started). Same idea as the existing evdi special case (rendererRequired = false).

Build (2026-10-11): sync DB was stale (cmake 404 on mirror), so cmake came from a PyPI venv:
  sudo pacman -S --asdeps hyprwayland-scanner; PATH=<venv>/bin:$PATH makepkg -fd
Install: sudo pacman -U aquamarine-0.15.1-1.2-aarch64.pkg.tar.xz
Rollback: sudo pacman -U /var/lib/fay-backup/aquamarine-20261011/aquamarine-0.15.1-1-aarch64.pkg.tar.xz
pkgrel 1.2 > extra 0.15.1-1 and omarchy 0.15.1-1.1, so -Syu keeps it until a newer pkgver/pkgrel
lands in extra; that update silently drops the patch again (check pacman -Q aquamarine).
