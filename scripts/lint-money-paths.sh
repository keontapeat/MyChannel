#!/usr/bin/env bash
# Fail CI if money-path Swift files introduce new force-unwraps on URL/amount.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATTERNS='URL\(string:[^)]+\)!|\.amount!|amountCents!|platformFee!'
FILES=(
  MyChannel/Core/Services/MoneyEscrowService.swift
  MyChannel/Core/Services/StripeConnectService.swift
  MyChannel/Core/Utils/MoneyMath.swift
  MyChannel/Core/Utils/WagerPolicy.swift
)

fail=0
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then continue; fi
  if grep -nE "$PATTERNS" "$f" 2>/dev/null; then
    echo "❌ Force-unwrap / unsafe URL in $f"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "✓ Money paths: no force-unwrap patterns in scanned files"
