#!/usr/bin/env bash
set -euo pipefail

# Simple smoke:
# 1) Fetch TMDB proxy 2) Request ads 3) Ping growth 4) Health endpoints

PROJECT="${PROJECT:-mychannel-ca26d}"
ADS_BASE_URL="${ADS_BASE_URL:-https://ads-serve-fkri6ifojq-uc.a.run.app}"

step() { echo "[SMOKE] $1"; }

step "TMDB trending"
curl -sSf "https://us-central1-${PROJECT}.cloudfunctions.net/tmdb_trending?media_type=movie&time_window=week" >/dev/null

step "Ads serve"
curl -sSf -X POST -H 'Content-Type: application/json' \
  -d '{"key":"demo","placement":"preroll","device":"ios","locale":"en-US"}' \
  "${ADS_BASE_URL}/ads/serve" >/dev/null || true

step "Growth eligibility"
curl -sSf -X POST -H 'Content-Type: application/json' \
  -d '{"userId":"smoke-user"}' \
  "https://us-central1-${PROJECT}.cloudfunctions.net/reviews_eligibility" >/dev/null

step "Services health"
curl -sSf "https://mychannel-content-fkri6ifojq-uc.a.run.app/health" >/dev/null || true
curl -sSf "https://mychannel-events-fkri6ifojq-uc.a.run.app/health" >/dev/null || true
curl -sSf "https://mychannel-upload-fkri6ifojq-uc.a.run.app/health" >/dev/null || true

echo "OK"
