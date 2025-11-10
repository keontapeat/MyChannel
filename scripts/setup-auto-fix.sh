#!/bin/bash

echo "🤖 Setting up MyChannel Auto-Fix System..."
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew installed"
fi

# Check for SwiftLint
if ! command -v swiftlint &> /dev/null; then
    echo "📦 Installing SwiftLint..."
    brew install swiftlint
else
    echo "✅ SwiftLint installed"
fi

# Check for fswatch
if ! command -v fswatch &> /dev/null; then
    echo "📦 Installing fswatch..."
    brew install fswatch
else
    echo "✅ fswatch installed"
fi

# Make scripts executable
chmod +x /Users/keonta/Documents/MyChannel/Scripts/*.sh

echo ""
echo "✅ Setup complete!"
echo ""
echo "🚀 Quick Start:"
echo "   1. Run this in a terminal (keep it open while coding):"
echo "      cd /Users/keonta/Documents/MyChannel && ./Scripts/auto-fix.sh"
echo ""
echo "   2. Optional: Add alias to your shell profile:"
echo "      echo 'alias mychannel-dev=\"cd /Users/keonta/Documents/MyChannel && ./Scripts/auto-fix.sh\"' >> ~/.zshrc"
echo ""
echo "📖 Full documentation: Scripts/README.md"


