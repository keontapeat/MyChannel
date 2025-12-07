#!/bin/bash
# =============================================================================
# 🔍 POST-AI CODING SESSION AUDIT 🔍
# =============================================================================
# Run this AFTER every AI/Cursor coding session to check for damage!
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="/Users/keonta/Documents/MyChannel"
cd "$PROJECT_ROOT"

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🔍 POST-AI CODING SESSION AUDIT 🔍${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ISSUES=0

# =============================================================================
# CHECK 1: File count comparison
# =============================================================================
echo -e "${CYAN}🔍 Check 1: File count comparison...${NC}"

SWIFT_BEFORE=$(cat /tmp/mychannel_swift_count 2>/dev/null || echo "0")
TS_BEFORE=$(cat /tmp/mychannel_ts_count 2>/dev/null || echo "0")
SWIFT_AFTER=$(find MyChannel -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
TS_AFTER=$(find web-v2 -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')

SWIFT_DIFF=$((SWIFT_AFTER - SWIFT_BEFORE))
TS_DIFF=$((TS_AFTER - TS_BEFORE))

if [ "$SWIFT_DIFF" -lt 0 ]; then
    echo -e "${RED}🚨 ALERT: ${SWIFT_DIFF#-} Swift files were DELETED!${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$SWIFT_DIFF" -gt 0 ]; then
    echo -e "${GREEN}✓ +$SWIFT_DIFF Swift files added${NC}"
else
    echo -e "${GREEN}✓ Swift file count unchanged ($SWIFT_AFTER files)${NC}"
fi

if [ "$TS_DIFF" -lt 0 ]; then
    echo -e "${RED}🚨 ALERT: ${TS_DIFF#-} TypeScript files were DELETED!${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$TS_DIFF" -gt 0 ]; then
    echo -e "${GREEN}✓ +$TS_DIFF TypeScript files added${NC}"
else
    echo -e "${GREEN}✓ TypeScript file count unchanged ($TS_AFTER files)${NC}"
fi

# =============================================================================
# CHECK 2: Git deleted files
# =============================================================================
echo ""
echo -e "${CYAN}🔍 Check 2: Checking for deleted files in git...${NC}"

DELETED=$(git diff --name-only --diff-filter=D 2>/dev/null)
STAGED_DELETED=$(git diff --cached --name-only --diff-filter=D 2>/dev/null)

if [ -n "$DELETED" ] || [ -n "$STAGED_DELETED" ]; then
    echo -e "${RED}🚨 DELETED FILES DETECTED:${NC}"
    [ -n "$DELETED" ] && echo "$DELETED" | while read f; do echo -e "  ${RED}✗ $f${NC}"; done
    [ -n "$STAGED_DELETED" ] && echo "$STAGED_DELETED" | while read f; do echo -e "  ${RED}✗ $f (staged)${NC}"; done
    ISSUES=$((ISSUES + 1))
    echo ""
    echo -e "${YELLOW}To recover:${NC} git restore <filename>"
else
    echo -e "${GREEN}✓ No files deleted${NC}"
fi

# =============================================================================
# CHECK 3: Critical files exist
# =============================================================================
echo ""
echo -e "${CYAN}🔍 Check 3: Verifying critical files...${NC}"

CRITICAL_FILES=(
    "MyChannel/App/MyChannelApp.swift"
    "MyChannel/Core/Config/AppConfig.swift"
    "MyChannel/Core/Theme/AppTheme.swift"
    "MyChannel.xcodeproj/project.pbxproj"
    "web-v2/package.json"
    "firebase.json"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗ MISSING: $file${NC}"
        ISSUES=$((ISSUES + 1))
    fi
done

# =============================================================================
# CHECK 4: Project builds
# =============================================================================
echo ""
echo -e "${CYAN}🔍 Check 4: Quick build check (syntax only)...${NC}"

# Check for Swift syntax errors (quick check)
SWIFT_ERRORS=$(find MyChannel -name "*.swift" -exec grep -l "<<<<<<" {} \; 2>/dev/null | head -3)
if [ -n "$SWIFT_ERRORS" ]; then
    echo -e "${RED}🚨 Merge conflict markers found in:${NC}"
    echo "$SWIFT_ERRORS"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ No merge conflicts detected${NC}"
fi

# =============================================================================
# CHECK 5: Large changes
# =============================================================================
echo ""
echo -e "${CYAN}🔍 Check 5: Checking change size...${NC}"

LINES_CHANGED=$(git diff --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | head -2)
FILES_CHANGED=$(git diff --stat 2>/dev/null | grep -c '|' || echo "0")

echo -e "  ${BLUE}Files changed:${NC} $FILES_CHANGED"
echo -e "  ${BLUE}Changes:${NC} $LINES_CHANGED"

if [ "$FILES_CHANGED" -gt 50 ]; then
    echo -e "${YELLOW}⚠️  Large number of files changed. Review carefully!${NC}"
fi

# =============================================================================
# FINAL REPORT
# =============================================================================
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✅ ALL CHECKS PASSED! Your project is safe.${NC}"
else
    echo -e "${RED}🚨 $ISSUES ISSUE(S) DETECTED!${NC}"
    echo ""
    echo -e "${YELLOW}Recovery options:${NC}"
    echo -e "  ${CYAN}git restore <file>${NC}        - Restore specific file"
    echo -e "  ${CYAN}git checkout HEAD -- .${NC}   - Restore all files"
    echo -e "  ${CYAN}./scripts/recover-deleted.sh${NC} - Full recovery tool"
fi

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""








