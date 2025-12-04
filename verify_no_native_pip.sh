#!/bin/bash

# 🔒 Verification Script: Ensure Native iOS PiP is Completely Removed
# Run this before ANY commit that touches video player code

echo "🔍 Verifying Native iOS PiP is completely removed..."
echo ""

FAIL_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: AVPictureInPictureController (MUST be 0)
echo "📋 Check 1: AVPictureInPictureController references..."
RESULT=$(grep -r "AVPictureInPictureController" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: No AVPictureInPictureController references found"
else
    echo -e "${RED}❌ FAIL${NC}: Found $RESULT AVPictureInPictureController references"
    grep -r "AVPictureInPictureController" MyChannel/ --include="*.swift" 2>/dev/null
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 2: handlePiPStateChange (MUST be 0)
echo "📋 Check 2: handlePiPStateChange references..."
RESULT=$(grep -r "handlePiPStateChange" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: No handlePiPStateChange references found"
else
    echo -e "${RED}❌ FAIL${NC}: Found $RESULT handlePiPStateChange references"
    grep -r "handlePiPStateChange" MyChannel/ --include="*.swift" 2>/dev/null
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 3: togglePictureInPicture (MUST be 0)
echo "📋 Check 3: togglePictureInPicture references..."
RESULT=$(grep -r "togglePictureInPicture" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: No togglePictureInPicture references found"
else
    echo -e "${RED}❌ FAIL${NC}: Found $RESULT togglePictureInPicture references"
    grep -r "togglePictureInPicture" MyChannel/ --include="*.swift" 2>/dev/null
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 4: isPiPActive (MUST be 0)
echo "📋 Check 4: isPiPActive references..."
RESULT=$(grep -r "isPiPActive" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: No isPiPActive references found"
else
    echo -e "${RED}❌ FAIL${NC}: Found $RESULT isPiPActive references"
    grep -r "isPiPActive" MyChannel/ --include="*.swift" 2>/dev/null
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 5: PlayerPiPContainerView (MUST be 0 - file should be deleted)
echo "📋 Check 5: PlayerPiPContainerView file..."
if [ ! -f "MyChannel/Core/Components/PlayerPiPContainerView.swift" ]; then
    echo -e "${GREEN}✅ PASS${NC}: PlayerPiPContainerView.swift is deleted"
else
    echo -e "${RED}❌ FAIL${NC}: PlayerPiPContainerView.swift still exists"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 6: pipController/pipPlayerLayer (MUST be 0)
echo "📋 Check 6: pipController/pipPlayerLayer references..."
RESULT=$(grep -r "pipController\|pipPlayerLayer" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: No pipController/pipPlayerLayer references found"
else
    echo -e "${RED}❌ FAIL${NC}: Found $RESULT pipController/pipPlayerLayer references"
    grep -r "pipController\|pipPlayerLayer" MyChannel/ --include="*.swift" 2>/dev/null
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 7: FloatingMiniPlayer exists (MUST have > 0)
echo "📋 Check 7: FloatingMiniPlayer references (REQUIRED)..."
RESULT=$(grep -r "FloatingMiniPlayer" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: Found $RESULT FloatingMiniPlayer references (custom mini player exists)"
else
    echo -e "${RED}❌ FAIL${NC}: No FloatingMiniPlayer references found (custom mini player missing!)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Check 8: minimizePlayer() exists (MUST have > 0)
echo "📋 Check 8: minimizePlayer() references (REQUIRED)..."
RESULT=$(grep -r "minimizePlayer()" MyChannel/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RESULT" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: Found $RESULT minimizePlayer() references"
else
    echo -e "${RED}❌ FAIL${NC}: No minimizePlayer() references found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo ""

# Final result
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL CHECKS PASSED${NC}"
    echo "✅ Native iOS PiP is completely removed"
    echo "✅ Only custom YouTube-style mini player will show"
    echo "✅ Ready to commit/deploy"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo -e "${RED}❌ $FAIL_COUNT CHECK(S) FAILED${NC}"
    echo "🚨 CRITICAL: Native PiP code detected!"
    echo "🚫 DO NOT COMMIT until all checks pass"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi










