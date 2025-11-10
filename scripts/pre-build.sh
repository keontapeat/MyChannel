#!/bin/bash

# Pre-Build Script - Runs before each Xcode build
# Add this to Xcode: Build Phases > New Run Script Phase

echo "🚀 Pre-Build Check Started"

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

# Clear DerivedData if there are persistent build errors
if [ -f "/tmp/mychannel_build_failed" ]; then
    echo "🧹 Previous build failed - clearing DerivedData"
    rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-* 2>/dev/null
    rm /tmp/mychannel_build_failed
fi

# Run SwiftLint if available
if command -v swiftlint &> /dev/null; then
    echo "🔍 Running SwiftLint..."
    swiftlint --fix --quiet || true
fi

# Check for common issues
echo "🔍 Checking for common issues..."

# Check for duplicate type names
DUPLICATES=$(find "$PROJECT_DIR/MyChannel" -name "*.swift" -exec grep -h "^struct\|^class\|^enum" {} \; | \
             awk '{print $2}' | sort | uniq -d)

if [ ! -z "$DUPLICATES" ]; then
    echo "⚠️  Warning: Potential duplicate types detected:"
    echo "$DUPLICATES"
fi

echo "✅ Pre-Build Check Complete"


