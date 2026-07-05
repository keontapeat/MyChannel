#!/usr/bin/env bash
# Update the bundle ID on the RevenueCat iOS app to match the Xcode project.
#
# Why this exists:
#   App startup logs show:
#     "Your app's Bundle ID 'com.keontapeat.MyChannelApp' doesn't match the
#      RevenueCat configuration 'live.mychannel.app'."
#   This causes the SDK to reject offerings/purchases. Real source of truth is
#   the iOS project: PRODUCT_BUNDLE_IDENTIFIER = com.keontapeat.MyChannelApp.
#   So we update the RevenueCat dashboard to match the app, not the other way
#   around.
#
# Usage:
#   RC_SECRET_KEY=sk_xxx scripts/fix-revenuecat-bundle-id.sh
#
# Get the secret key (one-time):
#   1. Open https://app.revenuecat.com/projects/00019812/api-keys
#   2. Under "Project API keys" copy the "Secret API key" (starts with sk_).
#   3. Export it: export RC_SECRET_KEY=sk_...
#
# This key is NOT the SDK key shipped in AppSecrets.swift. It is project-level
# and must NEVER be committed. It is only read from the env var at runtime.
set -euo pipefail

if [[ -z "${RC_SECRET_KEY:-}" ]]; then
  echo "❌ RC_SECRET_KEY env var not set." >&2
  echo "" >&2
  echo "Get it from https://app.revenuecat.com/projects/00019812/api-keys" >&2
  echo "Then run:" >&2
  echo "  export RC_SECRET_KEY=sk_xxx" >&2
  echo "  scripts/fix-revenuecat-bundle-id.sh" >&2
  exit 1
fi

PROJECT_ID="00019812"
TARGET_BUNDLE_ID="com.keontapeat.MyChannelApp"

API="https://api.revenuecat.com/v2/projects/${PROJECT_ID}/apps"

echo "🔍 Listing RevenueCat apps in project ${PROJECT_ID}..."
APPS_JSON="$(curl -sS -H "Authorization: Bearer ${RC_SECRET_KEY}" -H "Accept: application/json" "${API}")"

if ! echo "$APPS_JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
  echo "❌ Bad response from RevenueCat:" >&2
  echo "$APPS_JSON" >&2
  exit 1
fi

# Find the iOS app (type == "app_store")
IOS_APP_ID="$(echo "$APPS_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
items = data.get("items", [])
for app in items:
    if app.get("type") == "app_store":
        print(app["id"])
        break
')"

if [[ -z "$IOS_APP_ID" ]]; then
  echo "❌ No iOS (app_store) app found in RevenueCat project ${PROJECT_ID}." >&2
  echo "Apps returned:" >&2
  echo "$APPS_JSON" | python3 -m json.tool >&2 || echo "$APPS_JSON" >&2
  exit 1
fi

echo "📱 iOS app id: ${IOS_APP_ID}"
echo "🛠  Updating bundle ID → ${TARGET_BUNDLE_ID}"

UPDATE_RESPONSE="$(curl -sS -X POST \
  -H "Authorization: Bearer ${RC_SECRET_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"app_store\":{\"bundle_id\":\"${TARGET_BUNDLE_ID}\"}}" \
  "${API}/${IOS_APP_ID}")"

echo "$UPDATE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$UPDATE_RESPONSE"

if echo "$UPDATE_RESPONSE" | python3 -c '
import json, sys
target = "'"$TARGET_BUNDLE_ID"'"
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
ok = d.get("app_store", {}).get("bundle_id") == target or d.get("bundle_id") == target
sys.exit(0 if ok else 1)
'; then
  echo ""
  echo "✅ RevenueCat iOS app bundle ID is now ${TARGET_BUNDLE_ID}."
  echo "   Restart the app and the 'Bundle ID doesn'\''t match' SDK error will clear."
else
  echo ""
  echo "⚠️  Update may have failed — check response above. If it says the field is read-only," >&2
  echo "    the bundle ID has to be set in the RevenueCat dashboard:" >&2
  echo "    https://app.revenuecat.com/projects/${PROJECT_ID}/apps/${IOS_APP_ID}/general" >&2
fi
