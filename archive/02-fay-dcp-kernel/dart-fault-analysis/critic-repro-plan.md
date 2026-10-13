# Safest repro plan (critic, 2026-10-09)

Principles:
 - Each boot persists data to disk BEFORE the risky step.
 - All waits are bounded.
 - After a crash the system reboots itself without going through driver shutdown.
 - A wrong boot can never loop into the test again.
 - Expect 2 boots minimum (dry run, then repro), plus 1-2 repeats. The user must type the LUKS passphrase at each boot and must not touch the machine during a run. Keep AC power connected and the lid open.

PHASE 0 — preparation on the running linux-asahi system. Needs sudo, so the user has to approve.
 1. Reinstall /usr/lib/modules/7.2.2-fay-dcp from ~/.cache/fay-build/wip (modules_install + depmod), optionally with the appledrm patch F. Prevent re-deletion: either run 'systemctl mask linux-modules-cleanup.service' for the test period and unmask afterwards, or reinstall before every test boot.
 2. Add a top-level GRUB entry 'fay-dcp DCP test' (40_custom, then grub-mkconfig). Base it on the fay-dcp entry (grub.cfg:126-137) without 'quiet splash', and append: systemd.unit=multi-user.target modprobe.blacklist=appledrm fay.dcptest=1 log_buf_len=16M.
    - multi-user.target means SDDM autologin into Hyprland does not start.
    - The blacklist lets the script arm tracing and then run 'modprobe appledrm' by name; the blacklist only blocks alias loading.
    - Do not put trace_event= on the cmdline: without filters it would flood the buffer with every device's DMA.
 3. Install /usr/local/sbin/fay-dcptest and a oneshot fay-dcptest.service: WantedBy=multi-user.target, ConditionKernelCommandLine=fay.dcptest=1, ConditionPathExists=/var/lib/fay-dcptest/armed, After=local-fs.target sys-kernel-tracing.mount systemd-journald.service. Mode (dry, full or hypr) and a delay come from /var/lib/fay-dcptest/armed.
 4. Optional: take a btrfs snapshot of @.
 5. Arm: write the mode into /var/lib/fay-dcptest/armed, then run grub-reboot 'fay-dcp DCP test' (next_entry; grub.cfg:21-30 clears it) and reboot.

SCRIPT FLOW. Everything goes to /var/lib/fay-dcptest/<boot_id>/, with fsync after each step.
 S0. FIRST: rm /var/lib/fay-dcptest/armed, and run grub-editenv /boot/grub/grubenv unset next_entry (in case GRUB/U-Boot could not save_env). Record uname -a, /proc/cmdline and a free/df snapshot.
 S1. Set up tracing (steps A-C, B via :mod:), echo 1 > tracing_on.
 S2. modprobe appledrm. Wait up to 30 s for /sys/class/graphics/fb0/name == appledrmfb and for 'set_digital_out_mode' in dmesg, then sleep a further 'delay' (default 20 s; use 360 s on a repeat to match the original uptime).
 S3. Save trace (cat, which is non-destructive), dmesg, and the appledrm lines from /proc/kallsyms. Compute and register stage 2 (D) and the E probes. Run 'sync' to take the pre-snapshot, and gdb-dump l2-pre.bin. Grep immediately for the owner of 10fffdfc000 and write VERDICT-owner.txt. Run journalctl --sync; sync. G1/H1-identity is now decided, even if what follows fails.
 S4. If mode=dry: unregister the probes and run 'systemctl reboot'. STOP. Check the artifacts before doing the full run.
 S5. If mode=full: sync; journalctl --sync. Then run timeout 20 sh -c 'echo 4 > /sys/class/graphics/fb0/blank'. This is FB_BLANK_POWERDOWN, which goes drm_fb_helper_blank, then drm_client_modeset_dpms (atomic, active=false), then apple_crtc_atomic_disable and dcp_poweroff: the same kernel path as the crash. No DRM master is held, so the blank is not blocked. The kernel wait is bounded by 50 ms + 1000 ms (iomfb_template.c:934/954).
 S6. Sleep 5 s. Set crashed=1 if dmesg has 'DCP has crashed' or a '28d30c000.iommu: translation fault'. Run 'sync' again for the post-snapshot. Gdb-dump l2-post.bin. Copy the crashlog: the debugfs blob if patched, otherwise a python3 mmap of /dev/mem at 0x103e1aa6000, 64 KiB (non-RAM carveout; STRICT_DEVMEM allows it; read-only).
 S7. Run timeout 15 sh -c 'echo 0 > /sys/class/graphics/fb0/blank' to record recovery behaviour. -EINVAL is expected after a crash (dcp.c:337-338). If there was no crash, repeat S5-S7 two more times to test determinism within the boot.
 S8. Save the full trace (trace, then trace_pipe drained with timeout), dmesg, and journalctl -k -b. Then: sync; journalctl --sync; sync.
 S9. Reboot.
   - No crash: 'systemctl reboot'.
   - Crash: avoid driver shutdown paths entirely, with echo s > /proc/sysrq-trigger; sleep 2; echo u > /proc/sysrq-trigger; sleep 2; echo b > /proc/sysrq-trigger. /proc/sysrq-trigger works for root regardless of kernel.sysrq=16.
   - next_entry was cleared in S0, so GRUB boots the default linux-asahi. The user types the passphrase there, and the results are on disk.
   - Fallback for the user: if the screen is still dead and there was no reboot within about 5 min, hold the power button. That is the outcome already proven safe on 2026-10-03, 23:19:02 ('macsmc-input: Triggering forced shutdown!').

PHASES
 Phase 1: one dry boot. It decides G1 and validates every probe definition. Fix any probe errors seen in dynamic_events or error_log.
 Phase 2: one full boot, the crash repro.
 Phase 3, only as needed:
   - Repeat full with delay=360 (determinism, uptime).
   - If fbdev blank does NOT reproduce, use mode=hypr. Boot the normal graphical target, with tracing armed by an early service ordered Before=systemd-udev-trigger.service (:mod: cache plus the vmlinux probes). The E probes are added after appledrm appears. Trigger with runuser -u mg -- env XDG_RUNTIME_DIR=/run/user/1000 hyprctl dispatch dpms off.
   - After that, a fix-validation boot (for example skip setPowerState(0), or FLUSH_ALL before it), chosen by the decision table in minimal_instrumentation.

ABORT RULES: any probe registration failure means continue tracepoint-only and do NOT trigger DPMS in that boot. Do not touch DART MMIO or /dev/mem outside the crashlog carveout. Never run the test entry without the armed file.
