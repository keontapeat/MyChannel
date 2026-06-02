#!/bin/bash
# =============================================================================
# measure_build_times.sh — Generate fresh Swift compile-time data and rank it.
# =============================================================================
#
# A senior-level, repeatable way to find what is making MyChannel slow to
# build. It does a clean build with the Swift frontend timing flags enabled,
# captures the "took NNNms to type-check" warnings, then ranks the worst
# offenders via scripts/rank_slow_compiles.py.
#
# WHY: the iOS app is ~2,600 Swift files. A handful of giant SwiftUI `body`
# getters and type-inference-heavy expressions dominate incremental builds.
# Fix those and everyone's edit-build loop gets faster. This script makes the
# hotspots measurable instead of guessed.
#
# Usage:
#   scripts/measure_build_times.sh                 # full clean build + rank
#   scripts/measure_build_times.sh --no-clean      # incremental (faster, noisier)
#   scripts/measure_build_times.sh --rank-only LOG  # just rank an existing log
#
# Notes:
#   * This runs xcodebuild and can take several minutes. It is intended to be
#     run by a developer in a terminal, NOT inside an agent (builds block).
#   * Output log: build_timing.log (gitignored-friendly; safe to delete).
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="MyChannel.xcodeproj"
SCHEME="MyChannel"
LOG="build_timing.log"
DERIVED="build-timing.noindex"
THRESHOLD_MS=100   # warn on function bodies / expressions slower than this

# --rank-only: skip the build, just parse a provided (or default) log.
if [[ "${1:-}" == "--rank-only" ]]; then
  python3 scripts/rank_slow_compiles.py "${2:-$LOG}"
  exit 0
fi

CLEAN=1
[[ "${1:-}" == "--no-clean" ]] && CLEAN=0

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Run this on a Mac with Xcode installed." >&2
  exit 1
fi

# Pick a simulator destination that exists; fall back to a generic one.
DEST='platform=iOS Simulator,name=iPhone 15 Pro'
if ! xcrun simctl list devices available 2>/dev/null | grep -q "iPhone 15 Pro"; then
  DEST='generic/platform=iOS Simulator'
fi

echo "==> Measuring Swift compile times (threshold ${THRESHOLD_MS}ms)"
echo "    project=$PROJECT scheme=$SCHEME clean=$CLEAN dest=$DEST"

TIMING_FLAGS="-Xfrontend -warn-long-function-bodies=${THRESHOLD_MS} -Xfrontend -warn-long-expression-type-checking=${THRESHOLD_MS}"

if [[ $CLEAN -eq 1 ]]; then
  echo "==> Clean build (most accurate, slower)"
  rm -rf "$DERIVED"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -configuration Debug \
    OTHER_SWIFT_FLAGS="\$(inherited) $TIMING_FLAGS" \
    clean build 2>&1 | tee "$LOG" || true
else
  echo "==> Incremental build (faster, only re-typechecks changed files)"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -configuration Debug \
    OTHER_SWIFT_FLAGS="\$(inherited) $TIMING_FLAGS" \
    build 2>&1 | tee "$LOG" || true
fi

echo ""
echo "==> Ranking slowest sites from $LOG"
python3 scripts/rank_slow_compiles.py "$LOG"

echo ""
echo "Done. Re-run with --rank-only $LOG to re-print the ranking without rebuilding."
