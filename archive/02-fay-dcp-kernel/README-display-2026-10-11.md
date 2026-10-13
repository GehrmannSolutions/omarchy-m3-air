# MacBook Air M3 (J613): internal and external display on Linux

> **Superseded (2026-10-13):** this describes the 7.2.2-fay-dcp state of 2026-10-11. Current work: the Aurora-based series in `aurora/upstream/` (v2, daily kernel fay-v2), status in `../plans/2026-10-13-STATUS.md`.

State: 2026-10-11. Machine: MacBook Air 13" M3 (J613, t8122), Omarchy on Asahi ALARM, DCP firmware 14.7.

Everything here was developed with Claude Code (Fay) and is meant for this machine and for Omarchy Mac. It is **not** submittable to Asahi Linux (their policy forbids AI-made contributions, see `../fay-upstream-ai-policies.md`).

## What works

| Feature | Status | Notes |
|---|---|---|
| Internal panel via `appledrm` (DCP 14.7) | works | 2560x1664@60; backlight device `apple-panel-bl` present (not separately tested) |
| Screen blank / DPMS off and on | works | was a DCP crash on every blank before the bw-scratch fix |
| External monitor, left-back USB-C port (DP alt mode) | works | 1920x1080@60 tested (Lenovo M14), via dcpext + ATC0 |
| External monitor present at boot | works | Hyprland starts before the monitor is up; needs the aquamarine fix |
| Unplug / replug with the desktop running | works | output comes back |
| DPMS with both displays | works | 3 cycles, 6 DCP power-offs, no DART fault |
| Shutdown / reboot with monitor attached | works | one hang seen once with an older debug kernel, not reproduced |
| Right-back USB-C port (ATC1) as display | untested | crossbar is described in the DT but not enabled |

## The pieces

### 1. Kernel `7.2.2-fay-dcp`

Base: AsahiLinux/linux `asahi-wip-7.2` @ 236788cd, plus:

- PR #608 (sofus13): t8122 DCP device tree and panel nodes, which give the internal panel.
- PR #607 (T8122 DP alt mode): ATC PHY DisplayPort support, tipd hotplug forwarding, DCP 14.7 tiling callbacks, rtkit/afk/mailbox fixes.
- **bw-scratch fix** (ours): on t8122 the DCP runs RT bandwidth in "Dashboard" mode (bw-scratch without bw-doorbell). Its only write through that mapping is a 64-bit zero to the pmgr dashboard at power-off, which dart-dcp rejects (FILL_REGION|NO_PTE), so the DCP crashed on every screen blank. The driver now hands the firmware a RAM page instead (`dmam_alloc_coherent`).
- **dcpext reg fix** (ours): the dcpext node was missing the disp-1 range (`0x318800000`), so every firmware `map_reg` index ≥ 1 was off by one. bw-scratch is now index 5.
- **J613 DP wiring** (ours): ATC display crossbars in `t8122.dtsi`; in `t8122-j613.dts` dcpext → atcphy0 (`mux-index = <2>`), `apple,sync-syslog-ack`, the dcpext port@1 ↔ atcphy0 port@2 graph, `ps_atc0_common` always-on, the `dcpext` alias.
- Our ATC PHY patches 0005/0006 for USB-C data (see `../project-usb-c-pd-controller.md`).

Files:

- `../kernel/7.2.2-fay-dcp-vs-asahi-wip-7.2.diff` is the whole tree as one diff (applies cleanly to 236788cd).
- `../kernel/config-7.2.2-fay-dcp` is the config.
- `../kernel/review-patches/` holds the display changes as 7 separate commits.

Build:

```sh
git checkout 236788cd && git apply 7.2.2-fay-dcp-vs-asahi-wip-7.2.diff
cp config-7.2.2-fay-dcp .config
make ARCH=arm64 -j8 Image modules dtbs
```

### 2. m1n1 (stage 2, `boot.bin`)

Base: AsahiLinux/m1n1 `main` @ 948783012, plus two commits (`../kernel/review-patches/0001`, `0004`):

- `dt_set_display()` treats t8122 like t8112. The J613 ADT has the same `iop-dcp-nub` region IDs (49/50/57/94/95) and DART streams, so the dcp/disp0 carveouts get reserved.
- `dt_reserve_dcpext_firmware()` includes t8122. Without it dcpext stays disabled. This also reserves regions 73/74, so no extra carveout is needed.

The boot blob is m1n1 + all dtbs + gzipped u-boot:

```sh
cat m1n1/build/m1n1.bin dtbs/*.dtb > boot.bin
gzip -n -c /usr/lib/asahi-boot/u-boot-nodtb.bin >> boot.bin
```

Built without `RELEASE=1` (like the tested v1.6.1 build). Install it as `/boot/m1n1/boot.bin`. The previous blob stays on the ESP as `m1n1/boot.bin.pr607`. If m1n1 fails to boot, copy it back from macOS.

### 3. aquamarine 0.15.1-1.2 (Hyprland backend)

Without a usable EGL device (software rendering on M3), aquamarine 0.15.1 drops any output that appears after the compositor started. `connect()` returns early because `updateSecondaryRendererState()` → `initMgpu()` can never succeed. The patch does what aquamarine already does for evdi, for any driver: if `initMgpu()` fails on a backend without a primary, it sets `rendererRequired = false` and carries on. This also ends the per-commit renderer retry spam (upstream issues hyprwm/aquamarine#425, #370).

Recipe in `../pkg/aquamarine/` (Arch PKGBUILD + patch). It installs as a normal pacman package (`pacman -U`). A newer aquamarine from `extra` replaces it silently. Check with `pacman -Q aquamarine`.

## Booting it

- GRUB default is still the daily kernel 7.1.13. Pick 7.2.2-fay-dcp for one boot:
  `sudo grub-reboot 'gnulinux-advanced-<root-uuid>>gnulinux-fay-dcp-advanced-<root-uuid>'`
- Do **not** use the `fay-dcptest` entry. It is the old debug entry, with appledrm blacklisted and no desktop.
- DPMS on Hyprland 0.56 (Lua config): `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`, then `"enable"`. The old `hyprctl dispatch dpms off` silently does nothing.

## Rollback

| What | How |
|---|---|
| m1n1 | `~/.cache/fay-build/patchwork/m1n1main-test/rollback-m1n1main.sh`, or copy `m1n1/boot.bin.pr607` over `m1n1/boot.bin` on the Asahi ESP from macOS |
| kernel (back to debug variant) | `~/.cache/fay-build/patchwork/clean-bwscratch-20261011/rollback-clean.sh` |
| aquamarine | `sudo pacman -U /var/lib/fay-backup/aquamarine-20261011/aquamarine-0.15.1-1-aarch64.pkg.tar.xz` |

## Test log

Full log: `../plans/2026-10-11-aux-test-log.md`. Two ultrareviews of the commits: the first found the missing dcpext firmware reservation (fixed); the second had 0 findings (`../drafts/2026-10-11-ultrareview*`).

## Known issues / open

- Shutdown hung once (debug kernel, after a replug) until the monitor was unplugged. Not reproduced with the clean kernel. If it comes back, photograph the screen first.
- A one-off DART fault on the ATC1 USB DART (`b02f80000`, stream 1, NO PGD at 0xdc) appeared at boot, unrelated to display.
- The right-back port (ATC1) is not wired for display yet.
- An aquamarine update from `extra` drops the patch until upstream fixes it.
- Making 7.2.2-fay-dcp the GRUB default is still a decision for Marius.

## Omarchy Mac

[omacom/omarchy-mac](https://github.com/omacom/omarchy-mac) (the Omarchy fork for Apple Silicon) and [omarchy-mac/omarchy-mac-iso](https://github.com/omarchy-mac/omarchy-mac-iso) are AI-friendly (AGENTS.md / CLAUDE.md). Their M3 images still show `simpledrm`. They have a J613 DCP overlay (`configs/m1n1/j613-dcp-overlay.dts`, patched into the j613 DTB slot of `boot.bin`) and a 7.2 appledrm kernel on their builder that has not shipped yet. That makes them a good home for this work: the bw-scratch crash fix, external display and aquamarine. Contributions there only with Marius's OK.

### Update 2026-10-11 evening: where Omarchy Mac is

- `omacom/omarchy-mac` is winding down. Mac packages moved to [omacom/omarchy-mac-pkgs](https://github.com/omacom/omarchy-mac-pkgs), generic work goes to omacom/omarchy. The kernel is [omacom/linux-aurora](https://github.com/omacom/linux-aurora) (formerly iconidentify/aurora-linux; latest release Aurora 2026.10.11.13). The installer supports `apple,j613`.
- Aurora drives the J613 internal panel differently: `t8122-dcp.dtsi` with an iBoot handoff (the boot loader checks and locks the inherited DART mappings, a display gate driver enables the nodes). The pmgr dashboard page is plain `disp-5`, with no `apple,bw-scratch`, and `map_reg` is unchanged upstream code. Whether their DPMS path hits our dart-dcp fault is unknown; their handoff may keep iBoot's mapping. There is no J613 blank-crash issue in their tracker.
- Their open issue [omacom/linux-aurora#39](https://github.com/omacom/linux-aurora/issues/39) "Software-rendered desktop: make late USB-C hotplug obtain a usable display route" (owner: kernel, readiness: investigation) is exactly our aquamarine finding: the cause is in aquamarine's `connect()`/`initMgpu()`, not the kernel. This is the best first contribution.
- No AI ban in their CONTRIBUTING (report format: machine/board/SoC, release tag, kernel, firmware, Mesa/renderer, compositor version, pass/fail per action). Claude-generated PRs are marked openly in omacom repos.

### GPU (research 2026-10-11)

- Aurora 2026.10.11.13 (kernel 7.1.12.aurora2) offers experimental M3 Air GPU via its installer (`install-aurora-sep.sh`): kernel + headers + `mesa-m3` (installed under /opt/mesa-m3) + their m1n1 stage2 (`m1n1-aurora 1.6.1.aurora17`), keeps a "GPU off" previous entry, supports GRUB.
- Profiles: **current14** (`--m3-gpu-persistent` / `--m3-gpu`; the "legacy" profile, release notes say the 14.x Vulkan profiles are kept) and **exact 26.6.2 / 25G83** (native OpenGL only, needs a macOS 26.6.2 volume group + special stage1).
- current14 gate (from the installer): board j613/j615, `asahi,os-fw-version` 14.7 or 14.8.3, stage1 `v1.6.1`, ESP `asahi/stub_info.json` ProductVersion 14.8.3, iBoot `iBoot-10151.140.19*`. **This Air matches all of them** (stage1 v1.6.1, os-fw 14.7, stub 14.8.3, iBoot-10151.140.19.700.2; system-fw 27.0 does not select the profile).
- Aurora on J613: internal panel via iBoot handoff, USB-PD `apple,sn201202x` on both ports. USB-C/Thunderbolt **display on the Air is still open** in Aurora (we have it via PR #607 + our DT).
- Our kernel is built with `CONFIG_RUST` off; the Asahi GPU driver is Rust, plus Aurora's t8122 GPU changes and their m1n1. Porting GPU into 7.2.2-fay-dcp would be large; rebasing our extras (external display, aquamarine is userspace anyway) onto Aurora is the smaller job.

### Aurora --m3-report on this Air (2026-10-11 21:00, run by Marius, read-only)

- Report: `~/.cache/fay-build/aurora/aurora-m3-report-j613-20261011-210018.tgz` (local only, masked).
- Boot facts: stage1 v1.6.1, stage2 9487830-dirty (our m1n1 main), os-fw 14.7, system-fw 27.0, iBoot-10151.140.19.700.2, stub ProductVersion 14.8.3. ADT step skipped (no phram module in our kernel), MTD state restored. No SMC key list (no debugfs smc keys on our kernel).
- Our DT has no GPU node/alias, so `--m3-gpu` would see "absent" and pick the **current14 (legacy)** profile; the stub/iBoot checks match.
- What an Aurora install changes: installs `linux-aurora` 7.1.12 + headers, `m1n1-aurora` (update-m1n1 rebuilds `/boot/m1n1/boot.bin` with Aurora's dtbs, replacing our m1n1 main blob), `mesa-m3` under /opt/mesa-m3, `aurora-touchid` + patched `libfprint` (Secure Enclave driver; `--read-only` keeps it from writing to the enclave), regenerates grub.cfg and sets `GRUB_DEFAULT` to the Aurora entry, keeps the previous kernel and a "GPU off" entry. Rollback: `install-aurora-sep.sh --uninstall` plus our saved boot.bin.
- With Aurora's boot.bin our 7.2.2-fay-dcp kernel would get Aurora's j613 DT (handoff-gated DCP) and most likely fall back to simpledrm, so it is a real switch, not side by side.
