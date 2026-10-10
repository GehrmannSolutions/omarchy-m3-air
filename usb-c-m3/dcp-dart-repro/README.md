# DCP screen-blank test kit (7.2.2-fay-dcp)

This kit reproduces the crash "the screen goes dark and never comes back" on
the test kernel 7.2.2-fay-dcp, and records what the kernel and the display
firmware (DCP) did at that moment. Each test is one special boot. That boot
has no desktop and reboots by itself. Your normal system (kernel 7.1.13) stays
the default and does not change, except for one thing: a cleanup service is
paused until you uninstall the kit.

Plan behind it: `~/.cache/fay-build/analysis/2026-10-09-dart-fault/critic-repro-plan.md`.
Technical checks: `probes-verification.md`.

## What is in this folder

| File | What it is |
|---|---|
| `install.sh` | One-time setup (needs sudo). |
| `arm.sh` | One-time GRUB check, and prepares exactly the next boot as a test boot (needs sudo). |
| `uninstall.sh` | Removes everything again and keeps the results (needs sudo). |
| `lib-grub.sh` | GRUB checks shared by install.sh and uninstall.sh. |
| `fay-dcptest` | The test script that runs during the test boot. |
| `fay-dcptest.service` | Starts the script, but only in a test boot. |
| `grub-40_custom-fay-dcptest.template` | The extra GRUB menu entry "fay-dcp DCP test". |
| `0007-…patch`, `0008-…patch`, `build*.log` | The instrumented display driver (made separately). |
| `config-usb-c.fragment` | Kernel options the WIP device tree needs for USB-C (see Notes). |

## Before you start

- The display driver build must be finished (no `make` running for appledrm).
- Plug in the charger and keep the lid **open**. Closing the lid would put
  the machine to sleep, which is the same kind of event the test is about.
- Plan about 10 minutes per test boot. You type your disk passphrase twice:
  once for the test boot, and once when it comes back to the normal system.
- Keep this README open on your phone or another computer. The test boot
  shows only text.

## Step 1: install (once)

In a terminal on the normal system:

```
cd ~/.cache/fay-build/omarchy/Tools/arch-arm-apple-silicon/usb-c-m3/dcp-dart-repro
sudo ./install.sh
```

It prints every command before running it. It does the following:

- installs the 7.2.2-fay-dcp kernel modules (about 2 GB, a few minutes);
- pauses `linux-modules-cleanup.service`, so those modules are not deleted
  again at the next boot;
- installs the test script and its service;
- adds the GRUB entry "fay-dcp DCP test".

It checks the new GRUB menu before using it, and it stops with an error if
anything looks wrong. The new menu may differ from the current one **only**
by the added test entry; any other difference (for example in the line of
your normal kernel) is shown and nothing is changed. The old menu is kept as
`/boot/grub/grub.cfg.fay-prev`, and both files are written to disk at once.

## Step 2: GRUB check (once, harmless)

The test boot is chosen through GRUB's "boot this entry once" setting.
GRUB itself has to clear that setting at boot; on this machine that has never
been used before. This check proves it works, with a boot into your normal
system:

```
sudo ./arm.sh grubenv-test
systemctl reboot
```

Boot normally (passphrase as usual), log in, then:

```
sudo ./arm.sh grubenv-check
```

It should say "GRUB check passed". If it says that GRUB did NOT clear the
setting, stop here and send the message: a failed test boot could then be
chosen again on every boot. `arm.sh dry` and `arm.sh full` refuse to run
until this check has passed.

## Step 3: dry run (no screen blank, harmless)

```
sudo ./arm.sh dry
systemctl reboot
```

What you will see:

1. GRUB picks "fay-dcp DCP test" by itself after a few seconds. Do not
   press any keys.
2. The disk passphrase prompt. Type your passphrase as usual.
3. Text messages, then a text login prompt. **Do not log in and do not
   type.** There is no desktop in this boot; that is intended.
4. Lines starting with `*** fay-dcptest:` appear. At "loading the display
   driver" the text may flicker and get smaller. During the waiting time a
   "still waiting" line appears every minute.
5. After about 1-2 minutes: "saving results and rebooting". The machine
   reboots by itself into your normal system. Type the passphrase again.

## Step 4: look at the dry-run result

```
ls -t /var/lib/fay-dcptest/                 # newest folder first
cd /var/lib/fay-dcptest/<that folder>
cat SUMMARY.txt VERDICT-owner.txt
```

A good dry run:

- `SUMMARY.txt` shows `blank_ok=1`, and "abort reasons" says `(none)`;
- `probe-errors.txt` is empty;
- `PROBES.txt`: the last column of the kprobe_profile table (missed events)
  is 0 everywhere;
- `VERDICT-owner.txt` has a line starting with `=>`. It says who owned the
  memory page the firmware crashed on, for example "H1 identity CONFIRMED".

Pack the folder for Claude:

```
tar czf ~/fay-dcptest-dry.tgz -C /var/lib/fay-dcptest <that folder>
```

About sharing: the result folders stay in `/var/lib/fay-dcptest/` and the
archive in your home folder. Do not copy them into this git folder. The
script replaces disk UUIDs, the hostname, serial numbers and MAC addresses
with placeholders in `00-env.txt`, `dmesg-*.txt` and `journal-*.txt`, and
keeps no GRUB values. Still look through the files before you share them
anywhere else.

If `blank_ok=0`, do not start the full run. Send the folder first. The
reason is in `SUMMARY.txt`, in `probe-errors.txt`, or in both.

## Step 5: full run (this triggers the crash)

Only after a good dry run:

```
sudo ./arm.sh full
systemctl reboot
```

It starts the same way as the dry run. Then:

- The message "S5.1: blanking the screen now. A black screen is expected."
  appears, and **the screen goes black**. That is the test.
- If the firmware crashes (expected), the machine saves everything and
  **reboots by itself within about a minute**. This reboot is abrupt, with no
  shutdown messages. That is on purpose.
- If it does not crash, the screen comes back after a few seconds. The test
  repeats up to 3 times, then reboots normally.

Afterwards, pack the newest folder as in step 4
(`~/fay-dcptest-full.tgz`). The key files are `VERDICT-fault.txt` and
`SUMMARY.txt`.

## If something goes wrong

- **Screen on, but no new `*** fay-dcptest:` line for more than 5 minutes**
  (during the waiting time a line appears every minute), or **the screen
  stays black for more than 5 minutes after "blanking the screen now"**:
  hold the power button for about 10 seconds until the machine switches
  off, then switch it on again. This was safe on 2026-10-03 too. Everything
  up to the last finished step is already on disk. GRUB boots your normal
  system. If you do nothing, the safety timer forces a reboot at the latest
  20 minutes + the delay + 2 minutes per repeat after the test started
  (about 27 minutes with the defaults; `arm.sh` prints the number).
- **GRUB chooses "fay-dcp DCP test" again and again:** in the GRUB menu,
  pick "Omarchy Linux" within the 5 seconds, boot normally, then run
  `sudo ./arm.sh disarm`. (This can only happen if GRUB cannot clear its
  one-shot setting and the test boot died before the script started; step 2
  checks for this.)
- **Kernel panic in the test boot:** the test entry has `panic=10`, so the
  machine restarts after 10 seconds. If that happens before the script ran
  and GRUB cannot clear its one-shot setting, the test entry comes up again
  and stops at the passphrase prompt: switch off, then choose "Omarchy Linux"
  in the GRUB menu as above.
- **A text login prompt stays for more than 5 minutes and nothing happens:**
  log in as mg and run `sudo systemctl reboot`. Then send
  `journalctl -b -1 -u fay-dcptest` and the newest result folder.
- **GRUB stops at a `grub>` prompt** (only possible after a power loss in
  the second in which install.sh or uninstall.sh replaces the GRUB menu):
  type `configfile $prefix/grub.cfg.fay-prev` and press Enter; if that is
  not found, try `configfile /grub/grub.cfg.fay-prev`. Then boot normally
  and run `sudo ./install.sh` (or `sudo ./uninstall.sh`) again.
- **You armed by mistake and have not rebooted yet:** `sudo ./arm.sh disarm`.
- The test script deletes the "armed" marker and the one-time GRUB choice
  before it does anything else, and the normal GRUB default is never
  changed. So once the script has started, a test boot cannot repeat.

## Repeats and options

```
sudo ./arm.sh full 360               # wait 6 minutes before blanking (uptime like the original crash)
sudo REPEATS=1 ./arm.sh full         # only one blank attempt
sudo REBOOT=sysrq ./arm.sh dry       # dry run that ends with the abrupt reboot
```

Put the options after `sudo`, as shown. sudo drops variables set in front
of it.

The number (`delay_seconds`, default 20) is a wait after the boot data is
saved. In a dry run it gives a second, "late" snapshot, which shows whether
the page table changes on its own over time. During the wait the console
shows "still waiting, N s left" every minute.

## Remove everything

```
sudo ./uninstall.sh                  # removes entry, service, script; un-pauses the cleanup service
sudo ./uninstall.sh --remove-modules # also deletes /usr/lib/modules/7.2.2-fay-dcp right away
```

The results in `/var/lib/fay-dcptest/<boot_id>/` are kept. uninstall.sh can
be run again if it stopped with an error: it keeps the GRUB entry's file
until the new GRUB menu has passed all checks and is on disk.

## Result files (one folder per test boot)

| File | Meaning |
|---|---|
| `SUMMARY.txt` | Mode, crashed yes/no, kernel calls that hung, why the screen was not blanked (if so), both verdicts |
| `VERDICT-owner.txt` | Who mapped the crash page 0x10fffdfc000 at boot (H1/H2/H3/H4 decision) |
| `VERDICT-owner-late.txt` | Same, after the delay |
| `VERDICT-fault.txt` | Full run: page-table state at the fault ((a) walker/TLB, (b) entry wiped, (c) locked table differs, or H2 unmap) and the events around it |
| `stage2.txt`, `snapshots.txt` | Page-table addresses and values (kernel table, locked table, leaf entry) |
| `l1-*.bin`, `l2-*.bin` | Raw 16 KiB page-table pages: pre, late, post-N |
| `trace-*.txt` | Kernel trace (DMA mappings, DCP callbacks and mailbox, probe hits), timestamps as in dmesg |
| `dmesg-*.txt`, `journal-kernel.txt` | Kernel log (redacted), including the instrumented driver's `fay-cb:`, `fay-cb-ack:` and `fay-sweep:` lines |
| `debugfs-*` | Sweep and crashlog copies from the instrumented driver, if present |
| `PROBES.txt`, `probe-errors.txt` | Hit count per probe, missed events, and any probe that failed to register |
| `kprobe_profile-*.txt` | Hits and missed events per probe at each snapshot |
| `00-env.txt`, `grubenv-after-S0.txt` | Kernel, command line and memory (redacted); whether GRUB's one-shot choice was cleared |
| `run.log` | Step-by-step log of the script |
| `WATCHDOG-FIRED.txt` | Only present if the safety timer had to force the reboot |

## Notes

- Reading the firmware crash log through `/dev/mem` was deliberately left
  out. The instrumented driver (patch 0008) keeps a copy under debugfs, and
  the script copies that.
- The test script loads the display driver with `fay_cb_log=1`, so every
  firmware callback is logged. A normal desktop boot of the "with Linux
  fay-dcp" entry uses the driver's default (2), which leaves out the two
  callbacks that come with every frame. (Since 2026-10-10 the default is 0.)
- The dry run ends with a normal reboot. During a normal shutdown, the
  display driver itself also powers the display controller down, so a DCP
  crash message at shutdown in the dry run is not a problem. The script uses
  the abrupt reboot instead whenever the display state is not known to be
  good (crash, failed or unfinished blank, a driver call that hung).
- The test boot uses `loglevel=3`, so kernel messages do not flood the text
  console. The full kernel log is still saved.
- USB-C on 7.2.2-fay-dcp needs `config-usb-c.fragment` (USB4, Apple ACIO,
  CIO reset, all as modules). Without them the PD controllers `spmi 1-0a`
  and `1-0c` wait for the ACIO supplier forever (`devices_deferred`), so only
  `port0` exists and no USB device can work. Charging is not affected. With
  the modules the ACIO driver only registers itself; it powers the block up
  only for a USB4/Thunderbolt partner. A power-only charger gives no USB
  data role, so no xHCI appears until a USB device is plugged in.
