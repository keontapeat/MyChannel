#!/usr/bin/env python3
"""
Patch Live TV channel data files: replace dead YouTube logoURLs with the stable
mzstatic.com artwork resolved in build-verify/ltv_artwork.json.

For each channel whose `name:` matches a key in the artwork map, the FIRST
`logoURL:` line that follows is rewritten. Idempotent: re-running with the same
map produces no further changes.
"""
import json
import re
import glob
import os

ART_FILE = "/Users/keonta/Documents/MyChannel/build-verify/ltv_artwork.json"
DATA_GLOB = "/Users/keonta/Documents/MyChannel/MyChannel/Core/Models/LiveTVChannel+SampleData_c0*.swift"

NAME_RE = re.compile(r'^\s*name:\s*"(.*?)"\s*,\s*$')
LOGO_RE = re.compile(r'^(\s*logoURL:\s*)"(.*?)"(.*)$')


def main():
    with open(ART_FILE) as f:
        art = json.load(f)

    total_patched = 0
    for path in sorted(glob.glob(DATA_GLOB)):
        if os.path.basename(path).startswith("._"):
            continue
        with open(path) as f:
            lines = f.readlines()

        patched = 0
        pending_name = None
        for i, line in enumerate(lines):
            m = NAME_RE.match(line)
            if m:
                pending_name = m.group(1)
                continue
            if pending_name is not None:
                lm = LOGO_RE.match(line)
                if lm:
                    if pending_name in art:
                        new_url = art[pending_name]
                        # Preserve any trailing comment after the closing quote
                        trailing = lm.group(3)
                        lines[i] = f'{lm.group(1)}"{new_url}"{trailing}\n'
                        patched += 1
                    pending_name = None  # consumed this channel's logo
        if patched:
            with open(path, "w") as f:
                f.writelines(lines)
            print(f"  patched {patched:>2} in {os.path.basename(path)}")
            total_patched += patched

    print(f"\nTotal logoURLs patched: {total_patched}")


if __name__ == "__main__":
    main()
