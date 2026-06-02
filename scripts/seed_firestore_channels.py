#!/usr/bin/env python3
"""
Seed the liveTVChannels Firestore collection from build-verify/ltv_channels.json
using the Firebase CLI access token + Firestore REST API.

Idempotent: each channel is written to liveTVChannels/{id} (PATCH = create/overwrite).
"""
import json
import subprocess
import sys
import time
import urllib.request
import urllib.error

PROJECT = "mychannel-ca26d"
CHANNELS_FILE = "/Users/keonta/Documents/MyChannel/build-verify/ltv_channels.json"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/liveTVChannels"


def get_token():
    out = subprocess.check_output(
        ["firebase", "login:ci", "--no-localhost"],
        stderr=subprocess.DEVNULL
    ) if False else None
    # Use the access token from gcloud-style firebase CLI
    out = subprocess.check_output(["firebase", "--project", PROJECT, "auth:export", "/dev/null"],
                                  stderr=subprocess.DEVNULL) if False else None
    # Simplest: ask the firebase CLI for an access token
    token = subprocess.check_output(["firebase", "login:list"], stderr=subprocess.DEVNULL)
    raise RuntimeError("placeholder")


def to_fs_value(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, str):
        return {"stringValue": v}
    return {"stringValue": str(v)}


def main(token):
    with open(CHANNELS_FILE) as f:
        channels = json.load(f)

    ok = 0
    fail = 0
    for i, ch in enumerate(channels):
        cid = ch["id"]
        fields = {}
        for k, v in ch.items():
            if k == "id":
                continue
            fields[k] = to_fs_value(v)
        fields["sortIndex"] = {"integerValue": str(i)}
        body = json.dumps({"fields": fields}).encode()

        url = f"{BASE}/{urllib.parse.quote(cid)}"
        req = urllib.request.Request(url, data=body, method="PATCH")
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                if r.status in (200, 201):
                    ok += 1
                else:
                    fail += 1
                    print(f"  ⚠️ {cid}: HTTP {r.status}")
        except urllib.error.HTTPError as e:
            fail += 1
            print(f"  ⛔ {cid}: {e.code} {e.read().decode()[:200]}")
        except Exception as e:
            fail += 1
            print(f"  ⛔ {cid}: {e}")
        if (i + 1) % 25 == 0:
            print(f"  ... {i+1}/{len(channels)}")
        time.sleep(0.05)

    print(f"\n✅ Seeded {ok}/{len(channels)} channels ({fail} failed)")


if __name__ == "__main__":
    import urllib.parse
    if len(sys.argv) < 2:
        print("Usage: seed_firestore_channels.py <ACCESS_TOKEN>")
        sys.exit(1)
    main(sys.argv[1])
