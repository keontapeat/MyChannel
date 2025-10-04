#!/usr/bin/env bash
set -euo pipefail
RUN_URL="https://health-fkri6ifojq-uc.a.run.app"
TOKEN=$(gcloud auth print-identity-token)
START=$(python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
)
HTTP_CODE=$(curl -sS -H "Authorization: Bearer $TOKEN" -o /tmp/health_body.$$ -w "%{http_code}" "$RUN_URL")
END=$(python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
)
LAT=$((END-START))
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LINE="$TS code=$HTTP_CODE latency_ms=$LAT"
mkdir -p logs
echo "$LINE" | tee -a logs/health.log
rm -f /tmp/health_body.$$
# non-zero exit for alerting
[ "$HTTP_CODE" = "200" ]
