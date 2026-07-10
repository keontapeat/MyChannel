#!/usr/bin/env bash
#
# lint-no-new-shared — warn when staged Swift files add new `.shared` references.
# Does not block commits; pairs with SwiftLint custom rule + singleton baseline.
#
# Usage:
#   bash scripts/lint-no-new-shared.sh          # scan staged files
#   bash scripts/lint-no-new-shared.sh --all    # full MyChannel tree (informational)
#   bash scripts/lint-no-new-shared.sh --features  # MyChannel/Features only (no new ObservableObject.shared)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---staged}"
TARGETS=()

if [ "$MODE" = "--all" ]; then
  echo "📋 Full .shared scan (see docs/singleton-baseline.md for baseline)"
  exec bash scripts/count-shared-singletons.sh
fi

if [ "$MODE" = "--features" ]; then
  echo "📋 Features/ .shared scan — no new ObservableObject.shared in Features/"
  echo "   Prefer DependencyContainer + @Injected (docs/injected-property-wrapper.md)"
  HITS=$(grep -rn 'ObservableObject.*\.shared\|\.shared' MyChannel/Features --include='*.swift' 2>/dev/null || true)
  if [ -n "$HITS" ]; then
    echo "⚠️  Features/ references .shared (audit before adding new ones):"
    echo "$HITS" | head -40
    echo ""
    echo "Baseline: docs/singleton-baseline.md"
  else
    echo "✓ No .shared references under MyChannel/Features/"
  fi
  exit 0
fi

while IFS= read -r f; do
  [[ "$f" == *.swift ]] && [ -f "$f" ] && TARGETS+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "lint-no-new-shared: no staged Swift files"
  exit 0
fi

HITS=$(grep -n '\.shared' "${TARGETS[@]}" 2>/dev/null || true)

if [ -n "$HITS" ]; then
  echo "⚠️  Staged files reference .shared — prefer DependencyContainer + @Injected:"
  echo "$HITS" | head -30
  echo ""
  echo "Baseline: docs/singleton-baseline.md ($(bash scripts/count-shared-singletons.sh 2>/dev/null | awk '/Total/{print $4}') refs)"
  echo "See docs/injected-property-wrapper.md"
  # Warning only — exit 0 so pre-commit secret scan remains the hard gate
  exit 0
fi

echo "✓ No new .shared references in staged Swift files"
