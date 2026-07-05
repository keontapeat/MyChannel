#!/usr/bin/env bash
# scan-for-secrets — fast regex scan for live-key shapes across the working tree.
# Used as a pre-commit guard and as a sanity check before hosting deploys.
#
# Exits 1 if any matches found. Skips node_modules, build outputs, AppleDouble, and
# documentation files that historically reference test placeholders.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# What to scan: the staged set if we're in a commit, otherwise everything tracked.
TARGETS=()
if [ "${1:-}" = "--staged" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] && TARGETS+=("$f")
  done < <(git diff --cached --name-only --diff-filter=ACMR)
  if [ "${#TARGETS[@]}" -eq 0 ]; then
    echo "scan-for-secrets: no staged files; skipping"
    exit 0
  fi
fi

PATTERNS=(
  'sk_live_[A-Za-z0-9]{20,}'
  'rk_live_[A-Za-z0-9]{20,}'
  'whsec_[A-Za-z0-9]{20,}'
  'AIza[0-9A-Za-z_-]{35}'
  '-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'ghp_[A-Za-z0-9]{36}'
  'gho_[A-Za-z0-9]{36}'
)

EXCLUDE_DIRS='node_modules|\.next|\.derivedData|build-verify|google-cloud-sdk|venv|__pycache__|DerivedData'
EXCLUDE_NAMES='\._|\.lock$|package-lock\.json$|yarn\.lock$|\.DS_Store'

joined_patterns="$(IFS='|'; echo "${PATTERNS[*]}")"

if [ "${#TARGETS[@]}" -gt 0 ]; then
  hits="$(grep -EnH "$joined_patterns" "${TARGETS[@]}" 2>/dev/null \
            | grep -Ev "$EXCLUDE_NAMES" || true)"
else
  hits="$(grep -rEnH \
            --exclude-dir=node_modules \
            --exclude-dir=.next \
            --exclude-dir=.git \
            --exclude-dir=build-verify \
            --exclude-dir=google-cloud-sdk \
            --exclude-dir=venv \
            --exclude-dir=__pycache__ \
            --exclude-dir=DerivedData \
            "$joined_patterns" \
            "$ROOT" 2>/dev/null \
          | grep -Ev "$EXCLUDE_NAMES" || true)"
fi

# Allowlist: known placeholders / tests / docs explicitly using example keys
hits="$(echo "$hits" | grep -Ev 'YOUR_|<your-|example|placeholder|REDACT|REDACTED|xxxx|XXXX|PLACEHOLDER|test_dummy' || true)"

if [ -n "$hits" ]; then
  echo "✗ live-key shapes detected:" >&2
  echo "$hits" >&2
  echo "" >&2
  echo "Move them to env / Secret Manager and commit a placeholder. Aborting." >&2
  exit 1
fi

echo "✓ scan-for-secrets clean"
