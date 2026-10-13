# DART NO_PTE fault on screen blank (t8122, 7.2.2-fay-dcp) — analysis, 2026-10-09

Output of a parallel read-only analysis (5 investigation strands, synthesis, 3 skeptics per
hypothesis, completeness critic). `full-results.json` holds every agent's complete structured result (5 strands, synthesis, 15 skeptic
verdicts, critic). Checked before upload: no LUKS/filesystem UUIDs, no MAC addresses, no LAN IPs (the only
UUID is the Claude session id from file paths). The raw kernel logs stay machine-local in
`~/.cache/fay-build/analysis/2026-10-09-dart-fault/` because the kernel cmdline in them contains the LUKS
UUID. The per-agent transcripts (~21 MB of raw tool output) stay in `~/.claude/projects/` on the laptop.

- `synthesis.md` — ranked hypotheses H1-H5 with mechanism, decisive test and candidate fix
- `critic-gaps.md` — what is still unknown (G1-G15)
- `critic-instrumentation.md` — tracepoints, kprobes (offsets from the crashed kernel's vmlinux) and one appledrm patch
- `critic-repro-plan.md` — automated, self-rebooting dry run + crash repro
- `critic-macos-questions.md` — questions for Mika (macOS side)

Verdicts: H1 (dashboard write through the map_reg(5) DVA 0x10fffdfc000, PTE absent) survived all
three lenses. H2 (released D451 buffer), H3 (stale iBoot DVA), H4 (stale DVA from failed alloc) and
H5 (cross-sid L1 aliasing) were refuted or unsupported. H1 names the target but not why the PTE was
missing. New candidate from the critic: mailbox #118 right after "free_all_sdp_resources" may be
D574 `power_up_dart`, which Linux answers with zero and otherwise ignores.
