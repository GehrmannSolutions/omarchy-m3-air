# Arch Linux ARM (Omarchy) on Apple Silicon — GEH-37

Goal: a fully working Arch Linux ARM environment on Apple M\* Macs, ideally
running Omarchy so the themes/tools in this repo apply.

State of the ecosystem (verified 2026-10-02):

| Your Mac | Recommended path | Status |
|---|---|---|
| **M1 / M2** (incl. Pro/Max/Ultra) | **Bare metal**: Asahi Alarm + `omarchy-mac` dual-boot alongside macOS | Working today. GPU, Wi‑Fi, Touch ID, external displays via USB‑C, disk encryption. |
| **M3 / M3 Pro / M3 Max** | **Bare metal** via Asahi Alarm — support shipped Sept 2026 | New. Wi‑Fi, Bluetooth, USB 3, webcam, mics, HW video decode all work. **No GPU 3D acceleration yet** (desktop is software-rendered), no sleep, HDMI port disabled. M3 Ultra not supported. |
| **M4 / M5** | **VM**: native aarch64 Omarchy in UTM (free) or Parallels (better graphics) | Asahi M4/M5 support still in development — no bare-metal option yet. |
| Any M\* chip, vanilla Arch (no Omarchy) | Arch Linux ARM aarch64 VM in UTM | Trivial; UTM gallery has ALARM images. |

## "Single boot" on Apple Silicon — what's actually possible

Pure single boot (Linux only, macOS fully removed) is **not possible on any
Apple Silicon Mac** by platform design: the boot chain requires a macOS
"stub" partition holding Apple's bootloader, firmware and a recovery image
(~2.5 GB). Deleting the full macOS install beyond that stub is explicitly
unsupported by Asahi — system firmware updates only come through macOS.

The closest supported setup — and what this guide recommends for a
"single boot" goal: keep a **minimal macOS** (~15–20 GB) for firmware
updates, give the entire rest of the SSD to Linux during the Asahi install,
and leave Linux as the default startup volume. The Mac then boots straight
into Arch every time; macOS exists only as a maintenance partition you never
see unless you hold the power button at boot.

The helper script in this directory, [`omarchy-apple-silicon.sh`](omarchy-apple-silicon.sh),
detects your chip and walks you through the right path. Run it **on the Mac**:

```bash
bash Tools/arch-arm-apple-silicon/omarchy-apple-silicon.sh
```

---

## Path A — Bare metal (M1/M2 proven; M3 new as of Sept 2026)

This is real Arch Linux ARM booting natively next to macOS, using Asahi
Linux's partitioner and Apple Silicon kernel work. Nothing in macOS is
touched; a boot menu lets you pick macOS or Linux at startup (for a
"single boot" feel, shrink macOS to the minimum and Linux is the default —
see above).

**Prerequisites**
- M1/M2-family or M3/M3 Pro/M3 Max Mac (M3 Ultra, M4, M5 not supported — use Path B)
- macOS 15 or later, recent Time Machine backup
- ≥ 50 GB free on the internal SSD (100 GB recommended)

**M3 caveats (read before installing on an M3)**

Asahi shipped official M3 support in September 2026 and the Asahi Alarm
(Arch) port enabled M3 firmware (14.8.3) on 2026‑09‑20. Working: Wi‑Fi,
Bluetooth, USB up to 10 Gb/s, webcam, internal mics, hardware video decode
incl. AV1. Not working yet:

- **GPU 3D acceleration** — the desktop runs software-rendered on the
  firmware framebuffer. Hyprland/Omarchy works but is noticeably slower
  than on M1/M2; GPU support is actively being developed.
- **Sleep** (firmware framebuffer limitation) and the **HDMI port** on
  MacBook Pros (incomplete display-controller support).
- `omarchy-mac` was built and tested against M1/M2. On M3 treat it as
  experimental: if the Omarchy setup misbehaves, the proven M3 baseline is
  Asahi Alarm's stock KDE/GNOME image, with Omarchy layered on later once
  GPU support lands.
- **Expert mode** — Asahi's M3 announcement says M3 support is gated
  behind the installer's Expert mode while the work is fresh. If the
  installer doesn't offer an install on your M3, restart it and answer
  `y` at "Enable expert mode?". Expert mode also asks which macOS version
  to use for boot firmware — just press Enter to keep the default; any
  other choice is unsupported and can break the install.

**Install (~15 min, 3 automatic reboots)**

1. From macOS Terminal, run the Asahi Alarm installer and choose
   **Asahi Alarm Minimal (BTRFS)**, allocating ≥ 50 GB (on an M3, enable
   Expert mode if prompted — see M3 caveats above):

   ```bash
   curl https://asahi-alarm.org/installer-bootstrap.sh | sh
   ```

2. Reboot into the new Arch system, log in as `root` / `root`, and bring up
   Wi‑Fi with `nmtui`.

3. Run the Omarchy Mac setup (prompts for hostname, user, password,
   encryption — encryption is on by default):

   ```bash
   curl -fsSL https://raw.githubusercontent.com/omarchy-mac/omarchy-mac/quattro/bin/omarchy-mac-setup | bash
   ```

   Useful flags: `--no-encrypt`, `--status`, `--step <name>` (re-run a step).

**Known issues**
- SSH: Omarchy enables a default-deny firewall that never opens port 22.
  Run `omarchy-setup-security-sshd` afterwards if you want SSH in.
- If you ever land in `grub rescue>`: `/boot` must live on the EFI partition
  before enabling encryption — see the omarchy-mac README.
- Rollback: `omarchy snapshot restore` with the `@fresh` (pre-Omarchy) or
  `@factory` (post-install baseline) BTRFS snapshots.
- Uninstall: no automatic uninstaller. Remove the Linux partitions from
  macOS and expand the macOS container per the Asahi partitioning
  cheatsheet — careful work, follow it exactly.

There is also the official **Omarchy M** effort (announced Sept 2026,
<https://omarchy.org/news/2026/09/introducing-omarchy-m/>): a native Mac
installer app plus a "Try Omarchy" app that runs Omarchy hardware-accelerated
inside macOS without partitioning. M1/M2 today, M3–M5 in development. Still
preview-quality as of early Oct 2026; the Asahi Alarm + omarchy-mac path above
is the proven route right now, but Omarchy M is worth watching — once it ships
a polished release it will likely become the recommended path.

## Path B — VM on M4/M5, M3 Ultra (or if you don't want to repartition)

Native aarch64 Omarchy inside a VM. Two options:

**B1. UTM (free) — prebuilt image or one-script build**

- Prebuilt: download `omarchy-arm-utm-v2.zip` (~3.6 GB) from
  <https://archive.org/details/omarchy-arm-utm>, unzip, open the `.utm`
  bundle in UTM, boot. (Community-built image — treat it accordingly; build
  it yourself below if you'd rather not trust a third-party image.)
- Build it yourself (~1 h on an M3 Max, 8 resumable phases):

  ```bash
  brew install --cask utm
  git clone https://github.com/ggalancs/omarchy-arm-utm.git
  cd omarchy-arm-utm
  ./build-omarchy-arm.sh
  ```

  UTM caveats: no GL acceleration (software rendering via
  `LIBGL_ALWAYS_SOFTWARE=1`), single monitor, set resolution at boot (runtime
  changes white-screen), and macOS swallows Cmd so the image maps **Option (⌥)
  as SUPER**. Fine for daily terminal/editor work; not for GPU-heavy use.
  Daily-driver tuning notes: <https://github.com/dchersey/omarchy-apple-silicon-utm>.

**B2. Parallels Desktop (paid) — better graphics**

<https://github.com/vincenzopalazzo/omarchy-parallels> repackages the official
try-omarchy guest into a bootable Parallels VM and also publishes a live ISO
(`omarchy-arm-*-aarch64.iso`) usable in Parallels/UTM/QEMU as an installer CD.

**Vanilla Arch Linux ARM (no Omarchy)**: in UTM, create an aarch64 UEFI VM
from the UTM gallery's Arch Linux ARM image, or boot an aarch64 installer ISO
and install ALARM normally.

## Sources

- Omarchy M announcement: <https://omarchy.org/news/2026/09/introducing-omarchy-m/>
- omarchy-mac (bare metal M1/M2): <https://github.com/omacom/omarchy-mac>
- Asahi Alarm installer: <https://asahi-alarm.org>
- One-script UTM build discussion: <https://github.com/omacom/omarchy/discussions/7956>
- UTM build repo: <https://github.com/ggalancs/omarchy-arm-utm> · prebuilt image: <https://archive.org/details/omarchy-arm-utm>
- UTM daily-driver fixes: <https://github.com/dchersey/omarchy-apple-silicon-utm>
- Parallels repack + live ISO: <https://github.com/vincenzopalazzo/omarchy-parallels>
- Asahi M3 support announcement (Sept 2026, incl. caveats): <https://asahilinux.org/2026/09/m2-episode-1/>
- Asahi Alarm M3 firmware enablement (2026‑09‑20): <https://github.com/asahi-alarm/asahi-installer-data/commits>
- Why macOS can't be fully removed (stub partition): <https://asahilinux.org/docs/sw/partitioning-cheatsheet/>
