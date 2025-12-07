#!/bin/bash
# =============================================================================
# 🐕 MYCHANNEL FILE WATCHDOG - REAL-TIME PROTECTION 🐕
# =============================================================================
# Monitors for file deletions in real-time and alerts you
# Run in background: ./file-watchdog.sh &
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

PROJECT_ROOT="/Users/keonta/Documents/MyChannel"
LOG_FILE="$PROJECT_ROOT/logs/watchdog.log"

mkdir -p "$PROJECT_ROOT/logs"

echo -e "${MAGENTA}🐕 FILE WATCHDOG ACTIVE${NC}"
echo -e "${GREEN}Monitoring: $PROJECT_ROOT${NC}"
echo "Watchdog started at $(date)" >> "$LOG_FILE"

# Monitor critical directories using fswatch (if installed) or poll
if command -v fswatch &> /dev/null; then
    fswatch -r --event Removed "$PROJECT_ROOT/MyChannel" "$PROJECT_ROOT/web-v2" 2>/dev/null | while read file; do
        echo -e "${RED}🚨 FILE DELETED: $file${NC}"
        echo "$(date): DELETED - $file" >> "$LOG_FILE"
        
        # macOS notification
        osascript -e "display notification \"$file\" with title \"🚨 File Deleted!\" sound name \"Basso\"" 2>/dev/null || true
    done
else
    echo -e "${YELLOW}⚠️  Install fswatch for real-time monitoring: brew install fswatch${NC}"
    echo -e "${YELLOW}⚠️  Using polling mode (checks every 30 seconds)${NC}"
    
    # Create initial snapshot
    SNAPSHOT_FILE="/tmp/mychannel_files.txt"
    find "$PROJECT_ROOT/MyChannel" "$PROJECT_ROOT/web-v2" -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | sort > "$SNAPSHOT_FILE"
    
    while true; do
        sleep 30
        NEW_SNAPSHOT="/tmp/mychannel_files_new.txt"
        find "$PROJECT_ROOT/MyChannel" "$PROJECT_ROOT/web-v2" -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | sort > "$NEW_SNAPSHOT"
        
        # Find deleted files
        DELETED=$(comm -23 "$SNAPSHOT_FILE" "$NEW_SNAPSHOT")
        if [ -n "$DELETED" ]; then
            echo -e "${RED}🚨 FILES DELETED:${NC}"
            echo "$DELETED" | while read file; do
                echo -e "  ${RED}$file${NC}"
                echo "$(date): DELETED - $file" >> "$LOG_FILE"
            done
            osascript -e "display notification \"Files were deleted!\" with title \"🚨 MyChannel Watchdog\" sound name \"Basso\"" 2>/dev/null || true
        fi
        
        mv "$NEW_SNAPSHOT" "$SNAPSHOT_FILE"
    done
fi








