# MyChannel Auto-Fix Scripts

These scripts help you catch and fix errors automatically before they become big problems.

## Setup Instructions

### 1. Install Required Tools

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install SwiftLint (for automatic code fixes)
brew install swiftlint

# Install fswatch (for file monitoring)
brew install fswatch
```

### 2. Make Scripts Executable

```bash
cd /Users/keonta/Documents/MyChannel/Scripts
chmod +x auto-fix.sh pre-build.sh post-build.sh
```

### 3. Run Auto-Fix Agent

Open a terminal and run:

```bash
cd /Users/keonta/Documents/MyChannel
./Scripts/auto-fix.sh
```

Keep this terminal open while you work. It will automatically:
- Watch for file changes
- Run SwiftLint auto-fixes
- Check for common errors
- Log everything to `auto-fix.log`

### 4. Add Pre-Build Script to Xcode (Optional but Recommended)

1. Open MyChannel.xcodeproj in Xcode
2. Select the MyChannel target
3. Go to "Build Phases"
4. Click "+" and select "New Run Script Phase"
5. Drag it to the top (before "Compile Sources")
6. Name it "Pre-Build Check"
7. Add this script:

```bash
bash "${PROJECT_DIR}/Scripts/pre-build.sh"
```

8. Uncheck "Based on dependency analysis"

### 5. Add Post-Build Script to Xcode (Optional)

1. Same steps as above, but:
2. Name it "Post-Build Check"
3. Drag it to the bottom (after all other phases)
4. Add this script:

```bash
bash "${PROJECT_DIR}/Scripts/post-build.sh"
```

## Usage

### Quick Commands

```bash
# Start the auto-fix agent (recommended while coding)
./Scripts/auto-fix.sh

# Manually run SwiftLint fixes
cd /Users/keonta/Documents/MyChannel
swiftlint --fix

# Clear DerivedData when things go wrong
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*

# Check for duplicate types
find MyChannel -name "*.swift" -exec grep -h "^struct\|^class\|^enum" {} \; | awk '{print $2}' | sort | uniq -d
```

## What Gets Fixed Automatically

- **Code Formatting**: Trailing whitespace, indentation, etc.
- **Unused Imports**: Removes unnecessary imports
- **Common Patterns**: Redundant nil coalescing, explicit init, etc.
- **Build Cache**: Auto-clears DerivedData after failed builds

## Troubleshooting

### "Command not found: swiftlint"
```bash
brew install swiftlint
```

### "Command not found: fswatch"
```bash
brew install fswatch
```

### Build still failing?
1. Stop the auto-fix agent (Ctrl+C)
2. Clean build folder in Xcode (Cmd+Shift+K)
3. Clear DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*`
4. Restart Xcode
5. Start the auto-fix agent again

## Tips

- **Keep the auto-fix terminal open** while you code
- **Let it run for 1-2 seconds** after saving files (it batches changes)
- **Check auto-fix.log** if you want to see what was fixed
- **SwiftLint can't fix everything** - some errors need manual fixes

## What This DOESN'T Do

This setup catches formatting and simple issues, but it **cannot** automatically fix:
- Type ambiguity (duplicate struct names)
- Missing properties or methods
- Complex SwiftUI compiler timeouts
- Logic errors

For those, you'll still need to fix them manually or ask me for help!

## Making It Persistent

To run the auto-fix agent every time you open your project:

1. Add this to your `~/.zshrc` or `~/.bash_profile`:

```bash
alias mychannel-dev='cd /Users/keonta/Documents/MyChannel && ./Scripts/auto-fix.sh'
```

2. Then just run `mychannel-dev` in any terminal to start coding with auto-fixes enabled!


