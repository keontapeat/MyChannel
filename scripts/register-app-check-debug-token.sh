#!/usr/bin/env bash
# Register an App Check debug token for the MyChannel iOS app.
#
# Usage:
#   scripts/register-app-check-debug-token.sh <DEBUG_TOKEN_UUID> [DISPLAY_NAME]
#
# Reads the OAuth access token from the local Firebase CLI configstore so we
# don't have to store another credential. Requires `firebase login` to have been
# run on this machine (which it has — keontapeat@mychannel.live).
#
# Project / app are pinned to the MyChannel iOS Firebase app:
#   project number: 124515086975
#   app id:         1:124515086975:ios:f3683f5fb93c02d2c3454a
set -euo pipefail

if [[ "${1:-}" == "" ]]; then
  echo "usage: $0 <DEBUG_TOKEN_UUID> [DISPLAY_NAME]" >&2
  exit 1
fi

DEBUG_TOKEN="$1"
DISPLAY_NAME="${2:-iOS Simulator (auto)}"

PROJECT_NUMBER="124515086975"
APP_ID="1:124515086975:ios:f3683f5fb93c02d2c3454a"

CONFIGSTORE="$HOME/.config/configstore/firebase-tools.json"
if [[ ! -f "$CONFIGSTORE" ]]; then
  echo "❌ Firebase CLI configstore not found at $CONFIGSTORE — run 'firebase login' first." >&2
  exit 1
fi

ACCESS_TOKEN="$(python3 -c '
import json, sys, time, urllib.request, urllib.parse
p = "'"$CONFIGSTORE"'"
d = json.load(open(p))
t = d.get("tokens") or {}
now_ms = int(time.time() * 1000)
# If still valid for at least 60s, use it; otherwise refresh.
if t.get("access_token") and t.get("expires_at", 0) > now_ms + 60_000:
    print(t["access_token"])
    sys.exit(0)

refresh_token = t.get("refresh_token")
if not refresh_token:
    print("ERR: no refresh_token in firebase-tools configstore", file=sys.stderr)
    sys.exit(2)

# Firebase CLI uses Google'\''s public OAuth client (same one the CLI ships with).
# These IDs are not secret; they are baked into the firebase-tools binary.
client_id = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
client_secret = "j9iVZnySqyHrjJ0sHF3OS6_2"
body = urllib.parse.urlencode({
    "client_id": client_id,
    "client_secret": client_secret,
    "refresh_token": refresh_token,
    "grant_type": "refresh_token",
}).encode()
req = urllib.request.Request("https://oauth2.googleapis.com/token", data=body, method="POST")
with urllib.request.urlopen(req) as resp:
    fresh = json.load(resp)
print(fresh["access_token"])
')"

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "❌ failed to get access token" >&2
  exit 1
fi

echo "🔑 Registering App Check debug token..."
echo "   project: $PROJECT_NUMBER"
echo "   app:     $APP_ID"
echo "   token:   ${DEBUG_TOKEN:0:8}…"
echo "   name:    $DISPLAY_NAME"

RESPONSE="$(curl -sS -X POST \
  "https://firebaseappcheck.googleapis.com/v1/projects/${PROJECT_NUMBER}/apps/${APP_ID}/debugTokens" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"displayName\":\"${DISPLAY_NAME}\",\"token\":\"${DEBUG_TOKEN}\"}")"

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

if echo "$RESPONSE" | grep -q '"name"'; then
  echo ""
  echo "✅ Debug token registered. App Check 403 errors should clear on the next app launch."
else
  echo ""
  echo "⚠️  Registration may have failed — see response above. (A 'token already exists' error is fine.)"
fi
