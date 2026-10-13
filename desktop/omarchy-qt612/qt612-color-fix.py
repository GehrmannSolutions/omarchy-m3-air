#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marius Gehrmann
# SPDX-License-Identifier: MIT
"""Qualify omarchy's Color singleton as Commons.Color (Qt 6.12 shadows bare `Color`).
Same pattern as omacom/omarchy PR #14553. Usage: qt612-color-fix.py [--write] DIR..."""
import re, sys, pathlib
write = "--write" in sys.argv
dirs = [a for a in sys.argv[1:] if a != "--write"]
bare = re.compile(r'(?<![\w."\'/])Color(?=\s*\.)')          # Color.xyz
target = re.compile(r'(\btarget\s*:\s*)Color\b')            # Connections { target: Color }
changed = 0
for d in dirs:
    for p in sorted(pathlib.Path(d).rglob("*.qml")):
        if p.name == "Color.qml" and p.parent.name == "Commons":
            continue
        s = p.read_text()
        n = s
        n = target.sub(r'\1Commons.Color', n)
        n = bare.sub('Commons.Color', n)
        n = n.replace('Commons.Commons.Color', 'Commons.Color')
        if n == s:
            continue
        if 'import qs.Commons as Commons' not in n:
            lines = n.split('\n')
            idx = None
            for i, l in enumerate(lines):
                if l.strip() == 'import qs.Commons':
                    idx = i; break
            if idx is None:
                for i, l in enumerate(lines):
                    if l.startswith('import '):
                        idx = i
                if idx is None:
                    print("SKIP (no import):", p); continue
            lines.insert(idx + 1, 'import qs.Commons as Commons')
            n = '\n'.join(lines)
        changed += 1
        cnt = len(bare.findall(s)) + len(target.findall(s))
        print(f"{'WRITE' if write else 'would change'} {p} ({cnt} refs)")
        if write:
            p.write_text(n)
print("files:", changed)
