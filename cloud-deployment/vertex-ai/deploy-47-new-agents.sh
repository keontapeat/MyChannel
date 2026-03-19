#!/bin/bash
# ============================================================
# DEPLOY ALL 47 NEW ML AGENTS TO CLOUD RUN
# Project: mychannel-ca26d | Region: us-central1
# ============================================================

set -e

PROJECT_ID="mychannel-ca26d"
REGION="us-central1"
REGISTRY="gcr.io/${PROJECT_ID}"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }

DEPLOYED=0
FAILED=0
FAILED_SERVICES=()

deploy_service() {
  local SERVICE_DIR="$1"
  local SERVICE_NAME=$(basename "$SERVICE_DIR")

  if [ ! -f "$SERVICE_DIR/main.py" ]; then
    warn "Skipping $SERVICE_NAME - no main.py"
    return
  fi

  log "Deploying $SERVICE_NAME..."

  # Copy optimized base Dockerfile if no Dockerfile exists
  if [ ! -f "$SERVICE_DIR/Dockerfile" ]; then
    cp "$BASE_DIR/optimized-base.Dockerfile" "$SERVICE_DIR/Dockerfile"
  fi

  # Build and push image
  IMAGE_TAG="${REGISTRY}/${SERVICE_NAME}:latest"

  if gcloud builds submit "$SERVICE_DIR" \
    --tag "$IMAGE_TAG" \
    --project "$PROJECT_ID" \
    --quiet 2>/dev/null; then

    # Deploy to Cloud Run
    if gcloud run deploy "$SERVICE_NAME" \
      --image "$IMAGE_TAG" \
      --platform managed \
      --region "$REGION" \
      --project "$PROJECT_ID" \
      --allow-unauthenticated \
      --min-instances 1 \
      --max-instances 10 \
      --memory 512Mi \
      --cpu 1 \
      --concurrency 80 \
      --cpu-boost \
      --execution-environment gen2 \
      --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
      --quiet 2>/dev/null; then

      DEPLOYED=$((DEPLOYED + 1))
      log "  ✅ $SERVICE_NAME deployed → https://${SERVICE_NAME}-fkri6ifojq-uc.a.run.app"
    else
      FAILED=$((FAILED + 1))
      FAILED_SERVICES+=("$SERVICE_NAME")
      fail "  ✗ $SERVICE_NAME deploy failed"
    fi
  else
    FAILED=$((FAILED + 1))
    FAILED_SERVICES+=("$SERVICE_NAME")
    fail "  ✗ $SERVICE_NAME build failed"
  fi
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MYCHANNEL - DEPLOYING 47 NEW ML AGENTS 🚀            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── VIDEO INTELLIGENCE (10 agents) ──────────────────────────
echo -e "\n${YELLOW}━━ VIDEO INTELLIGENCE AGENTS ━━${NC}"
deploy_service "$BASE_DIR/scene-detection-service"
deploy_service "$BASE_DIR/auto-chapters-service"
deploy_service "$BASE_DIR/speech-to-text-service"
deploy_service "$BASE_DIR/video-summary-service"
deploy_service "$BASE_DIR/highlight-reel-service"
deploy_service "$BASE_DIR/hook-analyzer-service"
deploy_service "$BASE_DIR/audio-quality-service"
deploy_service "$BASE_DIR/pacing-optimizer-service"
deploy_service "$BASE_DIR/face-blur-service"

# ── USER INTELLIGENCE (7 agents) ────────────────────────────
echo -e "\n${YELLOW}━━ USER INTELLIGENCE AGENTS ━━${NC}"
deploy_service "$BASE_DIR/mood-detection-service"
deploy_service "$BASE_DIR/session-intent-service"
deploy_service "$BASE_DIR/binge-watch-predictor-service"
deploy_service "$BASE_DIR/content-fatigue-service"
deploy_service "$BASE_DIR/sleep-mode-service"
deploy_service "$BASE_DIR/discovery-mode-service"
deploy_service "$BASE_DIR/second-screen-service"

# ── COMMUNITY INTELLIGENCE (7 agents) ───────────────────────
echo -e "\n${YELLOW}━━ COMMUNITY INTELLIGENCE AGENTS ━━${NC}"
deploy_service "$BASE_DIR/debate-detector-service"
deploy_service "$BASE_DIR/toxic-pattern-service"
deploy_service "$BASE_DIR/community-health-service"
deploy_service "$BASE_DIR/creator-fan-matcher-service"
deploy_service "$BASE_DIR/poll-optimizer-service"
deploy_service "$BASE_DIR/gifting-optimizer-service"

# ── BUSINESS INTELLIGENCE (7 agents) ────────────────────────
echo -e "\n${YELLOW}━━ BUSINESS INTELLIGENCE AGENTS ━━${NC}"
deploy_service "$BASE_DIR/unit-economics-service"
deploy_service "$BASE_DIR/platform-health-service"
deploy_service "$BASE_DIR/market-sizing-service"
deploy_service "$BASE_DIR/creator-economy-service"
deploy_service "$BASE_DIR/investor-narrative-service"

# ── GLOBAL EXPANSION (5 agents) ─────────────────────────────
echo -e "\n${YELLOW}━━ GLOBAL EXPANSION AGENTS ━━${NC}"
deploy_service "$BASE_DIR/cultural-sensitivity-service"
deploy_service "$BASE_DIR/local-trending-service"
deploy_service "$BASE_DIR/currency-optimizer-service"
deploy_service "$BASE_DIR/regional-compliance-service"
deploy_service "$BASE_DIR/dialect-detection-service"

# ── ADVANCED SECURITY (5 agents) ────────────────────────────
echo -e "\n${YELLOW}━━ ADVANCED SECURITY AGENTS ━━${NC}"
deploy_service "$BASE_DIR/account-takeover-service"
deploy_service "$BASE_DIR/synthetic-media-detection-service"
deploy_service "$BASE_DIR/phishing-detector-service"
deploy_service "$BASE_DIR/data-exfiltration-service"

# ── MUSIC & AUDIO (5 agents) ────────────────────────────────
echo -e "\n${YELLOW}━━ MUSIC & AUDIO AGENTS ━━${NC}"
deploy_service "$BASE_DIR/music-mood-service"
deploy_service "$BASE_DIR/beat-sync-service"
deploy_service "$BASE_DIR/music-licensing-service"
deploy_service "$BASE_DIR/audio-fingerprint-service"
deploy_service "$BASE_DIR/voice-clone-detector-service"

# ── iOS / APP SPECIFIC (4 agents) ───────────────────────────
echo -e "\n${YELLOW}━━ iOS / APP AGENTS ━━${NC}"
deploy_service "$BASE_DIR/app-crash-predictor-service"
deploy_service "$BASE_DIR/battery-optimizer-service"
deploy_service "$BASE_DIR/offline-content-service"
deploy_service "$BASE_DIR/accessibility-ai-service"

# ── SUMMARY ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                   DEPLOYMENT SUMMARY                    ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  ✅ Successfully deployed: %-30s ║\n" "$DEPLOYED agents"
printf "║  ✗  Failed:               %-30s ║\n" "$FAILED agents"
echo "╚══════════════════════════════════════════════════════════╝"

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
  echo ""
  warn "Failed services:"
  for svc in "${FAILED_SERVICES[@]}"; do
    echo "  - $svc"
  done
fi

echo ""
log "All deployed agents available at:"
log "https://<service-name>-fkri6ifojq-uc.a.run.app"
echo ""
echo "Total MyChannel ML agents: 190+ existing + $DEPLOYED new = $((190 + DEPLOYED)) TOTAL 🔥"
