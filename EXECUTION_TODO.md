# Execution TODO (live)

## Infra (Terraform)
- [x] Pub/Sub: add topic `media-ingest`
- [x] Buckets: `ingest`, `public` with IAM/CORS
- [x] BigQuery: tables `plays`, `impressions`, `likes`
- [ ] Cloud Run services: upload, transcode, content, events, search, moderation, creator
- [ ] API Gateway routes & JWT verification
- [ ] Monitoring alerts (5xx, latency, error budget)

## Services (Cloud Run)
- [ ] Upload: POST /v1/uploads/signed-url
- [ ] Transcode: sub to `media-ingest`, create job, write HLS/sprites/VTT
- [ ] Content: CRUD videos/channels, feed endpoints
- [ ] Events: POST /v1/events → Pub/Sub → BigQuery
- [ ] Search: indexer + GET /v1/search
- [ ] Ranking: GET /v1/feed/personalized (stub)
- [ ] Moderation: POST /v1/moderate/video + reviewer endpoints
- [ ] Creator: uploads/drafts/analytics

## Web (PWA)
- [ ] Signed upload flow (replace direct Storage writes)
- [ ] Send events (impression/play/complete)
- [ ] Search UI wired to Search service; typeahead
- [ ] Studio v1 (uploads/drafts/analytics)
- [ ] Modularize features/services code

## iOS
- [ ] Events SDK (impression/play/complete)
- [ ] Signed upload & progress
- [ ] Creator uploads/drafts

## Data/AI
- [ ] Whisper transcription → index transcripts
- [ ] Rank v1 (recency + personalized boosts)
- [ ] Moderation ML (thumbnail/title safety)

## Compliance/TS
- [ ] Reports, rate limits, audit logs
- [ ] Accessibility & perf pass


