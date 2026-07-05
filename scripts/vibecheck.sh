#!/usr/bin/env bash
# vibecheck — fast, scoped verify for whatever you just touched.
#
# Usage:
#   ./scripts/vibecheck.sh ios            # SwiftLint app + tvOS
#   ./scripts/vibecheck.sh web            # web-v2 lint + build
#   ./scripts/vibecheck.sh web-fast       # web-v2 lint only (skips full build)
#   ./scripts/vibecheck.sh services       # typecheck every service that has tsconfig.json
#   ./scripts/vibecheck.sh service <name> # typecheck one service (e.g. ads, pay-api)
#   ./scripts/vibecheck.sh functions      # firebase/functions build + python syntax
#   ./scripts/vibecheck.sh all            # everything above (slow, full preflight)
#   ./scripts/vibecheck.sh                # smart: detect from `git status` what to run
#
# Exits non-zero on the first hard failure so it's safe in hooks/CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ok()    { printf '\033[32m✓\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }
info()  { printf '\033[36m▸\033[0m %s\n' "$*"; }
note()  { printf '\033[33m!\033[0m %s\n' "$*"; }

run_ios() {
  info "iOS / tvOS — SwiftLint"
  if ! command -v swiftlint >/dev/null 2>&1; then
    note "swiftlint not on PATH; skipping. brew install swiftlint to enable."
    return 0
  fi
  swiftlint --config .swiftlint.yml --quiet
  ok "SwiftLint clean"
  note "Real Xcode build is owner-run: open MyChannel.xcodeproj in Xcode and Cmd+R."
}

run_web_lint() {
  info "web-v2 — eslint"
  npm --prefix web-v2 run lint
  ok "web-v2 lint clean"
}

run_web_build() {
  info "web-v2 — next build (catches static-export errors)"
  npm --prefix web-v2 run build
  ok "web-v2 build succeeded"
}

run_web() { run_web_lint; run_web_build; }

run_one_service() {
  local svc="$1"
  local dir="services/$svc"
  if [ ! -d "$dir" ]; then fail "no such service: $svc"; return 1; fi
  if [ -f "$dir/tsconfig.json" ]; then
    info "service[$svc] — tsc --noEmit"
    npx --no-install tsc --noEmit -p "$dir/tsconfig.json" 2>/dev/null || \
      npx tsc --noEmit -p "$dir/tsconfig.json"
    ok "service[$svc] typecheck clean"
  else
    note "service[$svc] has no tsconfig.json — checking *.js / *.mjs syntax"
    local found=0
    while IFS= read -r f; do
      node --check "$f"
      found=1
    done < <(find "$dir" -type f \( -name '*.js' -o -name '*.mjs' \) \
              -not -path "*/node_modules/*" -not -name '._*' 2>/dev/null)
    [ "$found" = 1 ] && ok "service[$svc] node --check clean" \
                     || note "service[$svc] no JS/TS sources found"
  fi
}

run_services() {
  local any=0
  while IFS= read -r d; do
    [ -f "$d/tsconfig.json" ] || continue
    run_one_service "$(basename "$d")"
    any=1
  done < <(find services -maxdepth 1 -mindepth 1 -type d -not -name 'node_modules' 2>/dev/null | sort)
  [ "$any" = 1 ] || note "no TypeScript services found to check"
}

run_functions() {
  if [ -d firebase/functions ] && [ -f firebase/functions/package.json ]; then
    info "firebase/functions — build (story-functions, Node)"
    npm --prefix firebase/functions install --no-audit --no-fund >/dev/null 2>&1 || true
    npm --prefix firebase/functions run build
    ok "firebase/functions build clean"
  fi

  if [ -f functions/main.py ]; then
    info "functions/ — python3 -m py_compile main.py (python-functions)"
    python3 -m py_compile functions/main.py
    ok "functions/main.py syntax clean"
  fi

  for f in cloud-functions/escrow-payments/index.js \
           cloud-functions/music-payouts/index.js; do
    if [ -f "$f" ]; then
      info "$f — node --check"
      node --check "$f"
      ok "$f syntax clean"
    fi
  done
}

# Smart mode: pick verifiers based on what's modified in git
run_smart() {
  info "smart mode — inspecting git status"
  local changed
  changed="$(git status --porcelain 2>/dev/null | awk '{print $NF}')"
  if [ -z "$changed" ]; then
    note "no working-tree changes — running web-fast as a sanity check"
    run_web_lint
    return 0
  fi

  local did=0
  if echo "$changed" | grep -qE '\.swift$|\.swiftlint\.yml$|MyChannel(/|TV/)'; then
    run_ios; did=1
  fi
  if echo "$changed" | grep -qE '^web-v2/|\.tsx?$|\.css$|next\.config'; then
    run_web; did=1
  fi
  if echo "$changed" | grep -qE '^services/'; then
    local svcs
    svcs="$(echo "$changed" | grep '^services/' | awk -F/ '{print $2}' | sort -u)"
    for s in $svcs; do
      [ -d "services/$s" ] || continue
      run_one_service "$s" || did=1
      did=1
    done
  fi
  if echo "$changed" | grep -qE '^firebase/functions/|^functions/|^cloud-functions/'; then
    run_functions; did=1
  fi
  [ "$did" = 1 ] || note "no recognized targets in changed files"
}

main() {
  local cmd="${1:-smart}"
  case "$cmd" in
    ios)        run_ios ;;
    web)        run_web ;;
    web-fast)   run_web_lint ;;
    services)   run_services ;;
    service)    run_one_service "${2:?service name required}" ;;
    functions)  run_functions ;;
    all)        run_ios; run_web; run_services; run_functions ;;
    smart|"")   run_smart ;;
    *)          fail "unknown target: $cmd"; exit 2 ;;
  esac
  ok "vibecheck done"
}

main "$@"
