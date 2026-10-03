# Runbook: macOS session for the M3 display device-tree data (MacBook Air M3, J613)

Purpose: read the display nodes of the M3 device tree on macOS, so that the m1n1
display carveouts (`disp_reserved_regions_t8122`) and the DCP node addresses can be
written correctly. Without this, the DCP 14.7 kernel (asahi-wip-7.2 + PR #608) cannot be
brought up. Plan: `agents/fay/plans/2026-10-03-dcp-14x-port-PLAN.md` in the memory repo.

Status: prepared, not started. Marius decides when to boot macOS.

## Safety rules

- Read only. Do NOT run the Asahi installer, do not change partitions, do not install
  anything into macOS.
- Do not commit the full dump anywhere. It contains serial numbers and hardware IDs.
  Only the extracted `reg` values and names go into the repo, as text.
- The Linux install stays. Next normal boot goes to Omarchy.

## Steps

1. **Boot macOS once.** Power on, hold the power button until the startup options appear,
   choose macOS.
2. **Record the versions.** Terminal: `sw_vers` and `system_profiler SPHardwareDataType | grep -E "Model|Chip|Firmware"`.
3. **Dump the device tree (read only).** In Terminal:

   ```
   ioreg -p IODeviceTree -l -w0 > ~/Desktop/fay-devicetree.txt
   ```

4. **Extract the display part.** In Terminal:

   ```
   grep -nE 'dcp|disp|dart|dptx|mbox|reserved|firmware' ~/Desktop/fay-devicetree.txt > ~/Desktop/fay-display-extract.txt
   ```

   Look at `fay-display-extract.txt` and check it contains the display nodes. If it is
   empty or only has unrelated entries, stop and tell Fay.
5. **Hand over the result.** Copy `fay-display-extract.txt` to the exFAT stick `FAYTESTa`
   (empty test stick, the only one to use here). Do not copy the full dump.
6. **Reboot into Omarchy** (Asahi boot picker, Linux).
7. **Tell Fay.** Fay reads the extract, writes the m1n1 carveout and the DT values as
   patches, and checks them against the PR #608 nodes.

## Notes

- The ioreg command and paths are standard macOS; if an option changes on a newer macOS,
  check `man ioreg` on the Mac.
- The display node names on the M3 are expected to resemble `dcp`, `dcpext`, `disp0`
  and `dart`. The actual names in the dump decide the next step.
