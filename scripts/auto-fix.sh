#!/bin/bash

# Auto-Fix Script for MyChannel
# This script watches for file changes and runs lint checks automatically

PROJECT_DIR="/Users/keonta/Documents/MyChannel"
LOG_FILE="$PROJECT_DIR/auto-fix.log"

echo "🤖 MyChannel Auto-Fix Agent Started" | tee -a "$LOG_FILE"
echo "📅 $(date)" | tee -a "$LOG_FILE"
echo "================================" | tee -a "$LOG_FILE"

# Function to clear DerivedData when needed
clear_derived_data() {
    echo "🧹 Clearing DerivedData..." | tee -a "$LOG_FILE"
    rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-* 2>/dev/null
    echo "✅ DerivedData cleared" | tee -a "$LOG_FILE"
}

# Function to run SwiftLint and auto-fix
run_swiftlint() {
    echo "🔍 Running SwiftLint auto-fix..." | tee -a "$LOG_FILE"
    cd "$PROJECT_DIR"
    
    if command -v swiftlint &> /dev/null; then
        swiftlint --fix --quiet 2>&1 | tee -a "$LOG_FILE"
        echo "✅ SwiftLint auto-fix complete" | tee -a "$LOG_FILE"
    else
        echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint" | tee -a "$LOG_FILE"
    fi
}

# Function to check for common build errors
check_common_errors() {
    echo "🔍 Checking for common errors..." | tee -a "$LOG_FILE"
    
    # Check for duplicate type declarations
    duplicates=$(grep -r "struct\|class\|enum" "$PROJECT_DIR/MyChannel" --include="*.swift" | \
                 awk '{print $2}' | sort | uniq -d | head -5)
    
    if [ ! -z "$duplicates" ]; then
        echo "⚠️  Potential duplicate types found:" | tee -a "$LOG_FILE"
        echo "$duplicates" | tee -a "$LOG_FILE"
    fi
}

# Main monitoring loop
echo "👀 Watching for changes in: $PROJECT_DIR/MyChannel"
echo "Press Ctrl+C to stop"
echo ""

# Initial checks
run_swiftlint
check_common_errors

# Watch for file changes using fswatch (if available)
if command -v fswatch &> /dev/null; then
    echo "✅ fswatch detected - enabling live monitoring"
    
    fswatch -0 -r -e ".*" -i "\\.swift$" "$PROJECT_DIR/MyChannel" | while read -d "" event; do
        echo "📝 File changed: $(basename "$event")" | tee -a "$LOG_FILE"
        
        # Wait a bit to batch changes
        sleep 2
        
        # Run auto-fix
        run_swiftlint
        
        echo "---" | tee -a "$LOG_FILE"
    done
else
    echo "⚠️  fswatch not installed. Install with: brew install fswatch"
    echo "   Without fswatch, this script will only run once."
    echo ""
    echo "💡 Tip: Install fswatch for automatic monitoring:"
    echo "   brew install fswatch"
fi


