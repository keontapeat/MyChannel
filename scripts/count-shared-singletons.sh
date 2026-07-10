#!/usr/bin/env bash
#
# Count `.shared` singleton usages across the iOS codebase.
# Helps track DI migration progress (goal: resolve via DependencyContainer).
#
# Usage: bash scripts/count-shared-singletons.sh [path]
#
set -euo pipefail

ROOT="${1:-MyChannel}"
if [ ! -d "$ROOT" ]; then
  echo "❌ Directory not found: $ROOT"
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  RG="rg"
elif [ -x "./node_modules/.bin/rg" ]; then
  RG="./node_modules/.bin/rg"
else
  echo "❌ ripgrep (rg) required."
  exit 1
fi

echo "📊 .shared singleton usage in $ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL=$($RG -c '\.shared' --glob '*.swift' "$ROOT" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
FILES=$($RG -l '\.shared' --glob '*.swift' "$ROOT" 2>/dev/null | wc -l | tr -d ' ')

echo "Total .shared references: $TOTAL"
echo "Files with .shared:       $FILES"
echo ""
echo "Top 20 files:"
$RG -c '\.shared' --glob '*.swift' "$ROOT" 2>/dev/null \
  | sort -t: -k2 -nr \
  | head -20 \
  | while IFS=: read -r file count; do
      printf "  %4s  %s\n" "$count" "$file"
    done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
