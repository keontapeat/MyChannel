#!/usr/bin/env bash
# Run MyChannel unit tests (web wager-policy always; iOS when on macOS with Xcode).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Web wager-policy unit tests (web-v2)"
cd web-v2
if command -v npx >/dev/null 2>&1 && npx --yes tsx --version >/dev/null 2>&1; then
  npm run test:unit
else
  node --test lib/wager-policy.test.mjs
fi
cd "$ROOT"

if [[ "$(uname -s)" == "Darwin" ]] && command -v xcodebuild >/dev/null 2>&1; then
  echo "==> iOS unit tests (MyChannel scheme, simulator)"
  set +e
  xcodebuild test \
    -project MyChannel.xcodeproj \
    -scheme MyChannel \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
    -only-testing:MyChannelTests \
    CODE_SIGNING_ALLOWED=NO \
    | xcpretty 2>/dev/null || true
  ios_status=${PIPESTATUS[0]}
  set -e
  if [[ $ios_status -ne 0 ]]; then
    echo "⚠️  iOS tests failed or scheme unavailable (exit $ios_status). Web tests passed."
    exit $ios_status
  fi
else
  echo "⏭  Skipping iOS tests (requires macOS + Xcode)."
fi

echo "✅ Unit test script finished."
