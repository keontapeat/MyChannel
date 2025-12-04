#!/bin/bash
# =============================================================================
# 🔄 MYCHANNEL FILE RECOVERY TOOL 🔄
# =============================================================================
# Recovers accidentally deleted files from git or backups
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="/Users/keonta/Documents/MyChannel"
BACKUP_ROOT="/Users/keonta/Documents/MyChannel-Backups"

cd "$PROJECT_ROOT"

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🔄 MYCHANNEL FILE RECOVERY TOOL 🔄${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# =============================================================================
# OPTION 1: Show recently deleted files (from git)
# =============================================================================
echo -e "${CYAN}📋 OPTION 1: Recently deleted files (in git staging)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

STAGED_DELETED=$(git diff --cached --name-only --diff-filter=D 2>/dev/null)
UNSTAGED_DELETED=$(git diff --name-only --diff-filter=D 2>/dev/null)

if [ -n "$STAGED_DELETED" ]; then
    echo -e "${YELLOW}Staged for deletion:${NC}"
    echo "$STAGED_DELETED" | while read file; do
        echo -e "  ${RED}✗${NC} $file"
    done
    echo ""
    echo -e "${GREEN}To recover staged deletions:${NC}"
    echo -e "  ${CYAN}git restore --staged <filename>${NC}"
    echo -e "  ${CYAN}git restore <filename>${NC}"
else
    echo -e "${GREEN}✓ No staged deletions${NC}"
fi

if [ -n "$UNSTAGED_DELETED" ]; then
    echo ""
    echo -e "${YELLOW}Unstaged deletions:${NC}"
    echo "$UNSTAGED_DELETED" | while read file; do
        echo -e "  ${RED}✗${NC} $file"
    done
    echo ""
    echo -e "${GREEN}To recover unstaged deletions:${NC}"
    echo -e "  ${CYAN}git restore <filename>${NC}"
else
    echo -e "${GREEN}✓ No unstaged deletions${NC}"
fi

# =============================================================================
# OPTION 2: Recover from last commit
# =============================================================================
echo ""
echo -e "${CYAN}📋 OPTION 2: Recover file from last commit${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Command:${NC} git checkout HEAD -- <filepath>"
echo -e "${GREEN}Example:${NC} git checkout HEAD -- MyChannel/Core/Config/AppConfig.swift"

# =============================================================================
# OPTION 3: Recover from specific commit
# =============================================================================
echo ""
echo -e "${CYAN}📋 OPTION 3: Recover from specific commit${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Recent commits:${NC}"
git log --oneline -10
echo ""
echo -e "${GREEN}Command:${NC} git checkout <commit-hash> -- <filepath>"
echo -e "${GREEN}Example:${NC} git checkout f754267 -- MyChannel/Features/Video/VideoPlayerView.swift"

# =============================================================================
# OPTION 4: Find when file was deleted
# =============================================================================
echo ""
echo -e "${CYAN}📋 OPTION 4: Find when a file was deleted${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Command:${NC} git log --all --full-history -- <filepath>"
echo -e "${GREEN}Example:${NC} git log --all --full-history -- MyChannel/Features/Video/VideoPlayerView.swift"

# =============================================================================
# OPTION 5: Recover from backup
# =============================================================================
echo ""
echo -e "${CYAN}📋 OPTION 5: Recover from backup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -d "$BACKUP_ROOT" ]; then
    echo -e "${YELLOW}Available backups:${NC}"
    ls -lt "$BACKUP_ROOT" 2>/dev/null | head -10
    echo ""
    echo -e "${GREEN}To restore from backup:${NC}"
    echo -e "  ${CYAN}cp $BACKUP_ROOT/<backup_name>/<filepath> $PROJECT_ROOT/<filepath>${NC}"
else
    echo -e "${YELLOW}No backups found. Run ./scripts/nuclear-backup.sh first!${NC}"
fi

# =============================================================================
# OPTION 6: Recover ALL deleted files from current branch
# =============================================================================
echo ""
echo -e "${CYAN}📋 OPTION 6: Recover ALL deleted files${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Command to restore all deletions:${NC}"
echo -e "  ${CYAN}git checkout HEAD -- .${NC}"
echo -e "${YELLOW}⚠️  Warning: This will restore ALL files to last commit state!${NC}"

# =============================================================================
# QUICK RECOVERY COMMANDS
# =============================================================================
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🚀 QUICK RECOVERY COMMANDS${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Restore single file:${NC}       git restore <filepath>"
echo -e "${GREEN}Restore staged file:${NC}      git restore --staged <filepath>"
echo -e "${GREEN}Restore from commit:${NC}      git checkout <commit> -- <filepath>"
echo -e "${GREEN}Restore all changes:${NC}      git checkout HEAD -- ."
echo -e "${GREEN}Find deleted file:${NC}        git log --all --full-history -- <filepath>"
echo -e "${GREEN}See what's deleted:${NC}       git diff --name-only --diff-filter=D"
echo ""




