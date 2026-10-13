# Minimal instrumentation (critic, 2026-10-09)

Goal: one boot decides who owns the DVA (G1), what #118 is (G2), and which of PTE present / PTE absent / locked-L1 divergent holds (G4/G5). Steps A-E need NO kernel rebuild. The struct offsets below were computed with gdb from ~/.cache/fay-build/wip/vmlinux, built 2026-10-03 16:24, which is the crashed kernel's build ('Sat Oct 3 16:23:37'). CONFIG_RANDOMIZE_BASE is not set. KPROBE_EVENTS=y, DYNAMIC_EVENTS=y, HAVE_FUNCTION_ARG_ACCESS_API=y; return probes support entry $argN (trace_probe.c __store_entry_arg).

A. Built-in tracepoints. Keep trace_clock 'local' so the timestamps match dmesg. Set buffer_size_kb=16384 per CPU, and configure everything BEFORE appledrm loads.
 - events/dma/{dma_map_phys,dma_unmap_phys,dma_alloc,dma_free}: filter 'device == "28ec00000.dcp"'. The field name 'device' is at include/trace/events/dma.h:46. dma_map_resource goes through dma_map_phys (mapping.c:182, attrs MMIO). Failed allocations are traced with virt_addr=NULL (mapping.c:662).
 - events/iommu/{map,unmap} (iommu.c:2721/2820): filter 'iova >= 0x10ffe000000 && iova < 0x11000000000', which is L1 slot 0x7ff. These events carry NO domain, so C1/C2 below add one.

B. appledrm tracepoints, pre-armed with the :mod: cache (trace_events.c:1424). Run echo 'dcp:iomfb_callback:mod:appledrm' >> set_event, and do the same for dcp:dcp_recv_msg and dcp:dcp_send_msg.
 - iomfb_callback prints 'Callback D%03d <handler>' in the trampoline, BEFORE the handler runs (iomfb_internal.h:87). So every dma_* event that follows belongs to that tag.
 - The recv/send events give the raw 64-bit mailbox words. These map 1:1 onto the crashlog mailbox history and fix the DCP-tick-to-kernel-time offset.

C. kprobes on vmlinux (no rebuild).
 1. p:fay/dmap dart_map_pages l1=-0x28($arg1):x64 iova=$arg2:x64 pa=$arg3:x64 pgsz=$arg4:x64 cnt=$arg5:x64 prot=$arg6:x32 — same iova filter as A. Here l1 is the kernel L1 KVA, used as a domain id: ops - 0x78 is the io_pgtable, cfg is at +0x10, apple_dart_cfg.ttbr[0] at cfg+0x40, so the ttbr is at ops-0x28.
 2. p:fay/dunmap dart_unmap_pages l1=-0x28($arg1):x64 iova=$arg2:x64 pgsz=$arg3:x64 cnt=$arg4:x64 — same filter. These calls (io-pgtable-dart.c:322-323) are the only leaf clears.
 3. p:fay/syncmap apple_dart_iotlb_sync_map l1=-0x28(-0xa8($arg1)):x64 kl1=+0x3ff8(-0x28(-0xa8($arg1))):x64 iova=$arg2:x64 — same filter. Offsets: apple_dart_domain.domain is at 0xa8 and pgtbl_ops at 0x0. This yields the kernel L1[0x7ff] for the dcp domain.
 4. p:fay/tlbinv apple_dart_t8110_hw_invalidate_tlb dart=+0($arg1):x64 name=+0(+0(+0(+0($arg1)))):string sid=+8($arg1):x64 — layout: stream_map.dart at 0, sidmap at 8; dart->dev at 0; kobj.name at 0. It gives the address of the struct apple_dart for '28d30c000.iommu' and timestamps every flush.
 5. p:fay/irq apple_dart_t8110_irq name=+0(+0(+0($arg2))):string lk1=+0x3ff8(+0x1d30($arg2)):x64 kl1=+0x3ff8(-0x28(-0xa8(+0xb0(+0x80($arg2))))):x64 — filter 'name == "28d30c000.iommu"'. Offsets: locked_ttbr[5][0] is at dart+0x1d30, sid2group[5] at +0x80, iommu_group.domain at +0xb0. This captures the locked L1[0x7ff] that the hardware walks next to the kernel L1[0x7ff], atomically at the fault. Do NOT fetch DART MMIO registers in probes; the error status, address and stream are already printed (apple-dart.c:1400-1403).
 6. p:fay/pmgr apple_pmgr_ps_set name=+0(+0x480($arg1)):string pstate=$arg2:u32 auto=$arg3:u8 — logs genpd transitions in the window (G10).

D. Stage 2 (the script runs this after appledrm init), on-demand snapshots without drgn.
 - Take kl1 from fay/syncmap (the dcp domain's l1 equals the l1 seen in the dmap event for the 0x10fffe00000 shmem). Then L2_PA = (kl1 & 0x3FFFFFFC00) << 4, and L2_KVA = 0xffff000000000000 + (L2_PA - memstart_addr); read memstart_addr with gdb on /proc/kcore. In the leaf, 0x77f is at L2_KVA+0x3bf8 and its 64-byte line is at +0x3bc0.
 - Add p:fay/irq2 apple_dart_t8110_irq pte=@<L2_KVA+0x3bf8>:x64 line=@<L2_KVA+0x3bc0>:x64[8] — this is the leaf at the fault.
 - Add p:fay/snap __arm64_sys_sync pte=@<L2_KVA+0x3bf8>:x64 lk1=+0x3ff8(@<dart+0x1d30>):x64 lk1_40=+0x200(@<dart+0x1d30>):x64 — fires whenever the script runs 'sync'.
 - In addition, run gdb -batch vmlinux /proc/kcore -ex 'dump binary memory l2-{pre,post}.bin L2_KVA L2_KVA+0x4000'. That is the whole kernel L2 page, which lives in RAM, so kcore works.

E. Arguments in the power-down window. These kprobes on module statics go in after modprobe, by address. Each name exists 3 times (v12_3/v13_3/v14_7) and kprobe_events rejects non-unique names (trace_kprobe.c:970), so use the /proc/kallsyms copy whose address is above iomfb_poweroff_v13_3. Trampoline args are (dcp, tag, out, in).
 - p trampoline_zero tag=$arg2:s32 in=+0($arg4):x32 — D574 bool.
 - p trampoline_release_mem_desc id=+0($arg4):u32
 - r trampoline_map_reg idx=+4($arg4):u32 dva=+0($arg3):x64 addr=+8($arg3):x64 len=+16($arg3):x64 ret=+24($arg3):u32
 - r trampoline_allocate_buffer size=+4($arg4):x64 dva=+8($arg3):x64 dsz=+16($arg3):x64 id=+24($arg3):u32
 - r trampoline_map_physical pa=+0($arg4):x64 size=+8($arg4):x64 dva=+0($arg3):x64 id=+16($arg3):u32
 - p trampoline_get_time

F. One appledrm patch. Recommended, because the module tree has to be reinstalled anyway (G15), and it survives in the journal if the trace capture fails.
 (1) In dcpep_handle_cb (iomfb.c:262-292), after the handler and before dcp_ack: dev_info with ctx, tag, hdr->in_len, hdr->out_len, mailbox offset, ktime_get_ns(), a hex dump of up to 64 B of 'in', and of 'out' after the handler. This single site captures every D411/D451/D452/D454/D574/D209/D3 argument and response, the real padded lengths, and the identity of #118.
 (2) In dcp_rtk_crashed (dcp.c:251): kmemdup(crashlog, size) and debugfs_create_blob('crashlog') (G7).
 (3) In last_client_closed_poff (iomfb_template.c:861), just before dcp_set_power_state: for every D411/D452/D451 DVA recorded via (1), and for each 16 KiB page in 0x10ffe000000-0x10fffffffff, log iommu_iova_to_phys(iommu_get_domain_for_dev(dcp->dev), dva) against the expected PA. Repeat the same sweep in dcp_rtk_crashed. This is also the detection hook for H1's candidate fix.

G. Only if H3 must be proven directly (needs a kernel rebuild): in apple_dart_setup_translation_locked, between apple_dart_hw_map_locked_ttbr and the first apple_dart_hw_sync_locked (apple-dart.c:747-751), log iBoot's non-zero L1 entries per sid, and any leaf mapping PA 0x2d03d0000. A kprobe_event= cmdline is a possible no-rebuild alternative.

How to read the result:
 - Boot trace shows 'Callback D411 dcpep_cb_map_reg', then dma_map_phys phys_addr=2d03d0000 size=16384 dma_addr=10fffdfc000, then fay/dmap with the dcp l1: H1's identity is proven and H2/H3/H4 are dead.
 - dma_alloc after D451 covering that page, then before the fault D454 plus dma_free/fay/dunmap of it: H2. A dma_alloc with virt_addr=0: H4. No dcp-domain map covering it: H3.
 - At the fault, pte==0x000fff002d03d003 and lk1==kl1: sub-mechanism (a), walker/TLB/prefetch. Next, test FLUSH_ALL or TLB_OP bit 13 before setPowerState(0).
 - pte==0 with no fay/dunmap event: (b), an external writer. Diff l2-pre.bin against l2-post.bin to see how many entries changed.
 - lk1 != kl1: (c), the locked L1 was rewritten by a non-Linux agent.
 - fay/pmgr events for disp_* in the window: Linux power gating is involved.
