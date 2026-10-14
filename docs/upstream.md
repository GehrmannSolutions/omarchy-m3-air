# Upstream

| Where | What | Status |
|---|---|---|
| [omacom/linux-aurora#102](https://github.com/omacom/linux-aurora/issues/102) | PMP record bits for T8122 devices (kernel patch 0001) | filed 2026-10-13 |
| [omacom/linux-aurora#103](https://github.com/omacom/linux-aurora/issues/103) | J613 external displays over USB-C, branch offered | filed 2026-10-13; maintainer carried it as #114; our test results posted there 2026-10-14 |
| [omacom/linux-aurora#114](https://github.com/omacom/linux-aurora/pull/114) | draft PR by the maintainer with our 12 patches, reworked: the kernel enables `dcpext` only when m1n1 sets `apple,t8122-dcpext-firmware-ready` | both requested test boots passed (with and without the marker) |
| [omacom/linux-aurora#32](https://github.com/omacom/linux-aurora/issues/32) | panel brightness on 14.x M3 panels | known upstream; J613 not yet tested |
| [omacom/linux-aurora#26](https://github.com/omacom/linux-aurora/issues/26) | M3 GPU start (DPE block, `patches-local/0003`) | comments |
| [omacom/omarchy#15307](https://github.com/omacom/omarchy/issues/15307) | lid open: panel stays off | filed 2026-10-13 |
| [omacom/omarchy#15368](https://github.com/omacom/omarchy/issues/15368) | lid closed with external displays: logind suspends when the display count drops to zero for a moment | filed 2026-10-14 |
| omacom/m1n1 | the m1n1 change that sets the marker | not submitted: the fork inherits Asahi's no-AI rule; asked in #103 whether it applies |
| Asahi Linux / m1n1 | – | not submitted: their policies forbid AI-assisted contributions |

The patch series lives as branch `fay/aurora-j613-dp-v2` in
[GehrmannSolutions/linux-aurora](https://github.com/GehrmannSolutions/linux-aurora).
