# Phase 91 — Chaos Engineering

**Status:** ⬜ pending · **Owner:** SRE · **Cadence:** quarterly game-days

## Goal
Deliberately break MyChannel's dependencies in controlled environments and prove the system degrades gracefully. Turn firefighting into training.

## Failure modes we must survive
| Failure | Mitigation | Success criteria |
|---------|-----------|------------------|
| Cloud Run cold-start storm | Pre-warm top 20 agents with min instances | P95 API < 1.5s during spike |
| Firestore region outage | Reads fall back to BigQuery snapshot cache | Home feed serves within 3s |
| Cloudflare Stream 5xx | Player falls back to GCS origin | Playback resumes within 4s |
| FCM outage | APNs direct push from Functions | Push delivered within 60s |
| Stripe Connect down | Hold payouts in escrow; email creators | Zero data loss |
| Firebase Auth outage | Allow cached sessions up to 24h | Users stay signed in |

## Tooling
- **Gremlin** — infrastructure fault injection
- **Fiddler/Toxiproxy** — network latency + packet loss in staging
- **`gcloud run services update --region=*`** — region failover drill
- **Custom kill-switches** — per-feature Remote Config flags tested under load

## Runbook cadence
- **Weekly:** automated synthetic test of agentProxy → top 20 agents
- **Monthly:** one production-like staging game-day
- **Quarterly:** one limited-blast-radius production fault injection

## Deliverables
- [ ] `infra/chaos/` directory with YAML fault definitions
- [ ] 10 well-documented runbooks under `docs/runbook-*.md`
- [ ] On-call rotation in PagerDuty with 15-min paging SLO
- [ ] Post-mortem template in `.github/POST_MORTEM.md`

## Non-goals
- Production chaos on day 1 — start in staging
- Game-days involving real payments — simulate Stripe only
