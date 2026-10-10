# Probe verification for fay-dcptest (2026-10-10)

Every struct offset, symbol and fetch chain used by `fay-dcptest` was checked
here against the build tree, not taken from `critic-instrumentation.md`. All
numbers below come from `gdb -batch`, `readelf` and the kernel sources in
`~/.cache/fay-build/wip`. Host and user names in the outputs are redacted.

## 1. Build identity

- vmlinux: `~/.cache/fay-build/wip/vmlinux`, banner
  `Linux version 7.2.2-fay-dcp (<user>@<host>) (gcc (GCC) 16.1.1 20260430, GNU ld (GNU Binutils) 2.46.0) #1 SMP PREEMPT_DYNAMIC Sat Oct  3 16:23:37 CEST 2026`.
  That is the build the crash ran on (crash-boot.log line 2). `CONFIG_RANDOMIZE_BASE` is not set, so
  kallsyms addresses equal System.map.
- At run time the script only allows kprobes if the running kernel matches:
  8 vmlinux symbols in `/proc/kallsyms` must have the System.map address and be unique, and
  `sha256(/proc/version)` must equal the hash of `linux_banner` that `install.sh` stored.
  Otherwise there are no kprobes and no blank.
- appledrm.ko checked here: sha256 `439b0c05f7fda6c5...`, 9904528 bytes, built 2026-10-10 02:19:03.
  That is the instrumented build (patches 0007 + 0008 in this folder, 0008 revised after review:
  regmap ring, page-aligned D452 check, crashlog before sweep, `fay_cb_log` default 2, `fay-cb-ack`
  lines). The module offsets are not hard-coded. The script works them out at run time from
  `/proc/kallsyms` (section 5).
- Relevant config: `KPROBES=y KPROBE_EVENTS=y DYNAMIC_EVENTS=y HAVE_FUNCTION_ARG_ACCESS_API=y`,
  `DYNAMIC_FTRACE=y`, `# CONFIG_KPROBE_EVENTS_ON_NOTRACE is not set`, `ARM64_VA_BITS=48`,
  `ARM64_16K_PAGES=y`, `PROC_KCORE=y`, `STRICT_DEVMEM=y`, `MODULE_SIG`/`MODULE_COMPRESS` not set.

## 2. vmlinux offsets (gdb)

Command: `gdb -batch -nx -x vmlinux.gdb ~/.cache/fay-build/wip/vmlinux`

```
set pagination off
printf "linux_banner: %s", linux_banner
print/x (unsigned long)&((struct io_pgtable *)0)->cfg
print/x (unsigned long)&((struct io_pgtable *)0)->ops
print/x (unsigned long)&((struct io_pgtable_cfg *)0)->apple_dart_cfg.ttbr[0]
whatis ((struct io_pgtable_cfg *)0)->apple_dart_cfg.ttbr
print/x (unsigned long)&((struct dart_io_pgtable *)0)->iop
print/x (unsigned long)&((struct apple_dart_domain *)0)->pgtbl_ops
print/x (unsigned long)&((struct apple_dart_domain *)0)->domain
print/x (unsigned long)&((struct apple_dart_stream_map *)0)->dart
print/x (unsigned long)&((struct apple_dart_stream_map *)0)->sidmap
print/x (unsigned long)&((struct apple_dart *)0)->dev
print/x (unsigned long)&((struct apple_dart *)0)->sid2group[5]
print/x (unsigned long)&((struct apple_dart *)0)->locked_ttbr[5][0]
print/x sizeof(((struct apple_dart *)0)->locked_ttbr)
print/x (unsigned long)&((struct device *)0)->kobj
print/x (unsigned long)&((struct kobject *)0)->name
print/x (unsigned long)&((struct iommu_group *)0)->domain
print/x (unsigned long)&((struct generic_pm_domain *)0)->name
print/x (unsigned long)&((struct apple_pmgr_ps *)0)->genpd
print sizeof(dart_iopte)
info address memstart_addr
x/3i dart_map_pages
x/3i dart_unmap_pages
x/3i apple_dart_iotlb_sync_map
x/3i apple_dart_t8110_hw_invalidate_tlb
x/3i apple_dart_t8110_irq
x/3i apple_pmgr_ps_set
x/3i __arm64_sys_sync
x/8i apple_pmgr_ps_power_off+16
```

Output:

```
linux_banner: Linux version 7.2.2-fay-dcp (<user>@<host>) (gcc (GCC) 16.1.1 20260430, GNU ld (GNU Binutils) 2.46.0) #1 SMP PREEMPT_DYNAMIC Sat Oct  3 16:23:37 CEST 2026
$1 = 0x10
$2 = 0x78
$3 = 0x40
type = void *[4]
$4 = 0x0
$5 = 0x0
$6 = 0xa8
$7 = 0x0
$8 = 0x8
$9 = 0x0
$10 = 0x80
$11 = 0x1d30
$12 = 0x2000
$13 = 0x0
$14 = 0x0
$15 = 0xb0
$16 = 0x480
$17 = 0x8
$18 = 8
Symbol "memstart_addr" is static storage at address 0xffff80008150db68.
   0xffff8000809be1d8 <dart_map_pages>:	nop
   0xffff8000809be1dc <dart_map_pages+4>:	nop
   0xffff8000809be1e0 <dart_map_pages+8>:	paciasp
   0xffff8000809be568 <dart_unmap_pages>:	nop
   0xffff8000809be56c <dart_unmap_pages+4>:	nop
   0xffff8000809be570 <dart_unmap_pages+8>:	ldur	x5, [x0, #-96]
   0xffff8000809c12e8 <apple_dart_iotlb_sync_map>:	nop
   0xffff8000809c12ec <apple_dart_iotlb_sync_map+4>:	nop
   0xffff8000809c12f0 <apple_dart_iotlb_sync_map+8>:	paciasp
   0xffff8000809c1610 <apple_dart_t8110_hw_invalidate_tlb>:	nop
   0xffff8000809c1614 <apple_dart_t8110_hw_invalidate_tlb+4>:	nop
   0xffff8000809c1618 <apple_dart_t8110_hw_invalidate_tlb+8>:	paciasp
   0xffff8000809c1d48 <apple_dart_t8110_irq>:	nop
   0xffff8000809c1d4c <apple_dart_t8110_irq+4>:	nop
   0xffff8000809c1d50 <apple_dart_t8110_irq+8>:	ldr	x2, [x1, #16]
   0xffff8000809481c8 <apple_pmgr_ps_set>:	nop
   0xffff8000809481cc <apple_pmgr_ps_set+4>:	nop
   0xffff8000809481d0 <apple_pmgr_ps_set+8>:	paciasp
   0xffff8000804a0d88 <__arm64_sys_sync>:	nop
   0xffff8000804a0d8c <__arm64_sys_sync+4>:	nop
   0xffff8000804a0d90 <__arm64_sys_sync+8>:	paciasp
   0xffff8000809485b8 <apple_pmgr_ps_power_off+16>:	mov	w2, #0x0                   	// #0
   0xffff8000809485bc <apple_pmgr_ps_power_off+20>:	mov	w1, #0x0                   	// #0
   0xffff8000809485c0 <apple_pmgr_ps_power_off+24>:	mov	x29, sp
   0xffff8000809485c4 <apple_pmgr_ps_power_off+28>:	bl	0xffff8000809481c8 <apple_pmgr_ps_set>
   0xffff8000809485c8 <apple_pmgr_ps_power_off+32>:	ldp	x29, x30, [sp], #16
   0xffff8000809485cc <apple_pmgr_ps_power_off+36>:	autiasp
   0xffff8000809485d0 <apple_pmgr_ps_power_off+40>:	ret
   0xffff8000809485d4:	nop
```

The symbols are unique in System.map (one line each). `apple_dart_hw_sync_locked` and
`apple_dart_t8110_hw_tlb_command` are inlined, so they are not used as probe points.
`apple_pmgr_ps_set` is called out of line from both `apple_pmgr_ps_power_on` and `_off`
(the `bl` above and the matching `bl` in `power_on`).

### Verified values against the critic's numbers

| Quantity | critic | gdb | used as |
|---|---|---|---|
| io_pgtable.cfg / .ops | 0x10 / 0x78 | 0x10 / 0x78 | |
| io_pgtable_cfg.apple_dart_cfg.ttbr[0] | 0x40 | 0x40 (type `void *[4]`, a KVA) | ttbr[0] = `ops - 0x78 + 0x10 + 0x40` = **ops - 0x28** |
| apple_dart_domain.pgtbl_ops / .domain | 0x0 / 0xa8 | 0x0 / 0xa8 | ops = `*(domain - 0xa8)` |
| apple_dart_stream_map.dart / .sidmap | 0 / 8 | 0 / 8 (sidmap is `unsigned long[4]`) | |
| apple_dart.dev | 0 | 0 | |
| apple_dart.sid2group[5] | 0x80 | 0x80 | |
| apple_dart.locked_ttbr[5][0] | 0x1d30 | 0x1d30 (array 0x2000 = 256 sids x 4 ttbr x 8) | |
| device.kobj / kobject.name | 0 / 0 | 0 / 0 | |
| iommu_group.domain | 0xb0 | 0xb0 | |
| generic_pm_domain.name | 0x480 | 0x480; `$arg1` of apple_pmgr_ps_set is the genpd pointer | |
| L1 slot of 0x10fffdfc908 | 0x7ff | (0xfffdfc908 >> 25) & 0x7ff = 0x7ff, at +0x3ff8 | |
| L2 slot | 0x77f | (0xfffdfc908 >> 14) & 0x7ff = 0x77f, at +0x3bf8, line +0x3bc0 | |
| expected leaf PTE | 0x000fff002d03d003 | `(0x2d03d0000 >> 4) & GENMASK(37,10)` + SUBPAGE_END 0xfff<<40 + NO_CACHE + VALID (io-pgtable-dart.c:50,82-135) | |
| L2 KVA | `0xffff000000000000 + PA - memstart_addr` | `__phys_to_virt` = `(x - PHYS_OFFSET) | PAGE_OFFSET`, PAGE_OFFSET = -(1<<48) (memory.h:44,358) | |

All of the critic's offsets are correct.

## 3. Corrections to the critic's plan (found while verifying)

1. **`dart_map_pages` / `dart_unmap_pages` see a masked IOVA.** `apple_dart_map_pages` passes
   `iova & dart_domain->mask` (apple-dart.c:696/708). The mask is `DMA_BIT_MASK(ias)` (:831), and
   dart-dcp logs "Limited to ias=36 due to lock" (crash-boot.log:320). So the fault page arrives as
   `0xfffdfc000`, not `0x10fffdfc000`. The critic's filter `iova >= 0x10ffe000000` would have
   matched nothing on C1/C2. The script filters on both windows:
   `(iova >= 0xffe000000 && iova < 0x1000000000) || (iova >= 0x10ffe000000 && iova < 0x11000000000)`.
   The iommu tracepoints (iommu.c:2721/2820) and `apple_dart_iotlb_sync_map` do get the full DVA.
2. **A probe on an absolute address gets no `$argN` and no return probe.** In
   `trace_kprobe_create_internal` only the symbol branch sets `TPARG_FL_FENTRY`/`TPARG_FL_RETURN`
   (trace_kprobe.c:940-985; flags start as `TPARG_FL_KERNEL`, :1097). An address-based
   `p 0xffff...` therefore fails `$arg2` with "NOFENTRY_ARGS" (trace_probe.c:1134-1153), and an
   address-based `r` probe cannot read entry args either. The E probes therefore use
   `appledrm:iomfb_poweroff_v13_3+<off>`: the anchor is unique (passes `validate_probe_symbol`,
   :968), and `_kprobe_addr` re-bases sym+off onto the containing symbol (kprobes.c:1530). So it
   resolves to the trampoline at offset 0, `on_func_entry` is true (:1496) and `kprobe_on_func_entry`
   accepts it, also for `r` (:2238).
3. **Only ftrace-able functions can be probed** (`KPROBE_EVENTS_ON_NOTRACE` is off, so
   `within_notrace_func`, trace_kprobe.c:443-480, applies; it passes for any function that has an
   ftrace record in its range). The build uses `CONFIG_DYNAMIC_FTRACE_WITH_CALL_OPS=y`, i.e.
   `-fpatchable-function-entry=4,2` (arch/arm64/Makefile:145): two NOPs before the symbol (sym-8,
   sym-4, the ops literal) and two at sym+0 / sym+4. That is what the static files show (vmlinux:
   `x/4i dart_map_pages-8`, `x/4i apple_dart_t8110_irq-8` = four NOPs; appledrm.ko: objdump at
   0x1ab68 / 0x1cfa0, `__patchable_function_entries` present). **At run time sym+0 is no longer a
   NOP:** `ftrace_init_nop()` (arch/arm64/kernel/ftrace.c:460-474) rewrites `rec->ip - 4` = sym+0 to
   `mov x9, x30` at boot and at module load. The ftrace call site is sym+4: the patchable entry is
   recorded at sym-8 and `ftrace_call_adjust()` (:63-125) adds 12. The kprobe at sym+0 therefore
   sits on `mov x9, x30`, which arm64 kprobes single-step out of line; that is fine.
   `check_ftrace_location()` (kprobes.c:1593) compares `ftrace_location(sym+0)`, which maps sym+0 to
   the function's ftrace site sym+4 (ftrace.c:1703-1719), with sym+0; they differ, so the probe is
   a plain kprobe and is not rejected.
4. **ftrace prints `x64` without leading zeros** (`0xfff002d03d003`). The script compares PTE and
   L1 values numerically (`heq`), never as strings.
5. **dart-dcp and dart-disp0 share AIC IRQ 557** (t8122.dtsi:939/950, `IRQF_SHARED`,
   apple-dart.c:1533). `apple_dart_t8110_irq(irq, dart)` runs for both, so fay_irq and fay_irq2 are
   filtered on `name == "28d30c000.iommu"`. For the other DART the fetch of `locked_ttbr[5][0]` may
   be NULL; kprobe fetches are fault-safe, so that only yields an error value, which the filter drops.
   The filter does not make a hit mean "dart-dcp faulted": the probes fire at handler entry, before
   the `!(error & FLAG)` check, and the dcp-DART handler instance runs on every assertion of the
   shared line, also when only dart-disp0 faulted. `VERDICT-fault.txt` therefore uses only hits after
   the first `tracing_mark_write: fay-dcptest S5.` marker, takes the one closest in time to the dmesg
   line `28d30c000.iommu: translation fault` (trace_clock `local` and printk both use local_clock),
   lists every hit after the marker, and warns if there is no such dmesg line or the distance is
   over 1 s.
6. **String fetches**: for `:string` the last dereference is turned into "store the string at this
   address" (trace_probe.c:1514). `name=+0(+0(+0(+0($arg1)))):string` on a stream_map is therefore
   right: stream_map→dart→dev→kobj.name, then the string. With `$arg2 = dart` in the IRQ handler,
   one level less is needed.
7. **Length limit**: each fetch body is at most 63 chars (`MAX_ARGSTR_LEN`, trace_probe.c:1593).
   The longest one, stage 2 `dkl1=+0x3ff8(-0x28(-0xa8(+0xb0(@0x<16 hex>)))):x64`, has a 53-char body.
8. The `:mod:appledrm` cache (trace_events.c:1425, :1395) is applied in `MODULE_STATE_COMING`
   (:3986), before the module init runs, so the dcp events see the first IOMFB callbacks.
9. `dma_map_resource` is traced as `dma_map_phys` with `attrs=MMIO` (mapping.c:366, :182).
   `iomfb_callback` fires in the trampoline before the handler (iomfb_internal.h:59-100).
10. A clean reboot runs `dcp_platform_shutdown`, then component_del, then
    `drm_atomic_helper_shutdown` and `iomfb_shutdown` (setPowerState 0) (dcp.c:1636/1708,
    apple_drv.c:527, iomfb_template.c:1490). That is the same firmware power-down path, so a dry
    boot ends with that path, after all data is on disk. After a crash, a failed or unfinished
    blank cycle, or a timed-out kernel call (modprobe, blank, unblank, sync) the script uses sysrq
    s/u/b, which skips device shutdown; `reboot_now` checks dmesg for a crash once more first.
11. **Unmaps of the fault page are counted per domain.** `dart_unmap_pages(ops, iova, pgsz, cnt)`
   clears `cnt` pages from `iova`, so a release of a multi-page D451 buffer that starts below
   0xfffdfc000 still clears the fault page; the verdict tests `iova <= page < iova + pgsz*cnt`, not
   `iova == page`. The piodma device maps the same D451 buffers into the disp-DART domain at the same
   DVAs (D201 `iommu_map_sgtable(dcp->iommu_dom, memdesc->dva)`, iomfb_template.c:282; D202 `iommu_unmap`, :332), and 28d304000
   is also "Limited to ias=36", so the masked iova is identical. Only `fay_dunmap` lines whose `l1`
   equals the stage-2 dcp-domain L1 (compared as hex strings, not as doubles) and that lie between the
   S5 marker and the fault count as a Linux unmap (H2); `dma_free` / `dma_unmap_phys` of the dcp
   device covering 0x10fffdfc000 in the same window count too. `iommu/map` and `iommu/unmap` carry
   no domain and are labelled "domain unknown (may be piodma)". If stage 2 failed (L1 unknown), the
   verdict says that (b) and H2 cannot be separated.
12. **Missed probe hits are visible.** `kprobe_profile` (hits and misses per probe, misses include
   kretprobe instance shortage) is saved at every snapshot and at the end, appended to `PROBES.txt`,
   and `VERDICT-fault.txt` warns if `fay_irq`, `fay_irq2`, `fay_dunmap` or `fay_dmap` missed any.

## 4. Fetch chains as installed

Stage 1 (S1, before appledrm loads):

```
p:fay/fay_dmap dart_map_pages l1=-0x28($arg1):x64 iova=$arg2:x64 pa=$arg3:x64 pgsz=$arg4:x64 cnt=$arg5:x64 prot=$arg6:x32
p:fay/fay_dunmap dart_unmap_pages l1=-0x28($arg1):x64 iova=$arg2:x64 pgsz=$arg3:x64 cnt=$arg4:x64
p:fay/fay_syncmap apple_dart_iotlb_sync_map l1=-0x28(-0xa8($arg1)):x64 kl1=+0x3ff8(-0x28(-0xa8($arg1))):x64 iova=$arg2:x64 size=$arg3:x64
p:fay/fay_tlbinv apple_dart_t8110_hw_invalidate_tlb dart=+0($arg1):x64 name=+0(+0(+0(+0($arg1)))):string sid=+8($arg1):x64
p:fay/fay_irq apple_dart_t8110_irq name=+0(+0(+0($arg2))):string lk1=+0x3ff8(+0x1d30($arg2)):x64 kl1=+0x3ff8(-0x28(-0xa8(+0xb0(+0x80($arg2))))):x64
p:fay/fay_pmgr apple_pmgr_ps_set name=+0(+0x480($arg1)):string pstate=$arg2:u32 auto=$arg3:u8
```

Stage 2 (after appledrm init). DART is the `dart=` value of fay_tlbinv for 28d30c000.iommu. One
`sync` fires fay_dom, which gives the dcp domain's L1 KVA, kernel L1[0x7ff], locked L1[0x7ff] and
memstart_addr. Then `L2_PA = (kl1 & 0x3FFFFFFC00) << 4` and
`L2 = 0xffff000000000000 + L2_PA - memstart_addr`:

```
p:fay/fay_dom __arm64_sys_sync dl1=-0x28(-0xa8(+0xb0(@<DART+0x80>))):x64 dkl1=+0x3ff8(-0x28(-0xa8(+0xb0(@<DART+0x80>)))):x64 lk1=+0x3ff8(@<DART+0x1d30>):x64 ms=@memstart_addr:x64
p:fay/fay_irq2 apple_dart_t8110_irq name=+0(+0(+0($arg2))):string pte=@<L2+0x3bf8>:x64 line=@<L2+0x3bc0>:x64[8]
p:fay/fay_snap __arm64_sys_sync pte=@<L2+0x3bf8>:x64 line=@<L2+0x3bc0>:x64[8] kl1=@<L1+0x3ff8>:x64 lk1=+0x3ff8(@<DART+0x1d30>):x64 kl1_40=@<L1+0x200>:x64 lk1_40=+0x200(@<DART+0x1d30>):x64
```

The `@<DART+0x80>` chain uses the dcp domain directly
(sid2group[5] → group->domain → pgtbl_ops → ttbr[0]), so it does not depend on matching map events.
The kernel L1 and L2 pages are also dumped from `/proc/kcore` (python reader, gdb fallback). The
locked L1 page is memremap'ed outside RAM and kcore returns zeros for it (critic G5), so it is only
read through the kprobe fetches (`lk1`, `lk1_40`).

## 5. appledrm statics (E probes)

Struct layouts, `gdb -batch -nx -x ko.gdb appledrm.ko` with `ptype/o` for each struct:

```
struct dcp_map_reg_req_v14_7_0   { char obj[4] @0; u32 index @4; u32 flags @8; u8 unk_u64_null @12; u8 addr_null @13; u8 length_null @14; u8 padding[1] @15 }  /* 16 bytes */
struct dcp_map_reg_resp_v14_7_0  { u64 dva @0; u64 addr @8; u64 length @16; u32 ret @24 }  /* 28 bytes */
struct dcp_allocate_buffer_req   { u32 unk0 @0; u64 size @4; u32 unk2 @12; u8 paddr_null @16; u8 dva_null @17; u8 dva_size_null @18; u8 padding @19 }  /* 20 bytes */
struct dcp_allocate_buffer_resp  { u64 paddr @0; u64 dva @8; u64 dva_size @16; u32 mem_desc_id @24 }  /* 28 bytes */
struct dcp_map_physical_req      { u64 paddr @0; u64 size @8; u32 flags @16; u8 dva_null @20; u8 dva_size_null @21; u8 padding[2] @22 }  /* 24 bytes */
struct dcp_map_physical_resp     { u64 dva @0; u64 dva_size @8; u32 mem_desc_id @16 }  /* 20 bytes */
```

These match the critic's offsets (`idx=+4`, `dva=+0 addr=+8 len=+16 ret=+24`, `size=+4`,
`dva=+8 dsz=+16 id=+24`, `pa=+0 size=+8`, `dva=+0 id=+16`). Trampoline signature:
`bool f(struct apple_dcp *dcp, int tag, void *out, void *in)`.

Which copy is v14_7? `readelf -sW appledrm.ko` (all in section 9 = `.text`) and the DWARF CU
ranges (`readelf --debug-dump=info --dwarf-depth=1` + `--debug-dump=Ranges`):

```
000000000000ed70   320 trampoline_zero              (v12_3 copy)
0000000000010308   444 trampoline_map_reg
0000000000012398  1052 iomfb_poweroff_v12_3
00000000000149e8   320 trampoline_zero              (v13_3 copy)
00000000000170e8   476 trampoline_map_reg
0000000000018458  1076 iomfb_poweroff_v13_3         <- anchor
000000000001ab70   320 trampoline_zero              (v14_7 copy)
000000000001b268   592 trampoline_map_physical
000000000001b628   332 trampoline_get_time
000000000001cfa8   476 trampoline_map_reg
000000000001d190   584 trampoline_release_mem_desc
000000000001d3e8   540 trampoline_allocate_buffer
000000000001e318  1076 iomfb_poweroff_v14_7_0
```

(Rebuilt module of 2026-10-10 02:19. All copies moved by +0x340 against the first build, because
dcp.c grew; the offsets from the anchor below did not change. The struct offsets above were
re-checked with `gdb -batch ... appledrm.ko` on this build: unchanged. `struct apple_dcp` only grew
at the end: `fay` at 0x3ea8 after `hdmi_hpd_irq` at 0x3ea0, sizeof 0x4c08.)

The link order is v12_3, v13_3, v14_7 (Makefile), so the v14_7 copy is the highest of the three.
The same holds for the unpatched build of 2026-10-03, where the copies sat at different offsets.
The run-time rule in the script:
- exactly 3 copies in `/proc/kallsyms`;
- take the highest;
- it must lie above `iomfb_poweroff_v13_3`;
- cross-check: its distance to `iomfb_poweroff_v14_7_0` must equal the one in the installed .ko
  (`readelf`).

For this build the probe points come out as `iomfb_poweroff_v13_3+0x2718` (zero),
`+0x2e10` (map_physical), `+0x31d0` (get_time), `+0x4b50` (map_reg), `+0x4d38` (release_mem_desc),
`+0x4f90` (allocate_buffer); the readelf cross-check distances to `iomfb_poweroff_v14_7_0` are
0x37a8, 0x30b0, 0x2cf0, 0x1370, 0x1188, 0xf30. The script computes them at run time, so a rebuild
needs no edits.

## 6. Offline test (no root, nothing installed)

The script was run in a harness copy with tracefs, kallsyms, kcore, grub-editenv, modprobe,
systemctl, sysrq and the console replaced by files or echo stubs:
- argument parsing, including rejected values;
- `run_bounded` timeout (rc 124 after the budget);
- all generated probe and filter strings;
- E-probe offsets from a kallsyms built from the real appledrm.ko symbol table, plus the readelf
  cross-check;
- stage-2 arithmetic (L2 KVA);
- the python kcore reader on a synthetic ELF core;
- all `VERDICT-owner` branches (H1 / H2 / freed / other mapping / H3 / H4) and all
  `VERDICT-fault` branches (a / b / c / unmap);
- a dry `main` end to end;
- full-mode blank cycles with and without a crash, including the reboot method (clean vs sysrq).

Re-run after the review fixes (same harness; every /proc, /sys, /dev and GRUB path pointed at
scratch files, modprobe/systemctl/sysrq stubbed):
- owner verdict on an interleaved trace (D411 on one kworker, D451 on another between its
  callback and its `dma_map_phys`): the map is attributed to D411; a multi-page `fay_dmap` starting
  below the page matches; other-domain and unknown-domain `l1` are labelled;
- fault verdict: a dart-disp0-style hit before the S5 marker is ignored; of three hits after the
  marker the one closest to the dmesg fault is used; a piodma (other `l1`) unmap gives (b), a
  dcp-domain 2-page unmap from 0xfffdf8000 gives H2, a dcp unmap after the fault gives (b), a
  `dma_free` covering the page gives H2, unknown L1 gives "cannot separate"; no dmesg fault line and
  a non-zero miss count in `kprobe_profile` each give a WARNING; (a) and (c) as before;
- `kbounded`: a timeout sets the stuck flag, a plain failure does not; `reboot_now` picks sysrq for
  a stuck call, an unfinished cycle, and a crash that only its own `check_crash` sees;
- watchdog with a 5 s budget and `WATCHDOG-FIRED.txt` replaced by a FIFO without reader (a write
  that blocks): the sysrq file still ends with `b` after 11 s;
- `record_env` on the real `/proc/cmdline` and banner: no UUID and no hostname in the output;
  `grubenv-after-S0.txt` holds variable names only;
- `main` end to end in full mode with stubs (no crash: clean reboot; simulated crash: cycles stop
  after cycle 1, sysrq).

`bash -n` passes on all scripts. shellcheck is not installed.

## 7. Only the dry boot can confirm

- that every kprobe registers on the real kernel (`probe-errors.txt`, `PROBES.txt` hit counts);
- that fay_tlbinv yields exactly one `struct apple_dart` for 28d30c000.iommu;
- that the stage-2 L1 from fay_dom equals the `kl1` seen in fay_syncmap, and that kcore L1[0x7ff]
  equals the probe value;
- the actual `memstart_addr`.
