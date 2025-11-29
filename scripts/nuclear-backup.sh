#!/bin/bash
# =============================================================================
# 🔥💣 MYCHANNEL NUCLEAR BACKUP SYSTEM 💣🔥
# =============================================================================
# Creates timestamped backups of ALL critical project files
# Run this before any major AI coding session!
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="/Users/keonta/Documents/MyChannel"
BACKUP_ROOT="/Users/keonta/Documents/MyChannel-Backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🔥💣 MYCHANNEL NUCLEAR BACKUP SYSTEM 💣🔥${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}📁 Backup location: $BACKUP_DIR${NC}"
echo ""

# =============================================================================
# BACKUP CRITICAL DIRECTORIES
# =============================================================================
echo -e "${CYAN}🛡️ Backing up critical directories...${NC}"

CRITICAL_DIRS=(
    "MyChannel"
    "MyChannel.xcodeproj"
    "web-v2"
    "services"
    "cloud-functions"
    "firebase"
    "functions"
    ".github"
    "scripts"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $dir"
        cp -R "$PROJECT_ROOT/$dir" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

# =============================================================================
# BACKUP CRITICAL FILES
# =============================================================================
echo ""
echo -e "${CYAN}📄 Backing up critical files...${NC}"

CRITICAL_FILES=(
    "firebase.json"
    "firestore.rules"
    ".swiftlint.yml"
    "package.json"
    ".cursorrules"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
        cp "$PROJECT_ROOT/$file" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

# =============================================================================
# CREATE FILE MANIFEST
# =============================================================================
echo ""
echo -e "${CYAN}📋 Creating file manifest...${NC}"

MANIFEST="$BACKUP_DIR/MANIFEST.txt"
echo "MyChannel Backup Manifest" > "$MANIFEST"
echo "=========================" >> "$MANIFEST"
echo "Created: $(date)" >> "$MANIFEST"
echo "Project: $PROJECT_ROOT" >> "$MANIFEST"
echo "" >> "$MANIFEST"
echo "Swift Files: $(find "$PROJECT_ROOT/MyChannel" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')" >> "$MANIFEST"
echo "TypeScript Files: $(find "$PROJECT_ROOT/web-v2" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')" >> "$MANIFEST"
echo "" >> "$MANIFEST"
echo "File List:" >> "$MANIFEST"
echo "----------" >> "$MANIFEST"
find "$BACKUP_DIR" -type f -name "*.swift" -o -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -100 >> "$MANIFEST"

# =============================================================================
# CREATE QUICK RESTORE SCRIPT
# =============================================================================
RESTORE_SCRIPT="$BACKUP_DIR/RESTORE.sh"
cat > "$RESTORE_SCRIPT" << 'RESTORE_EOF'
#!/bin/bash
# Quick restore script - USE WITH CAUTION!
BACKUP_DIR="$(dirname "$0")"
PROJECT_ROOT="/Users/keonta/Documents/MyChannel"

echo "⚠️  This will restore files from this backup to your project."
echo "⚠️  Current files will be OVERWRITTEN!"
read -p "Are you sure? (type 'yes' to confirm): " confirm

if [ "$confirm" = "yes" ]; then
    echo "Restoring..."
    cp -R "$BACKUP_DIR/MyChannel" "$PROJECT_ROOT/" 2>/dev/null || true
    cp -R "$BACKUP_DIR/web-v2" "$PROJECT_ROOT/" 2>/dev/null || true
    echo "✅ Restore complete!"
else
    echo "❌ Restore cancelled"
fi
RESTORE_EOF
chmod +x "$RESTORE_SCRIPT"

# =============================================================================
# CALCULATE BACKUP SIZE
# =============================================================================
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

# =============================================================================
# CLEANUP OLD BACKUPS (Keep last 10)
# =============================================================================
echo ""
echo -e "${CYAN}🧹 Cleaning old backups (keeping last 10)...${NC}"
cd "$BACKUP_ROOT"
ls -dt backup_* 2>/dev/null | tail -n +11 | xargs rm -rf 2>/dev/null || true

BACKUP_COUNT=$(ls -d backup_* 2>/dev/null | wc -l | tr -d ' ')

# =============================================================================
# FINAL SUMMARY
# =============================================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ NUCLEAR BACKUP COMPLETE!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLUE}📁 Location:${NC} $BACKUP_DIR"
echo -e "  ${BLUE}💾 Size:${NC} $BACKUP_SIZE"
echo -e "  ${BLUE}📊 Total backups:${NC} $BACKUP_COUNT"
echo ""
echo -e "${YELLOW}To restore from this backup:${NC}"
echo -e "  ${CYAN}$RESTORE_SCRIPT${NC}"
echo ""
echo -e "${MAGENTA}🔥 YOUR FILES ARE PROTECTED! GO CODE FEARLESSLY! 🔥${NC}"
echo ""

