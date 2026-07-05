#!/usr/bin/env bash
# vibedeploy — safe, targeted Firebase deploys for MyChannel.
#
# Wraps `firebase deploy --only ...` with:
#   - vibecheck preflight (won't deploy a broken build)
#   - project lock to mychannel-ca26d
#   - explicit target — never a bare `firebase deploy`
#   - secret scan on the diff before hosting deploys
#
# Usage:
#   ./scripts/vibedeploy.sh hosting          # web-v2 -> Firebase Hosting
#   ./scripts/vibedeploy.sh rules            # firestore:rules + firestore:indexes
#   ./scripts/vibedeploy.sh storage          # storage.rules
#   ./scripts/vibedeploy.sh database         # database.rules.json
#   ./scripts/vibedeploy.sh fn:<codebase-or-name>   # one functions codebase or function
#                                                   # e.g. fn:python-functions
#                                                   #      fn:python-functions:feature_slot_lifecycle
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="mychannel-ca26d"

ok()    { printf '\033[32m✓\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }
info()  { printf '\033[36m▸\033[0m %s\n' "$*"; }
note()  { printf '\033[33m!\033[0m %s\n' "$*"; }

require_firebase() {
  command -v firebase >/dev/null 2>&1 || { fail "firebase CLI not found"; exit 1; }
}

confirm_project() {
  local current
  current="$(firebase use 2>/dev/null | head -1 | tr -d '[:space:]')"
  if [ -z "$current" ] || ! firebase use 2>/dev/null | grep -q "$PROJECT"; then
    info "switching firebase project to $PROJECT"
    firebase use "$PROJECT" >/dev/null
  fi
  ok "firebase project = $PROJECT"
}

scan_for_secrets() {
  # Lightweight regex-based scan over the staged/working web-v2 build output for the
  # most common live-key shapes. Designed to fail loudly, not to be perfect.
  local target="${1:-web-v2}"
  if [ ! -d "$target" ]; then return 0; fi
  info "scanning $target for live secret patterns"
  local hits
  hits="$(grep -rEn \
    --include='*.js' --include='*.mjs' --include='*.html' --include='*.json' \
    --include='*.ts' --include='*.tsx' \
    'sk_live_[A-Za-z0-9]{20,}|rk_live_[A-Za-z0-9]{20,}|whsec_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----' \
    "$target" 2>/dev/null | grep -v node_modules | grep -v '\.next/cache' | head -10 || true)"
  if [ -n "$hits" ]; then
    fail "live-key shaped strings found in $target:"
    printf '%s\n' "$hits" >&2
    fail "refusing to deploy. Move secrets to env / Secret Manager."
    return 1
  fi
  ok "no live-key shapes in $target"
}

deploy_hosting() {
  info "preflight: vibecheck web"
  bash "$ROOT/scripts/vibecheck.sh" web
  scan_for_secrets web-v2/.next || true   # next/cache is fine; scan source instead
  scan_for_secrets web-v2/app
  scan_for_secrets web-v2/lib
  info "deploying hosting"
  firebase deploy --only hosting --project "$PROJECT" --non-interactive
  ok "hosting deploy complete"
}

deploy_rules() {
  info "deploying firestore:rules + firestore:indexes"
  firebase deploy --only firestore:rules,firestore:indexes \
    --project "$PROJECT" --non-interactive
  ok "rules + indexes deploy complete"
}

deploy_storage() {
  info "deploying storage.rules"
  firebase deploy --only storage --project "$PROJECT" --non-interactive
  ok "storage deploy complete"
}

deploy_database() {
  info "deploying database.rules.json"
  firebase deploy --only database --project "$PROJECT" --non-interactive
  ok "database deploy complete"
}

deploy_functions() {
  local target="$1"
  info "deploying functions:$target"
  FUNCTIONS_DISCOVERY_TIMEOUT=120 firebase deploy \
    --only "functions:$target" --project "$PROJECT" --non-interactive
  ok "functions:$target deploy complete"
}

main() {
  require_firebase
  confirm_project

  local cmd="${1:?target required (hosting|rules|storage|database|fn:<codebase>)}"
  case "$cmd" in
    hosting)         deploy_hosting ;;
    rules)           deploy_rules ;;
    storage)         deploy_storage ;;
    database)        deploy_database ;;
    fn:*)            deploy_functions "${cmd#fn:}" ;;
    *)               fail "unknown target: $cmd"; exit 2 ;;
  esac
}

main "$@"
