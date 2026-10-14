# Power, battery and temperatures (2026-10-14)

Measured on our J613 with the daily kernel `7.1.12-fay-v2` (r4, see [status.md](status.md)). The
battery reports 49.0 Wh full charge (52.0 Wh design, 135 cycles).

## Battery life: one full day (2026-10-14, 13:23-23:06)

One boot, 9 h 43 min, never suspended. Read from the journal and upower's charge history.

| Time | What ran | Battery |
|---|---|---|
| 13:23-15:48 | on the charger, development work | 100 % |
| 15:48 | off the charger | 99 % |
| 15:49-16:21 | 32-minute GPU soak (llama.cpp on Vulkan, see below) | 99 → 89 % |
| 16:21-21:35 | mostly idle desktop, screen on, not suspended | ~11 % per hour |
| 21:38-22:48 | heavy CPU load tests (thermal work below) | ~15 % per hour |
| 22:48 | back on the charger at 10 % | |

- 7 h 00 min on battery from 99 % to 10 %: about 44 Wh, **6.2 W on average**.
- Idle desktop with the screen on: **about 5.4 W**, a bit over 9 hours from a full battery.
- GPU soak (Qwen2.5-3B Q4_K_M on Honeykrisp, all layers on the GPU, 16 back-to-back llama-bench
  runs): 9.7 W on average, 16 W peak, 11 % of the battery in 32 minutes, no GPU errors.
- The GPU is capped at 618 MHz (performance state 2 of 8) because there is no SoC die temperature
  zone for the GPU yet; see below. Its power and speed will change once that is lifted.

## Temperatures: what the SMC has

The kernel only exported four SMC temperatures (NAND, battery hotspot, charge regulator, Wi-Fi/BT
module). The SMC itself has 1850 keys, 156 of them temperatures, readable through the read-only
debugfs list of the Aurora `macsmc_hwmon` driver (`/sys/kernel/debug/macsmc-hwmon/keys`).
The M3 Pro/Max die keys the driver knows (`Tf..`) do not exist on the base M3.

We mapped them by loading one CPU at a time:

| Key | Sits on | Notes |
|---|---|---|
| `Tp05`, `Tp0L`, `Tp0b`, `Tp0r` | P cores 0-3 (`cpu@10100`-`cpu@10103`) | each has a twin about 6.5 C lower (`Tp04`, `Tp0K`, ...) |
| `Te05`, `Te0P` | the two E-cluster sensor groups | E cores add only 3-6 C |
| `TCMz` | follows the hottest P-core sensor closely | not exactly their maximum |
| `Tg..` (12 keys) | not yet assigned | at 618 MHz the GPU adds only 8-15 C, so no key stands out |
| `PP0b`, `PPbb` | P-cluster and E-cluster power | `PSTR` is total system power |

## No CPU temperature limit until now

With the four P cores busy at 4056 MHz the die passed 107 C at full clock (22 W system power) and
reached 111 C after two minutes, still rising. Nothing throttled:

- the CPU frequency driver's fast die-temperature limit (`apple,fast-die-effort`, driven by the PMP)
  is only wired for t8140 (M4) in the Aurora tree;
- the SMC's thermal pressure value is only shown in sysfs;
- the device tree had no thermal zones for the CPUs.

The machine survived a day of kernel builds like this, and the hardware very likely has its own
emergency limit, but nothing kept the die at a sane temperature.

### The fix we are testing: CPU thermal zones (boot.bin device tree only)

Three device-tree patches on top of our boot.bin DTs (no kernel change; the drivers are built in):

1. **CPU power per OPP** (`opp-microwatt`) for both clusters, measured through `PP0b`/`PPbb`
   (cluster pinned to the state, four CPUs busy minus idle, divided by four, fitted to smooth
   curves). The power allocator governor needs this energy model; without it every zone fails with
   "is not a power actor" and does nothing. The scheduler gets an energy model on T8122 too.
2. `#cooling-cells` on the CPUs and the six die sensors above as the first SMC hwmon channels.
3. Six thermal zones on J613, one per sensor, each throttling both clusters with the power
   allocator, as the fanless M4 J700 in the Aurora tree does: throttling towards 95 C, an orderly
   shutdown at 110 C as the last resort.

Load tests (shell busy loops pinned to the CPUs, 8-10 minutes per case, each starting below 55 C;
"hottest" is the hottest of the six zones after the first two minutes):

| Load | Setting | Hottest | P cores | E cores | System |
|---|---|---|---|---|---|
| 4 P cores | none (before) | 111 C after 2 min, rising | 4056 MHz | | 22 W |
| 4 P cores | J700 tuning, 1.5 W sustainable power | 72 C | 2.1 GHz | | 14 W |
| 4 P cores | **6 W** | 90-95 C (one 96.5 C peak) | 2.6-3.0 GHz, steady | | 19 W |
| 4 P cores | 7.5 W | up to 98 C | swings 2.2-3.6 GHz | | 18 W |
| all 8 cores | 6 W | 92 C, max 96 C | 2.2-2.4 GHz | 2748 MHz (full) | 20 W |
| 4 P cores + GPU soak | 6 W | max 97 C | 1.9-2.6 GHz | | 19 W |
| 4 E cores | 6 W | 74 C | not throttled | 2748 MHz (full) | 11 W |

- **6 W** is what we use: the J700's 1.5 W gives away half the P-core speed at 72 C, and higher
  values make the controller swing between states. The machine now holds about 92 C under any
  CPU load instead of running into 111 C.
- The GPU is not a cooling device in these zones. At 618 MHz it adds little, but before the GPU cap
  is raised the GPU needs its own temperature limit (the `macsmc_soc_die` zone the GPU driver
  already looks for, which needs a J613 entry with the die keys above).
- Status: running on our machine since 2026-10-14 (boot.bin device tree only, same kernel). The
  three device-tree patches will be added to [../boot/](../boot/) after a few days of daily use.

## Two oddities found on the way (not fixed)

- **The top P states are limited by the hardware.** Above 3288 MHz the P cluster's power stays at
  about 11 W with four cores busy, and an integer loop gets 8-10 % less work per clock at 4056 MHz
  than at 3420 MHz, even with one core busy at 63 C. The DVFS status register still reports
  4056 MHz.
- **The boot core is half as fast.** `cpu0` (P core `cpu@10100`) runs the same integer loop at half
  the rate of the other three P cores at the same pinned frequency, all of the time in user space,
  not interrupts. There is no CPU performance counter driver for M3 yet to see why.
