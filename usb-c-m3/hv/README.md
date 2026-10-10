# Hypervisor trace: DisplayPort alt mode on the M3 Air (t8122)

Goal: record what macOS writes to the ATC0 PHY (AUX, DP clocks, PLL, lanes) and the
display crossbar when a USB-C monitor is plugged into the left-rear port.

- Target: the M3 Air with Asahi (m1n1 stage 1). Its `/boot/m1n1/boot.bin` is replaced by
  a plain m1n1 v1.9.9 `build/m1n1.bin` (no device trees, no U-Boot), so m1n1 stays in
  proxy mode. Keep the normal boot.bin to restore it afterwards.
- Host: the second Mac, connected with a Thunderbolt/USB-C cable to the target's
  right-hand port (atc1); the monitor goes into the target's left-rear port (atc0).
- Host software: m1n1 v1.9.9 checkout, Python 3 with `construct` and `pyserial`.
- Run on the host (the macOS kernelcache must match the target's macOS version):
  `M1N1DEVICE=/dev/cu.usbmodemP_01 python3 proxyclient/tools/run_guest.py -l fay-atc0-dp.log -m trace_atc0_dp_t8122.py <kernelcache>`
- After macOS is up under the hypervisor: unplug and replug the monitor, keep it in for
  ~30 s, then stop and save the host console log.
- Back to Linux: on the host, `python3 proxyclient/tools/chainload.py -r <normal boot.bin>`,
  then restore `/boot/m1n1/boot.bin` from Linux. Fallback: boot macOS from the boot picker,
  `sudo diskutil mount disk0s4`, copy the normal boot.bin back to `m1n1/boot.bin`.
