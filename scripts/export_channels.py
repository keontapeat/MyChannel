#!/usr/bin/env python3
"""
Parse the Swift LiveTVChannel sample data chunks and export a JSON catalog
that mirrors what the app bundles. Resolves the s_* stream-URL constants from
LiveTVChannel+SampleData.swift so streamURL/previewFallbackURL are concrete.

Output: build-verify/ltv_channels.json  (list of channel dicts)
"""
import json
import re
import glob
import os

MODELS_DIR = "/Users/keonta/Documents/MyChannel/MyChannel/Core/Models"
INDEX_FILE = os.path.join(MODELS_DIR, "LiveTVChannel+SampleData.swift")
OUT_FILE = "/Users/keonta/Documents/MyChannel/build-verify/ltv_channels.json"

# --- 1. Resolve s_* constants (two passes for aliases like s_entertain1 = s_cbsnews) ---
const_re = re.compile(r'static let (s_\w+)\s*=\s*(?:"([^"]+)"|(\w+))')
consts = {}
pending = []
with open(INDEX_FILE) as f:
    for line in f:
        m = const_re.search(line)
        if m:
            name = m.group(1)
            if m.group(2) is not None:
                consts[name] = m.group(2)
            else:
                pending.append((name, m.group(3)))
# resolve aliases
for _ in range(5):
    for name, ref in pending:
        if ref in consts and name not in consts:
            consts[name] = consts[ref]

def resolve(token):
    token = token.strip()
    if token.startswith('"') and token.endswith('"'):
        return token[1:-1]
    if token in consts:
        return consts[token]
    return None

# --- 2. Parse each channel block ---
field_patterns = {
    "id": re.compile(r'id:\s*"([^"]*)"'),
    "name": re.compile(r'name:\s*"([^"]*)"'),
    "logoURL": re.compile(r'logoURL:\s*"([^"]*)"'),
    "category": re.compile(r'category:\s*\.(\w+)'),
    "description": re.compile(r'description:\s*"((?:[^"\\]|\\.)*)"'),
    "isLive": re.compile(r'isLive:\s*(true|false)'),
    "viewerCount": re.compile(r'viewerCount:\s*([0-9_]+)'),
    "quality": re.compile(r'quality:\s*"([^"]*)"'),
    "language": re.compile(r'language:\s*"([^"]*)"'),
    "country": re.compile(r'country:\s*"([^"]*)"'),
    "streamURL": re.compile(r'streamURL:\s*(s_\w+|"[^"]*")'),
    "previewFallbackURL": re.compile(r'previewFallbackURL:\s*(s_\w+|"[^"]*"|nil)'),
}

def extract_blocks(text):
    """Return the inner text of each LiveTVChannel( ... ) call via paren matching."""
    blocks = []
    marker = "LiveTVChannel("
    i = 0
    while True:
        start = text.find(marker, i)
        if start == -1:
            break
        j = start + len(marker)
        depth = 1
        in_str = False
        while j < len(text) and depth > 0:
            c = text[j]
            if c == '"' and text[j-1] != '\\':
                in_str = not in_str
            elif not in_str:
                if c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
            j += 1
        blocks.append(text[start + len(marker):j-1])
        i = j
    return blocks

channels = []
for path in sorted(glob.glob(os.path.join(MODELS_DIR, "LiveTVChannel+SampleData_c0*.swift"))):
    if os.path.basename(path).startswith("._"):
        continue
    with open(path) as f:
        text = f.read()
    for block in extract_blocks(text):
        ch = {}
        for key, pat in field_patterns.items():
            m = pat.search(block)
            if not m:
                continue
            val = m.group(1)
            if key in ("streamURL", "previewFallbackURL"):
                if val == "nil":
                    continue
                resolved = resolve(val)
                if resolved:
                    ch[key] = resolved
            elif key == "viewerCount":
                ch[key] = int(val.replace("_", ""))
            elif key == "isLive":
                ch[key] = (val == "true")
            else:
                ch[key] = val
        if ch.get("id") and ch.get("name") and ch.get("streamURL"):
            channels.append(ch)

# de-dupe by id
seen = set()
unique = []
for ch in channels:
    if ch["id"] in seen:
        continue
    seen.add(ch["id"])
    unique.append(ch)

with open(OUT_FILE, "w") as f:
    json.dump(unique, f, indent=2)
print(f"Exported {len(unique)} channels to {OUT_FILE}")
