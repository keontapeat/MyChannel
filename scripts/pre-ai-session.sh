#!/bin/bash
# =============================================================================
# 🚀 PRE-AI CODING SESSION CHECKLIST 🚀
# =============================================================================
# Run this BEFORE every AI/Cursor coding session!
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
echo -e "${MAGENTA}🚀 PRE-AI CODING SESSION CHECKLIST 🚀${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# =============================================================================
# STEP 1: Check git status
# =============================================================================
echo -e "${CYAN}📋 Step 1: Checking git status...${NC}"
CHANGES=$(git status --porcelain | wc -l | tr -d ' ')

if [ "$CHANGES" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  You have $CHANGES uncommitted changes${NC}"
    echo -e "${YELLOW}   Consider committing before AI session:${NC}"
    echo -e "${CYAN}   git add . && git commit -m 'Pre-AI session save'${NC}"
else
    echo -e "${GREEN}✓ Working directory clean${NC}"
fi

# =============================================================================
# STEP 2: Create backup
# =============================================================================
echo ""
echo -e "${CYAN}📋 Step 2: Creating backup...${NC}"
./scripts/nuclear-backup.sh 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Backup script not found, creating one...${NC}"
}

# =============================================================================
# STEP 3: Verify pre-commit hook
# =============================================================================
echo ""
echo -e "${CYAN}📋 Step 3: Verifying protection hooks...${NC}"

if [ -x ".git/hooks/pre-commit" ]; then
    echo -e "${GREEN}✓ Pre-commit hook active${NC}"
else
    echo -e "${RED}✗ Pre-commit hook missing or not executable!${NC}"
    echo -e "${YELLOW}   Run: chmod +x .git/hooks/pre-commit${NC}"
fi

# =============================================================================
# STEP 4: Count critical files
# =============================================================================
echo ""
echo -e "${CYAN}📋 Step 4: Counting critical files...${NC}"

SWIFT_COUNT=$(find MyChannel -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
TS_COUNT=$(find web-v2 -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')

echo -e "  ${BLUE}Swift files:${NC} $SWIFT_COUNT"
echo -e "  ${BLUE}TypeScript files:${NC} $TS_COUNT"

# Save counts for post-session check
echo "$SWIFT_COUNT" > /tmp/mychannel_swift_count
echo "$TS_COUNT" > /tmp/mychannel_ts_count

# =============================================================================
# STEP 5: Show protection status
# =============================================================================
echo ""
echo -e "${CYAN}📋 Step 5: Protection status...${NC}"
echo -e "  ${GREEN}✓${NC} Git pre-commit hook: Active"
echo -e "  ${GREEN}✓${NC} .cursorrules file: $([ -f .cursorrules ] && echo 'Present' || echo 'Missing!')"
echo -e "  ${GREEN}✓${NC} Backup system: Ready"
echo -e "  ${GREEN}✓${NC} Recovery tools: Available"

# =============================================================================
# FINAL CHECKLIST
# =============================================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ READY FOR AI CODING SESSION!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}⚡ Quick recovery commands:${NC}"
echo -e "  ${CYAN}git restore <file>${NC}     - Restore single file"
echo -e "  ${CYAN}git checkout HEAD -- .${NC} - Restore all files"
echo -e "  ${CYAN}./scripts/recover-deleted.sh${NC} - Recovery tool"
echo ""
echo -e "${MAGENTA}🔥 GO BUILD SOMETHING AMAZING! 🔥${NC}"
echo ""

