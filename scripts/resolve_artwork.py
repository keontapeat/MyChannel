#!/usr/bin/env python3
"""
Resolve stable artwork for Live TV channels whose YouTube thumbnails are dead (404).

Strategy:
  1. Read the dead-channel report (build-verify/ltv_dead.txt).
  2. For each channel name, query the keyless iTunes Search API for stable
     mzstatic.com artwork (tvShow, then movie, then podcast, then music as a
     last resort), validating each candidate returns a real (>=2KB) image.
  3. Write a JSON map {channelName: artworkURL} to build-verify/ltv_artwork.json.

mzstatic.com URLs are immutable once published, so they don't rot like YouTube
video IDs. News/sports channels that have no iTunes match are left for the
branded category fallback (which already looks intentional).
"""
import json
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

DEAD_FILE = "/Users/keonta/Documents/MyChannel/build-verify/ltv_dead.txt"
OUT_FILE = "/Users/keonta/Documents/MyChannel/build-verify/ltv_artwork.json"

# Manual overrides / search-term cleanups for ambiguous names.
SEARCH_OVERRIDES = {
    "Pluto TV Horror": "horror movies",
    "Pluto TV Comedy": "comedy",
    "Pluto TV Sci-Fi": "sci-fi",
    "Pluto TV Español": "telenovela",
    "BET Pluto TV": "BET",
    "VH1 Pluto TV": "Behind the Music",
    "BET Jams": "hip hop",
    "90's Kids TV": "Rugrats",
    "Go Go Gadget!": "Inspector Gadget",
    "Home & How-To": "This Old House",
    "Poker Channel": "World Series of Poker",
    "Fight Network": "UFC",
    "Crime + Investigation": "The First 48",
    "The Pet Collective": "Funniest Animals",
    "Mister Rogers": "Mister Rogers Neighborhood",
    "LEGO Kids TV": "LEGO Ninjago",
    "Comedy Central": "South Park",
    "Cartoon Network": "Adventure Time",
    "Nickelodeon": "SpongeBob SquarePants",
    "Nick Jr.": "Paw Patrol",
    "Treehouse TV": "Paw Patrol",
}

ENTITIES = [
    ("tvShow", "tvSeason"),
    ("movie", "movie"),
]


def http_size_ok(url: str) -> bool:
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=12) as r:
            if r.status != 200:
                return False
            data = r.read(4096)
            # follow content-length if present
            cl = r.headers.get("Content-Length")
            if cl and int(cl) < 2000:
                return False
            return len(data) > 1500
    except Exception:
        return False


def itunes_artwork(term: str):
    enc = urllib.parse.quote(term)
    for media_entity in ENTITIES:
        media, entity = media_entity
        api = f"https://itunes.apple.com/search?term={enc}&media={media}&entity={entity}&limit=3"
        try:
            with urllib.request.urlopen(api, timeout=12) as r:
                payload = json.load(r)
        except Exception:
            continue
        for result in payload.get("results", []):
            art = result.get("artworkUrl100") or result.get("artworkUrl60")
            if not art:
                continue
            art = art.replace("100x100bb", "600x600bb").replace("60x60bb", "600x600bb")
            if http_size_ok(art):
                return art
        time.sleep(0.15)
    return None


def main():
    names = []
    seen = set()
    with open(DEAD_FILE) as f:
        for line in f:
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 2:
                name = parts[1]
                if name and name not in seen:
                    seen.add(name)
                    names.append(name)

    print(f"Resolving artwork for {len(names)} dead channels...")
    result = {}
    for name in names:
        term = SEARCH_OVERRIDES.get(name, name)
        art = itunes_artwork(term)
        if art:
            result[name] = art
            print(f"  ✅ {name} -> {art}")
        else:
            print(f"  ⛔ {name} (no stable match — will use branded fallback)")
        time.sleep(0.2)

    with open(OUT_FILE, "w") as f:
        json.dump(result, f, indent=2)
    print(f"\nResolved {len(result)}/{len(names)} channels. Written to {OUT_FILE}")


if __name__ == "__main__":
    main()
