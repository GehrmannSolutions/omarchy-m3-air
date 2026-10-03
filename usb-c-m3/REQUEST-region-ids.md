# Request: region-id entries for the M3 display nodes (for the Linux side)

To: the agent or person on the Mac (macOS, MacBook Air M3, J613).
From: Fay (Linux side, MacBook Air M3, Omarchy).
Read only. Change nothing on macOS.

## What is needed

m1n1 reserves display memory regions based on `region-id-NN` properties of the display
nodes in Apple's device tree (ADT). Linux needs the exact entries, so that the carveout
table for the M3 (t8122) can be written. Fay has the node names and addresses already
(see the memory repo, plan `2026-10-03-dcp-14x-port-PLAN.md`). These entries are missing.

Deliver one text file that contains, for each display node:

1. the node name and its path, e.g. `dcp@7EC00000`, `disp0@7C000000`, `dcpext@AC00000`,
   `dart-dcp@7D30C000`, `dart-disp0@7D304000`, `dart-dcpext@930C000`
2. every line with a property named `region-id-NN` and its value
3. for the DART nodes: the `dart-id` / `sid` values, if present

## Command (Terminal, on the Mac)

This assumes the full dump already exists as `~/Desktop/fay-devicetree.txt`
(from `ioreg -p IODeviceTree -l -w0`). If it does not, create it first with that command.

```
awk '/^ *\+-o /{node=$0} /region-id-[0-9]+|dart-id|"sid"/{print node " | " $0}' ~/Desktop/fay-devicetree.txt > ~/Desktop/fay-region-ids.txt
wc -l ~/Desktop/fay-region-ids.txt
```

Check the result: the file must not be empty. It should contain lines with `region-id-`
for at least `dcp`, `disp0` and `dcpext`. If it is empty, the node format differs on this
macOS version. Then say so and send the output of `grep -n "region-id" ~/Desktop/fay-devicetree.txt | head -20` instead.

## Rules for the file

- Plain text only. No full dump, no serial numbers, no hardware IDs beyond the node names.
- Keep the original values exactly as printed, e.g. `<...>` hex strings. Do not convert.

## How to deliver

Option 1 (preferred, no stick): on the Mac in `~/Desktop`, run
`python3 -m http.server 8000`. Send the Mac's IP to Marius, then Fay fetches the file with
`curl http://<Mac-IP>:8000/fay-region-ids.txt`.

Option 2: copy the file to the exFAT stick `FAYTESTb` (one partition, no EFI). Tell Marius
if macOS cannot mount it.

## What Fay does with it

Writes the t8122 carveout table for m1n1 from these entries, checks it against the PR #608
DT nodes, and records the result in the plan. Nothing is installed without Marius's approval.
