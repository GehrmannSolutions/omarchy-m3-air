# SPDX-License-Identifier: MIT
# m1n1 hypervisor script (run_guest.py -m): trace the t8122 (M3) ATC0 PHY while macOS
# brings up DisplayPort alt mode on the left-rear USB-C port (atc0).
# Ranges are from the macOS ADT of a Mac15,12 (atc-phy0 reg list) plus the AUX
# block found at core+0x16000/0x16400. Writes and reads are logged in order.
from m1n1.hv import TraceMode
from m1n1.utils import irange

CORE = 0x703000000
RANGES = [
    (CORE + 0x00000, 0x3000, "AUSCMN/PLL/AUSPLL"),
    (CORE + 0x07000, 0x1000, "ACIOPHY_LANE_DP_CFG (TX_DP_CTRL0)"),
    (CORE + 0x09000, 0x5000, "LN0 RX/TX"),
    (CORE + 0x10000, 0x5000, "LN1 RX/TX"),
    (CORE + 0x16000, 0x800,  "ACIOPHY_AUX_TOP/AUX_SHM"),
    (CORE + 0x17000, 0x1000, "ACIOPHY_BIST"),
    (CORE + 0x20000, 0x100,  "ATCPHY power/misc"),
    (0x70304c000,    0x4000, "atc0-dpxbar"),
]

for start, size, name in RANGES:
    print(f"fay: tracing {name} {start:#x}+{size:#x}")
    hv.trace_range(irange(start, size), mode=TraceMode.SYNC)
