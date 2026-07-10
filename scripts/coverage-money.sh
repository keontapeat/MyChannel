#!/usr/bin/env bash
# Echoes the xcodebuild command for money-related code coverage.
# Run locally after a successful test pass; open the .xcresult in Xcode Organizer.

set -euo pipefail

SCHEME="${SCHEME:-MyChannel}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 15 Pro,OS=latest}"

echo "Money coverage — run this after MyChannelTests pass:"
echo ""
cat <<EOF
xcodebuild test \\
  -project MyChannel.xcodeproj \\
  -scheme ${SCHEME} \\
  -destination '${DESTINATION}' \\
  -only-testing:MyChannelTests/MoneyMathTests \\
  -only-testing:MyChannelTests/MoneyEscrowMathTests \\
  -only-testing:MyChannelTests/MoneyMathGoldenTests \\
  -only-testing:MyChannelTests/WagerPolicyTests \\
  -only-testing:MyChannelTests/TermsVersionSyncTests \\
  -only-testing:MyChannelTests/EscrowIdempotencyTests \\
  -enableCodeCoverage YES \\
  -resultBundlePath ./build/MoneyCoverage.xcresult \\
  CODE_SIGNING_ALLOWED=NO
EOF
echo ""
echo "Then: xcrun xccov view --report ./build/MoneyCoverage.xcresult --only-targets MyChannel"
