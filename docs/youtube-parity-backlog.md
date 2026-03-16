# YouTube Parity Backlog
This backlog breaks down every critical gap blocking full YouTube parity (non-web surfaces) and orders the workstream so we can build continuously with real data.

## 1. Data Authenticity & Mock Removal (Critical)
1. **Kill mock feature gates** (`AppConfig.Features.enableMockData`, `Video.sampleVideos`, `User.sampleUsers`) and force all clients to rely on live Firestore/Cloud Run APIs.
2. **Production Firestore seeding**: create migration scripts that backfill real sample channels/videos/playlists/play history from prod sources; remove `/tools/seed/firestore_seed.json` demo entries once staging/prod seeds exist.
3. **SmartUserSeeder exit ramp**: add telemetry to detect real-user thresholds, automatically purge AI/imported placeholders, and log replacements.
4. **LiveTV ingestion**: hook `LiveTVManager` to a signed Firestore/REST feed; deprecate `sampleChannels` fallback; add validation cron to verify URLs.

## 2. Ingestion, Storage & Transcode Pipeline (Critical)
1. **Uploader service**: verify signed-URL issuance flow (Firebase Function → Cloud Run upload). Add integration tests + metrics for upload failures.
2. **Transcode orchestration**: ensure Pub/Sub → `services/transcode` path runs end-to-end with progress updates to Firestore. Add megaladder configs (SD/HD/4K).
3. **Content moderation pre-ingest**: integrate upload scanning (hashing + AI blocklist) before storage finalization.
4. **Storage policies**: enable coldline lifecycle + DRM-ready buckets; document CDN configs.

## 3. Playback & QoE (Important)
1. **Adaptive bitrate parity**: expose manifest selection, fallback logic, error reporting to Analytics.
2. **Background/PiP**: ensure AVPictureInPicture + Android Exo PIP parity; gate premium-only features via entitlement service.
3. **Offline & downloads**: confirm DRM license storage and expiry (iOS/Android) with telemetry.

## 4. Personalization & Recommendations (Critical)
1. **Watch history services**: persist real events (plays, likes, comments) and power History/Watch Later screens.
2. **Rec-system services**: deploy `services/recommendations` with matrix + real-time signals (topic affinity, engagement). Provide AB testing + fallback playlists.
3. **Topic/interest graph**: maintain user-channel graph, trending surfaces, localized feeds.

## 5. Trust, Safety & Rights (Critical)
1. **Report/strike pipeline**: add Firestore collections + Cloud Run moderation service for abuse reports, escalations, strike policy logic.
2. **Content ID / rights management**: expand `services/rights` to fingerprint uploads, manage ownership metadata, and provide manual dispute flows.
3. **Human review tooling**: Creator Studio + Admin dashboards for appeals, age gating, copyright claims.
4. **Policy automation**: cron jobs to suspend repeat offenders, notify users, and integrate with authentication bans.

## 6. Monetization & Stripe Integration (Critical)
1. **Stripe onboarding**: implement Connected Accounts, payout schedules, tax info capture inside Creator Studio.
2. **Revenue accounting service**: correlate ads impressions, memberships, tips; store ledger entries per creator, expose downloadable statements.
3. **Ads demand**: connect `services/ads` to real DSPs (Ad Manager, FreeWheel) + dynamic VMAP builder, including brand safety filters.
4. **Premium subscriptions & channel memberships**: entitlements service, paywall enforcement on clients.

## 7. Creator Studio & Community (Important)
1. **Analytics dashboards** backed by BigQuery exports (watch time, RPM, CTR, revenue). Replace placeholder metrics with real data.
2. **Live control room**: integrate live stream health, key rotation, latency controls.
3. **Clips/Shorts editors**: finalize asset pipelines, background rendering, server-side thumbnail testing.
4. **Community posts, polls, stories**: ensure moderation + notification parity.

## 8. Growth, Notifications & Integrity (Important)
1. **Notification expansion**: add triggers for likes, comments, live reminders, merch drops; consolidate via notification service with batching + localization.
2. **Referral/quest system**: real-time anti-fraud scoring, reward fulfillment.
3. **Device integrity**: add session risk scoring, 2FA, suspicious login alerts.

## 9. Analytics, Monitoring & Ops (Critical)
1. **Crash/Performance telemetry**: integrate Crashlytics + custom traces; wire MyChannel Doctor to real metrics instead of constants.
2. **Observability stack**: structured logging, error budgets, SLO dashboards, PagerDuty rotations.
3. **Experimentation platform**: remote config or Optimizely-like service to run variants safely.

## 10. Platform Parity (Important)
1. **Android app**: bring feature parity (upload, live, shorts, offline, PiP, monetization) and share modules via Kotlin MultiPlatform where possible.
2. **TV & Connected devices**: expand MyChannelTV to full Leanback experience with voice search and watch history sync.

## Execution Notes
- Only new external dependency to configure is Stripe (per product requirement); all other services must leverage existing Firebase/GCP stack unless unavailable.
- Workstreams can proceed in parallel, but ingestion + trust/safety + monetization must be production-ready before polish efforts.
- Each milestone should include verifiable data (Firestore docs, dashboards, logs) and automated tests so we can prove parity objectively.
