#!/bin/bash

# MyChannel Build Debug Script
# Automatically analyzes and helps fix Xcode build issues

set -e

echo "🔍 Starting MyChannel Build Debug Session..."
echo "📅 $(date)"
echo "=================================="

# Navigate to project root
cd "$(dirname "$0")"

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -scheme MyChannel -configuration Debug -quiet

# Attempt build and capture errors
echo "🔨 Building project..."
xcodebuild -scheme MyChannel -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tee build-errors.log

# Count errors
ERROR_COUNT=$(grep -c "error:" build-errors.log || echo "0")
WARNING_COUNT=$(grep -c "warning:" build-errors.log || echo "0")

echo ""
echo "📊 Build Results:"
echo "   Errors: $ERROR_COUNT"
echo "   Warnings: $WARNING_COUNT"

if [ $ERROR_COUNT -eq 0 ]; then
    echo ""
    echo "🎉 BUILD SUCCESSFUL! No errors found."
    echo "✅ Your project is ready to run!"
    
    # Optional: Launch in simulator
    echo ""
    read -p "🚀 Would you like to launch the app in simulator? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📱 Launching app in simulator..."
        xcodebuild -scheme MyChannel -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' test-without-building || echo "⚠️  Could not auto-launch, but build is successful!"
    fi
    
    exit 0
fi

echo ""
echo "🔍 Analyzing errors..."

# Show top error files
echo ""
echo "📁 Top files with errors:"
grep "error:" build-errors.log | cut -d':' -f1 | sort | uniq -c | sort -nr | head -5

# Show error patterns
echo ""
echo "🔍 Most common error patterns:"
grep "error:" build-errors.log | sed 's/.*error: /error: /' | cut -d' ' -f2- | sort | uniq -c | sort -nr | head -5

# Categorize errors
echo ""
echo "📋 Error Categories:"

# Protocol conformance errors
PROTOCOL_ERRORS=$(grep -c "does not conform to protocol" build-errors.log || echo "0")
if [ $PROTOCOL_ERRORS -gt 0 ]; then
    echo "   🔧 Protocol Conformance: $PROTOCOL_ERRORS errors"
    echo "      💡 Common fix: Add missing protocol methods or implement Codable"
fi

# Missing member errors
MISSING_MEMBER_ERRORS=$(grep -c "has no member" build-errors.log || echo "0")
if [ $MISSING_MEMBER_ERRORS -gt 0 ]; then
    echo "   ❌ Missing Members: $MISSING_MEMBER_ERRORS errors"
    echo "      💡 Common fix: Add missing properties or check imports"
fi

# Ambiguous type errors
AMBIGUOUS_ERRORS=$(grep -c "is ambiguous" build-errors.log || echo "0")
if [ $AMBIGUOUS_ERRORS -gt 0 ]; then
    echo "   ❓ Ambiguous Types: $AMBIGUOUS_ERRORS errors"
    echo "      💡 Common fix: Rename conflicting types or use full names"
fi

# iOS version errors
VERSION_ERRORS=$(grep -c "only available in iOS" build-errors.log || echo "0")
if [ $VERSION_ERRORS -gt 0 ]; then
    echo "   📱 iOS Version: $VERSION_ERRORS errors"
    echo "      💡 Common fix: Use iOS-compatible alternatives"
fi

# Extra arguments errors
ARGUMENT_ERRORS=$(grep -c "Extra arguments" build-errors.log || echo "0")
if [ $ARGUMENT_ERRORS -gt 0 ]; then
    echo "   📝 Extra Arguments: $ARGUMENT_ERRORS errors"
    echo "      💡 Common fix: Check function signatures and parameter counts"
fi

# Missing arguments errors
MISSING_ARG_ERRORS=$(grep -c "Missing argument" build-errors.log || echo "0")
if [ $MISSING_ARG_ERRORS -gt 0 ]; then
    echo "   ⚠️  Missing Arguments: $MISSING_ARG_ERRORS errors"
    echo "      💡 Common fix: Add required parameters to function calls"
fi

echo ""
echo "🎯 Recommended Next Steps:"

# Suggest specific fixes based on error types
if [ $PROTOCOL_ERRORS -gt 0 ]; then
    echo "   1️⃣  Fix protocol conformance issues first"
    echo "      📖 Check .windsurf/workflows/debug-build-issues.md for examples"
fi

if [ $MISSING_MEMBER_ERRORS -gt 0 ]; then
    echo "   2️⃣  Add missing properties or members"
    echo "      🔍 Look for 'has no member' errors in build-errors.log"
fi

if [ $AMBIGUOUS_ERRORS -gt 0 ]; then
    echo "   3️⃣  Resolve type ambiguities"
    echo "      🏷️  Rename duplicate struct/class definitions"
fi

echo ""
echo "🛠️  Quick Commands for Debugging:"
echo "   📄 View all errors:     cat build-errors.log | grep error:"
echo "   📂 View file errors:    grep 'error: YourFile.swift' build-errors.log"
echo "   🔍 Search specific:     grep 'does not conform' build-errors.log"
echo "   📊 Count by type:       grep 'error:' build-errors.log | cut -d' ' -f4- | sort | uniq -c"

echo ""
echo "💡 Pro Tips:"
echo "   • Fix one error type at a time"
echo "   • Test build after each fix"
echo "   • Use the workflow guide for detailed examples"
echo "   • Clear caches if errors persist: rm -rf ~/Library/Developer/Xcode/DerivedData/*"

echo ""
echo "📚 Resources:"
echo "   📖 Workflow Guide: .windsurf/workflows/debug-build-issues.md"
echo "   🔧 Error Log: build-errors.log"
echo "   📊 Progress Log: debug-progress.log"

# Update progress log
echo "$(date): Build attempt - $ERROR_COUNT errors, $WARNING_COUNT warnings" >> debug-progress.log

echo ""
echo "🚀 Ready to debug! Start with the highest priority errors first."
echo "💪 You've got this! Let's get that build to green! 🟢"
