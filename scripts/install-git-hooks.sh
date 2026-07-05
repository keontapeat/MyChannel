#!/usr/bin/env bash
# install-git-hooks — wire .githooks/ into this clone's git config.
# Idempotent. Run it once per machine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true
echo "✓ git hooks installed (core.hooksPath=.githooks)"
echo "  pre-commit: scripts/scan-for-secrets.sh --staged"
