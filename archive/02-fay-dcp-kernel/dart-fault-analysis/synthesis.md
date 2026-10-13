# Synthesis (2026-10-09)

## Hypotheses

### #1 H1

The faulting access was the DCP writing the RT-bandwidth dashboard (pmgr_dcp PA 0x2d03d0000 + 0x908) through the DVA that Linux returned for D411 map_reg(index 5), which is 0x10fffdfc000. Linux never unmapped that mapping, yet at power-down the DART found no leaf PTE for it. Static evidence identifies the target with fair confidence but cannot say why the PTE was absent. Two sub-mechanisms remain: (a) the kernel PTE was still valid but the iBoot-locked DART did not see it; (b) the kernel's L2 entry, or the whole L2 page, was cleared by something outside the DMA API.

**Mechanism:** Boot (inferred):
- The FW >= 13.2 path dcpep_cb_map_reg calls dma_map_resource(pmgr_dcp, 0x4000) and returns {dva, addr, length}. There is no bookkeeping and no unmap.
- As the first post-shmem allocation of 32 pages or fewer, it lands on the top page below the 1 MiB shmem at 0x10fffe00000. That page is 0x10fffdfc000.
- While running, the M3 maintains the dashboard by physical address. So stream 5 probably never touched this page until 'power_down_M3: disabling M3'. After that, the DCP CPU itself stores to dva+0x908 to drop the bandwidth request. This is the first stream-5 access to the page.

Fault: the DART reports a WRITE (bit 28) with only NO_PTE set. Upper levels were valid because the kernel L2 table for L1 slot 0x7ff also holds the shmem and RTKit PTEs.

Sub-mechanism (a): the PTE in kernel memory was valid, but the walker did not observe it. Possible causes:
- a stale or negative cached PTE line, given that PARAMS_4 advertises STT/TLB/CTC prefetch support;
- iBoot tunables at 0x20c-0x328 that stay active because the DART is locked and Linux cannot reset it;
- a FLUSH_SID that is not strong enough: Linux never sets TLB_OP bit 13 ENABLE_STT_FLUSH.

Sub-mechanism (b): the 8-byte PTE at offset 0x3bf8 of the kernel L2 page, or the whole page, was zeroed by a writer outside the DMA API. Candidates:
- a physical write via dart-dcp stream 15 (bypass-15 / apf-bypass-15) into RAM that the DRAFT t8122 m1n1 reserved-memory list leaves unreserved;
- kernel memory corruption.

If the whole page was wiped, TLB hits on the hot shmem and RTKit pages would hide it. The cold dashboard page would then be the first to fault.

**Decisive test:** Reboot into 7.2.2-fay-dcp with appledrm blacklisted (modprobe.blacklist=appledrm), so simpledrm keeps the console.

As root:
1. Enable the built-in events dma:dma_map_phys, dma:dma_unmap_phys, dma:dma_alloc and dma:dma_free, each with filter 'device == "28ec00000.dcp"'. Optionally add iommu:map and iommu:unmap with 'iova >= 0x10fff000000'.
2. Run modprobe appledrm and log in.
3. Save /sys/kernel/tracing/trace. Ownership is proven by a line 'dma_map_phys: 28ec00000.dcp dir=BIDIRECTIONAL dma_addr=10fffdfc000 size=16384 phys_addr=2d03d0000 attrs=MMIO'.
4. With drgn on /proc/kcore and the build tree's vmlinux (DWARF5, CONFIG_PROC_KCORE=y), walk the dcp device's io-pgtable: L1 index (iova>>25)&0x7ff, then L2 index (iova>>14)&0x7ff. Read the PTE for 0x10fffdfc908.
5. Trigger DPMS-off. The kernel survives the DCP crash.
6. Run the same drgn walk again.

Reading the result:
- H1 is confirmed by the map_phys line plus no dma_free or unmap of that address before the fault.
- PTE still valid after the crash means (a).
- PTE zero, ideally with the whole L2 page dumped to show how many entries are gone, means (b).

With a rebuild instead: print iommu_iova_to_phys(domain, addr), the kernel L1 entry and locked_ttbr[5][0][(addr>>25)&0x7ff], plus raw registers 0x160/0x164/0x178/0x180-0x18c, inside apple_dart_t8110_irq.

**Candidate fix:** Independent of the sub-mechanism (robustness first):
- Add a module option (default on for t8122) so that DPMS-off skips A472 setPowerState(0). The clear swap with bl_power=0 already blanks the panel, so the firmware's power_down_M3 path is never entered.
- Record {pa, dva, size} for every D411/D452 mapping. Before iomfb_poweroff sends setPowerState(0), check iommu_iova_to_phys(iommu_get_domain_for_dev(dcp->dev), dva) == pa. On a mismatch, warn and re-install with iommu_map(..., IOMMU_READ|IOMMU_WRITE|IOMMU_MMIO), which triggers a flush.
- Make the crash recoverable. Today dcp->crashed makes dcp_crtc_atomic_check return -EINVAL forever (dcp.c:337-338), which is why the screen never came back.

If (a): for locked T8110 DARTs, use a stronger invalidate after map and before setPowerState(0), i.e. FLUSH_ALL, or FLUSH_SID with TLB_OP bit 13 (ENABLE_STT_FLUSH, per m1n1). First read PARAMS_4 prefetch support and the iBoot tunables at 0x300-0x328.

If (b): find the agent and the carveout by comparing the macOS carveout-memory-map with the m1n1 DRAFT list 49/50/57/94/95. Reserve the missing region in m1n1.

### #2 H2

0x10fffdfc000 was the top page of a D451 allocate_buffer buffer (dma_alloc_coherent, 512 KiB or less): the first post-shmem allocation, or an rcache recycle of it. During setPowerState(0) the firmware released it with D454 release_mem_desc (mailbox #118, right after 'free_all_sdp_resources'). Linux unmapped it synchronously, and about 20 ms later the DCP still wrote into it at page offset 0x908.

**Mechanism:** 1. #118 is a CB-context IOMFB message of length 0x14. It matches D454 (u32 in, bool out, padded to 4).
2. dcpep_cb_release_mem_desc runs in the RTKit workqueue before the ack. It calls dma_free_coherent, then __iommu_dma_unmap and dart_unmap_pages, which writes *ptep = 0. The strict-mode FLUSH_SID completes before the firmware sees the ack.
3. The leaf is now gone while L1 slot 0x7ff stays valid, which gives NO_PTE only.
4. The firmware or a DCP engine then stores into the released buffer.

Why the store could still happen:
- Firmware use-after-release that macOS masks with lazy unmap or deferred TLB invalidation.
- Tag 454 in the 14.7 table (copied from 13.3) meaning something other than 'release'.

Under this hypothesis the store lands at buffer offset size-0x36f8, for example 0x908 for 16K or 0x4908 for 32K.

**Decisive test:** Use the same filtered dma:* trace as H1. Also enable dcp:iomfb_callback, dcp:dcp_recv_msg and dcp:dcp_send_msg ('echo :mod:appledrm >> set_event' before modprobe if this kernel supports it, otherwise enable right after load). Stream trace_pipe to disk during DPMS-off.

H2 is confirmed by both of:
- at boot, 'dma_alloc: 28ec00000.dcp ... dma_addr=<range covering 10fffdfc000>';
- right before the fault, 'iomfb_callback ... 454 ... dcpep_cb_release_mem_desc' followed by 'dma_free: 28ec00000.dcp ... dma_addr=<same>'.

**Candidate fix:** Defer the frees.
- dcpep_cb_release_mem_desc keeps clearing the bit and acking as now, but moves {buf, dva, size, sgt} to a deferred list instead of calling dma_free_coherent.
- Drain the list after setPowerState(0) completes or times out, at the next dcp_poweron, or after a grace period of at least 100 ms. This mirrors macOS-like lazy unmap and keeps the PTE alive for late firmware accesses.

Also:
- Set memdesc->dva = 0 on release.
- Verify the 14.7 tag numbering (454/455/456) with a macOS m1n1-hypervisor DCP trace (proxyclient hv trace_dcp) of a display sleep on this machine (ask Mika).

### #3 H3

Linux never had a mapping at 0x10fffdfc000 when the firmware wrote. The firmware used a dashboard DVA it had kept from the iBoot-driven DCP session, or never re-requested map_reg(5) under Linux. Linux's locked-L1 sync had erased the iBoot mapping, and the lookup ran into Linux's own L2 table for slot 0x7ff.

**Mechanism:** - Linux only wakes the DCP, which iBoot already booted and drove; the firmware is not reloaded.
- If the firmware cached the pmgr mapping from the iBoot-era AP-side implementation and did not call D411(5) again under Linux, it keeps using that old DVA.
- apple_dart_hw_sync_locked overwrites all 2048 iBoot L1 entries with Linux's L1 on the first flush.
- m1n1 re-creates only the RAM carveouts through iommu-addresses, not MMIO.
- Because Linux's L2 table occupies L1 slot 0x7ff, the walk reaches a valid L1 entry and an empty leaf, which gives NO_PTE.

The exact equality with Linux's next slot would require iBoot's allocator to have produced the same top-down layout: a 1 MiB shmem at 0x10fffe00000, then one page.

**Decisive test:** H3 holds if:
- the filtered boot trace shows no dma_map_phys or dma_alloc for 28ec00000.dcp covering 0x10fffdfc000 before the fault, and pmgr 0x2d03d0000 is either not mapped or mapped at a different dma_addr;
- and a second reproduction faults again at 0x10fffdfc908.

To confirm directly, dump iBoot's sid5 L1/L2 (pt-region-5, 0x103ffec4000-0x103fff04000) before the first apple_dart_hw_sync_locked. Use a debug print in apple_dart_hw_map_locked_ttbr or an m1n1 proxy dump.

**Candidate fix:** Before IOMFB start, pre-map pmgr_dcp at the DVA the firmware expects:
- reserve that IOVA range in the dcp domain (an iommu reserved region, or m1n1 passing an MMIO iommu-addresses entry);
- iommu_map it to 0x2d03d0000 with IOMMU_MMIO.

Alternatively, force the firmware to re-query its device mappings, for example with a full RTKit reboot instead of a wake. Re-check with the trace.

### #4 H4

The firmware received a stale DVA from D451: allocate_buffer returned the old memdesc->dva of a previously freed buffer whose PTE was already gone.

**Mechanism:** - dcpep_cb_allocate_buffer does not check memdesc->buf. When dma_alloc_coherent fails or size is 0, *dma_handle is left untouched, and resp.dva = memdesc->dva returns whatever that slot last held.
- release_mem_desc never clears memdesc->dva.
- If that slot had earlier held a freed buffer at 0x10fffdfc000, the firmware would later write to an unmapped page and fault with NO_PTE.

**Decisive test:** The filtered dma:* trace shows 'dma_alloc: 28ec00000.dcp ... virt_addr=0000000000000000' (a failed allocation is traced at kernel/dma/mapping.c:657). Alternatively, a D451 response whose dva equals an address freed earlier. With a rebuild: add a WARN when memdesc->buf == NULL in dcpep_cb_allocate_buffer.

**Candidate fix:** Harden the memdesc handling (worth doing regardless):
- in allocate_buffer, on failure clear_bit(id) and return dva = 0, dva_size = 0, mem_desc_id = 0;
- zero memdesc->dva in release;
- bounds-check id >= DCP_MAX_MAPPINGS in map_physical (iomfb_template.c:444-447 has none);
- use sg_free_table instead of memset on the sg_table.

### #5 H5

dart-dcp sid5's iBoot-locked TTBR points at the same physical L1 page as another locked sid (dart-disp0 sid0 or sid4). Another domain's sync then rewrote L1[0x7ff] to point at its own L2 table, so the walk found a valid L1 entry and a missing leaf.

**Mechanism:** - apple_dart_hw_sync_locked copies the domain's whole kernel L1 into whatever page the sid's TTBR pointed to at attach, and never checks for aliasing.
- All three domains allocate top-down, so each has an L1[0x7ff].
- A flush on disp0 sid0 or sid4 would therefore redirect sid5's slot 0x7ff to a foreign L2, giving NO_PTE.

**Decisive test:** As root, with the display on, read the TTBR registers through /dev/mem (CONFIG_IO_STRICT_DEVMEM is not set; reads have no side effects):
- 0x28d30d414 (dart-dcp sid5);
- 0x28d305400 (dart-disp0 sid0);
- 0x28d305410 (dart-disp0 sid4).

The L1 PA is ((v & ~1) >> 2) << 14 (apple-dart.c:151-154). Identical PAs confirm H5; distinct PAs exclude it.

**Candidate fix:** At attach, compare the locked TTBR PAs of all locked DARTs and sids, and refuse or WARN on aliasing. If aliasing is real, merge the aliasing sids into one domain.

## Contradictions

- Fault direction:
- The dart strand decodes status bit 28 as WRITE.
- The timeline strand calls the direction undetermined, and the iova strand reads 'bits 19:16 = 0x4' without decoding them.
- Resolved: m1n1 dart8110.py R_ERROR has WRITE_nREAD = 28 and FILL_REGION = 18, so this was a write with the unexplained bit 18 set.
- New point: public T8110 NO_PTE faults in AsahiLinux/linux#395 (0x80300008, 0x90100008) have bit 18 clear.
- Was there a release_mem_desc?
- The upstream strand says none occurred ('expected length 0x11') and uses that as support for its H3.
- The mapinventory and timeline strands say #118 (length 0x14) fits D454.
- Every IOMFB length in the history is a multiple of 4, which implies padding. On that basis 0x14 is consistent with D454 (and equally with D209 or D574), so upstream's exclusion does not hold.
- Size of the fault page's owner:
- The mapinventory and iova strands restrict the owner to a 16K / 1-page allocation.
- The dart strand notes that a 32K allocation at 0x10fffdf8000 also covers the page.
- Verified against iova.c:389-390 (round up to a power of two below 32 pages, size-aligned top-down): 0x10fffdfc000 is the top page of the first post-shmem allocation of any size from 1 to 32 pages, or exactly 64.
- So the owner can be a D451/D452 of up to 512 KiB. For D411, only the 1-page resources disp-2, disp-3 and pmgr qualify; disp-0, disp-1 and disp-4 cannot.
- Primary identity of the page:
- Strands favouring the D451 buffer: mapinventory H1 (medium) and dart H1 (medium).
- Strands favouring the map_reg(5) pmgr mapping: iova H1, timeline H1 and upstream H3.
- Both sides rest on the same unresolved trade-off: the 0x908 coincidence against the absence of any unmap path. No strand produced data that breaks the tie.
- Cross-sid L1 aliasing:
- The upstream strand's H3 proposes aliasing as the mechanism.
- The mapinventory and dart strands cite disjoint ADT pt-regions (region-id-16/17/18). An alias would also have broken shmem DMA at boot, and upstream's own counter-evidence agrees, so this is ranked low.
- Coincidence probability for offset 0x908: the mapinventory and dart strands give about 1/4096; the timeline strand gives about 1/2048 (8-byte alignment). This is minor and does not change the ranking.
- The dart strand's argument against stale PTE caching ('every fresh mapping in slot 0x7ff worked at boot right after FLUSH_SID') does not apply. The shmem and RTKit PTEs (L2 0x780-0x7bf, 0x7fe-0x7ff) are in different PTE cache lines from 0x77f, and nothing shows that line 0x778-0x77f was ever walked.
- How the dashboard is reached:
- The timeline strand suggests the M3 reaches it via bypass stream 15 or physically.
- The iova strand says the DCP reaches it via dart-dcp.
- These are compatible: dart-dcp has 'apf-bypass-15', so the DAPF allow-list entry 0x2d03c0000-0x2d03effff matters only for translated stream-5 traffic. That supports the DCP CPU accessing pmgr through a stream-5 mapping.
- Upstream context is itself inconsistent: PR #583 reports '8 CRTC cycles ... no DART/IOVA faults' on t6030, while PR #643 says 'dcp_set_power_state still crashes' on t6030. It is unknown whether #583's cycles included setPowerState(0).
- Allocation order: the iova and mapinventory strands place the AFK GETBUF before the shmem, yet 'AFK[ep:20]: new service system' is logged after 'shared memory dva'. This is not a real contradiction. afk_start blocks until RBEP_START_ACK (afk.c:110, afk.c:693-694), which comes after GETBUF; the 'new service' line is a later announcement.
