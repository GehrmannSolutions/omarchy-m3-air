# 7.2.2-fay-dcp kernel state (2026-10-11, display finish line)

`7.2.2-fay-dcp-vs-asahi-wip-7.2.diff` reproduces the running kernel tree (`~/.cache/fay-build/wip`, built 19:40,
vmlinuz sha 105d0f9b…) on top of AsahiLinux/linux `asahi-wip-7.2` @ 236788cd:
- PR #608 (sofus13, t8122 DCP DT + panel) @ 33f535e2
- PR #607 (T8122 DP alt mode: atc.c, tipd hotplug, drm afk/apple_drv/dpavservep/parser, rtkit/mailbox, 62bd293c tiling)
- our 0005/0006 ATC PHY patches (USB-C), J613 DP wiring (dcpext port@1 ↔ atcphy0 port@2, sync-syslog-ack, ps_atc0_common always-on)
- clean bw-scratch fix (review commit 0002) and dcpext disp-1 reg fix (0003)
- no fay debug code (that is in debug-instrumentation/, diffs against the PR #607 versions of the 7 files)

Rebuild: checkout asahi-wip-7.2, `git apply` the diff, `cp config-7.2.2-fay-dcp .config`,
`make ARCH=arm64 -j8 Image modules dtbs`.

`review-patches/` = review repo branch `fay/t8122-external-display` (7 commits incl. aquamarine; base main now also has PR #607 code files and aquamarine main 52ea11f subset):
`fay/t8122-external-display` (contains `fay/t8122-internal-display`): paths are `linux/…` and `m1n1/…`
(base: linux subset of asahi-wip-7.2 + PR #608 + 62bd293c, m1n1 main 948783012). 0001/0004 = m1n1, boot-tested on main.

Boot chain: boot.bin = m1n1 (main + 0001 + 0004, built without RELEASE) + dtbs + gzip u-boot-nodtb (recipe in plans/2026-10-11-aux-test-log.md).
Userspace: ../pkg/aquamarine (patched aquamarine 0.15.1-1.2).
