# Phase 94 — ML Platform v2

**Status:** ⬜ pending · **Owner:** ML · **Depends on:** Phase 49 (BigQuery pipeline)

## Goal
Promote the 244-agent Cloud Run fleet from artisanal scripts to a proper ML platform with:
- shared feature store
- online + offline training parity
- canary rollouts with auto-rollback
- data & concept drift detection

## Stack
- **Feature store:** Vertex AI Feature Store (online + offline)
- **Training:** Vertex AI Pipelines (Kubeflow)
- **Registry:** Vertex AI Model Registry
- **Serving:** Cloud Run + optional GPU autopilot; sticky canary routing via the existing `gateway`
- **Monitoring:** Vertex Model Monitoring + custom BigQuery dashboards

## Feature naming
`<domain>.<entity>.<feature>__<agg>`
Examples:
- `video.uniq_viewers_7d__sum`
- `user.avg_watch_seconds_30d__mean`
- `creator.upload_cadence_days__p50`

## Canary policy
| Stage | Traffic % | Duration | Auto-rollback trigger |
|-------|-----------|----------|------------------------|
| Shadow | 0% (compare only) | 2h | >2% prediction delta vs prod |
| Canary | 1% | 24h | Error rate >1%, P95 latency +50ms |
| Gradual | 10% → 50% | 48h | User-visible metric regression (CTR, watch-time) |
| Full | 100% | — | — |

## Drift detection
- PSI > 0.2 on any top-20 feature → alert
- Prediction distribution KL-divergence > 0.1 vs baseline → auto-rollback
- Weekly training parity check (online vs offline) must be within 3% accuracy

## Onboarding a new model
1. Register schema in `infra/feature-store/`
2. Training pipeline YAML in `infra/vertex-pipelines/`
3. Cloud Run service with `/predict` and `/health`
4. Canary rollout via `tools/canary-rollout.sh`
5. Dashboard entry in `ops/dashboards/ml-overview.json`
