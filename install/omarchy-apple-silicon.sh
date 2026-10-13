#!/usr/bin/env bash
# Arch Linux ARM / Omarchy on Apple Silicon — guided setup (GEH-37).
# Run this on the Mac itself. It detects the chip and walks through the
# right path: bare metal (M1/M2 proven, M3 new with caveats) or a native
# aarch64 VM (M3 Ultra / M4 / M5 / no-repartition).
# It never partitions a disk itself; the bare-metal path only prints the
# commands and hands off to the official Asahi installer interactively.
set -euo pipefail

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "Run this on the Mac (macOS), not on Linux."
[[ "$(uname -m)" == "arm64" ]] || die "This Mac is not Apple Silicon."

chip="$(sysctl -n machdep.cpu.brand_string)"   # e.g. "Apple M2 Pro"
say "Detected chip: $chip"

bare_metal_ok=false
is_m3=false
case "$chip" in
  *" M1"*|*" M2"*) bare_metal_ok=true ;;
  *" M3 Ultra"*)   ;;  # Asahi does not support M3 Ultra
  *" M3"*)         bare_metal_ok=true; is_m3=true ;;
esac

if $bare_metal_ok; then
  if $is_m3; then
    say "This is an M3-family Mac: bare metal is supported since Sept 2026, with caveats:"
    note "- NO GPU 3D acceleration yet: the desktop runs software-rendered (slower than M1/M2)."
    note "- Sleep does not work; the HDMI port on MacBook Pros is disabled."
    note "- omarchy-mac is tested on M1/M2; on M3 treat the Omarchy layer as experimental."
    note "- M3 support is gated behind the installer's Expert mode: answer 'y' at"
    note "  'Enable expert mode?', then press Enter to keep the default firmware version."
  else
    say "This is an M1/M2-family Mac: bare metal (dual-boot next to macOS) is supported."
  fi
  note "Requirements: macOS 15+, a current backup, >=50 GB free (100 GB recommended)."
  note "Note: macOS cannot be fully removed on Apple Silicon (firmware lives there)."
  note "For a 'single boot' feel, shrink macOS to the minimum in the Asahi installer;"
  note "Linux becomes the default startup volume."
  printf '\nInstall bare metal now? [y/N] '
  read -r ans
  if [[ "${ans:-}" =~ ^[Yy] ]]; then
    say "Step 1/2: Asahi Alarm installer (choose 'Asahi Alarm Minimal (BTRFS)', >=50 GB)."
    note "The installer is interactive and handles partitioning safely."
    curl https://asahi-alarm.org/installer-bootstrap.sh | sh
    say "Step 2/2 happens after you reboot into Arch:"
    note "1. Log in as root / root"
    note "2. Connect Wi-Fi:  nmtui"
    note "3. Install Omarchy:"
    note "   curl -fsSL https://raw.githubusercontent.com/omarchy-mac/omarchy-mac/quattro/bin/omarchy-mac-setup | bash"
    exit 0
  fi
  say "Skipping bare metal. Falling through to the VM path."
else
  say "This chip has no Asahi/bare-metal support yet (M4/M5/M3 Ultra). Using the VM path."
fi

say "VM path: native aarch64 Omarchy in UTM."
command -v brew >/dev/null || die "Homebrew is required for this path: https://brew.sh"
if [[ ! -d /Applications/UTM.app ]]; then
  note "Installing UTM..."
  brew install --cask utm
fi

printf '\nChoose: [1] download prebuilt image (~3.6 GB, community-built)  [2] build from source (~1 h): '
read -r choice
workdir="$HOME/omarchy-arm"
mkdir -p "$workdir"

case "${choice:-1}" in
  2)
    say "Building Omarchy ARM UTM image from source (8 resumable phases)."
    [[ -d "$workdir/omarchy-arm-utm" ]] || git clone https://github.com/ggalancs/omarchy-arm-utm.git "$workdir/omarchy-arm-utm"
    cd "$workdir/omarchy-arm-utm"
    ./build-omarchy-arm.sh
    ;;
  *)
    say "Downloading prebuilt image from archive.org (community-built; build from"
    note "source instead if you prefer not to trust a third-party image)."
    cd "$workdir"
    curl -L -C - -o omarchy-arm-utm-v2.zip \
      "https://archive.org/download/omarchy-arm-utm/omarchy-arm-utm-v2.zip"
    unzip -o omarchy-arm-utm-v2.zip
    utm_bundle="$(find "$workdir" -maxdepth 2 -name '*.utm' | head -1)"
    [[ -n "$utm_bundle" ]] || die "No .utm bundle found after unzip — check $workdir"
    say "Opening in UTM: $utm_bundle"
    open "$utm_bundle"
    ;;
esac

say "Done. Notes for the UTM VM:"
note "- Option (Alt) key acts as SUPER (macOS intercepts Cmd)."
note "- No GPU acceleration: software rendering only; single monitor."
note "- Set the resolution at boot; changing it at runtime white-screens."
note "- Daily-driver tuning: https://github.com/dchersey/omarchy-apple-silicon-utm"
