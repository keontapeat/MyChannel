#!/usr/bin/env python3
"""Rank slowest-compiling Swift code from xcodebuild warning output.

Usage:
    python3 scripts/rank_slow_compiles.py [build_log ...]

If no log is given it falls back to slow_build_warnings.txt. You can pass
multiple logs (e.g. full_build.log full_build2.log) and they are merged,
keeping the worst time seen per unique source site.

Tip: generate fresh data with scripts/measure_build_times.sh, which builds
with -warn-long-function-bodies / -warn-long-expression-type-checking and
pipes the result here.
"""
import re
import sys
from collections import defaultdict

paths = sys.argv[1:] or ["slow_build_warnings.txt"]

# Match: /path/File.swift:LINE:COL: warning: ... took NNNms to type-check
# IMPORTANT: the path class excludes ':' AND newlines/whitespace so a single
# regex can't span multiple log lines (the old version did, which captured
# macro-expansion artifacts and "in target ..." noise into the file path).
pat = re.compile(r"(/\S+?\.swift):(\d+):\d+: warning: (.+?) took (\d+)ms")

by_site = {}  # (file,line,desc) -> max ms (dedupe repeated identical warnings)

for path in paths:
    try:
        with open(path, "r", errors="ignore") as f:
            text = f.read()
    except FileNotFoundError:
        print(f"warning: log not found, skipping: {path}", file=sys.stderr)
        continue

    for m in pat.finditer(text):
        fpath, line, desc, ms = m.group(1), m.group(2), m.group(3), int(m.group(4))
        # Skip compiler-synthesized macro expansions (e.g. #Preview macro).
        # They aren't editable source and only add noise to the ranking.
        if "@__swiftmacro" in fpath or "/.build/" in fpath:
            continue
        key = (fpath, line, desc)
        # keep the max time seen for an identical site (batch mode repeats them)
        if key not in by_site or ms > by_site[key][0]:
            by_site[key] = (ms, desc)

# Per-file totals from deduped sites
by_file = defaultdict(int)
site_list = []
for (fpath, line, desc), (ms, _) in by_site.items():
    by_file[fpath] += ms
    site_list.append((ms, fpath, line, desc))


def short_path(fpath: str) -> str:
    return fpath.split("/MyChannel/")[-1] if "/MyChannel/" in fpath else fpath


print("=" * 72)
print("TOP 15 SLOWEST FILES (sum of unique slow sites, ms)")
print("=" * 72)
for fpath, total in sorted(by_file.items(), key=lambda x: -x[1])[:15]:
    print(f"{total:>7} ms  {short_path(fpath)}")

print()
print("=" * 72)
print("TOP 25 SLOWEST INDIVIDUAL SITES")
print("=" * 72)
for ms, fpath, line, desc in sorted(site_list, key=lambda x: -x[0])[:25]:
    d = (desc[:48] + "\u2026") if len(desc) > 49 else desc
    print(f"{ms:>7} ms  {short_path(fpath)}:{line}  [{d}]")

print()
print(f"Logs parsed:             {', '.join(paths)}")
print(f"Total unique slow sites: {len(site_list)}")
print(f"Total files affected:    {len(by_file)}")
