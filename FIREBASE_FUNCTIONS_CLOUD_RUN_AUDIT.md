# Firebase Functions + Cloud Run Full Audit

Date: 2026-04-27
Project: `mychannel-ca26d`
Account: `keontapeat@mychannel.live`

## Executive Verdict

MyChannel has a very large backend footprint: Firebase Functions, Firebase Storage/Firestore, and a Cloud Run fleet with hundreds of ML/AI services. The platform has broad YouTube-style feature coverage, but the fleet is over-expanded for the current GCP quota. This is why new server-authoritative Firebase Functions cannot deploy: the project is hitting the `us-central1` total allowable CPU quota.

Do **not** blindly delete functions. The safest path is:

1. Keep production-critical Functions and Cloud Run services.
2. Consolidate duplicate Firebase Functions into fewer event pipelines.
3. Scale down or delete failed/not-ready Cloud Run services first.
4. Request/increase Cloud Run CPU quota only after cleanup.
5. Then deploy server-authoritative event aggregation Functions and lock down counter writes.

## Current Backend Footprint

### Firebase Function Codebases

Configured in `firebase.json`:

- `functions` / `python-functions` / Python 3.12
- `firebase/functions` / `story-functions` / Node.js 20

### Python Functions in `functions/main.py`

#### Keep / critical

- `report_content` — authenticated reporting endpoint.
- `tmdb_popular` — TMDB proxy for movies.
- `tmdb_free_ads` — free/ad-supported movies proxy.
- `tmdb_trending` — TMDB trending proxy.
- `tmdb_details` — TMDB details proxy.
- `recaptcha_verify` — bot protection.
- `events_view` — event tracking endpoint.
- `ads_serve` — ad serving endpoint.
- `referral_create` — referral code creation.
- `reviews_eligibility` — review eligibility endpoint.

#### Keep but consolidate into event pipeline

- `on_comment_created`
- `on_comment_deleted`
- `on_like_created`
- `on_like_deleted`
- `on_subscribe_created`
- `on_subscribe_deleted`
- `on_video_view_created` — local code ready, deploy blocked by CPU quota.
- `on_short_event_created` — local code ready, deploy blocked until quota fixed.
- `on_story_event_created` — local code ready, deploy blocked until quota fixed.

Recommended consolidation: replace these many triggers with one `contentEventAggregator` service/function family or keep as a small trigger group but deploy only after quota is fixed.

#### Review before keeping

- `ai_rank` — currently has fallback heuristic/pass-through behavior if Vertex is not configured. Prefer Cloud Run `search-ranking` / `top-rank-ml` / `recommendations` if those are active.
- `growth_aso_sync`
- `growth_aso_publish`
- `on_upload_created_trigger`
- `on_video_ready`
- `on_tip_received`
- `on_membership_renew`

These may be useful, but they should be validated against active app call sites before increasing their quota footprint.

#### Disabled/dead code

- `send_welcome_email` and `on_email_verified` are inside `if ENABLE_EMAIL_TRIGGERS: false`; they are not deployed from `main.py` while disabled.
- `functions/simple_email.py` is not referenced by `firebase.json`; treat as legacy/dead unless explicitly deployed manually.

## TypeScript Functions in `firebase/functions/src/index.ts`

### Keep / critical

- `securityGuard` — callable AI security gate.
- `agentProxy` — callable Cloud Run proxy for authenticated iOS/web ML calls.
- `deleteExpiredStories` — scheduled story lifecycle cleanup.
- `cleanupOrphanedMedia` — scheduled Storage cleanup.
- `notifyFollowersOnStoryCreated` — story notification fanout.

### Keep but harden

- `securityWebhook` — claims internal protection by checking Bearer header, but should verify ID token audience/issuer, not only header presence.
- `adminScanUser` — should accept owner email or custom claim consistently; current custom-claim-only admin check may not match Firestore `isAdmin()` email logic.

## Cloud Run Fleet Audit

A `gcloud run services list` inventory found approximately:

- `316` Cloud Run services in `us-central1`.
- Many are ready and publicly reachable at `https://<service>-fkri6ifojq-uc.a.run.app`.
- Many are failed/not-ready but still consume config/deployment surface and may contribute to quota pressure.
- Several services request high CPU values such as `1`, `2`, or higher compared with many lightweight agents at `0.1666` or `0.3333`.

### Immediate CPU quota problem

Deploying new Gen 2 Functions failed with:

```text
Quota exceeded for total allowable CPU per project per region.
```

This blocked deploying:

- `on_video_view_created`
- eventually `on_short_event_created`
- eventually `on_story_event_created`

### Highest priority Cloud Run cleanup targets

Start with services that are **not ready** and have no active URL or show `Ready=False`. These are safer cleanup candidates than healthy services.

Examples observed in inventory:

- `accessibility-ai-service` — not ready.
- `account-takeover-service` — not ready.
- `ad-network-ml` — not ready.
- `app-crash-predictor-service` — not ready.
- `audio-fingerprint-service` — not ready.
- `battery-optimizer-service` — not ready.
- `beat-sync-service` — not ready.
- `budget-pacing-predictor` — not ready.
- `churn-predictor` — not ready.
- `competitor-intelligence-predictor` — not ready.
- `contextual-analysis-predictor` — not ready.
- `creative-performance-predictor` — not ready.
- `creator-economy-service` — not ready.
- `creator-fan-matcher-service` — not ready.
- `synthetic-media-detection-service` — not ready.
- `tmdb-details` — not ready.
- `tmdb-free-ads` — not ready.
- `tmdb-popular` — not ready.
- `tmdb-trending` — not ready.
- `unit-economics-service` — not ready.
- `voice-clone-detector-service` — not ready.

Before deletion, verify no app/service calls them by exact service name. If no references exist, delete or redeploy with lower CPU.

### Duplicate/v2 consolidation candidates

Services with both base and v2 variants should be audited and one should become canonical:

- `ai-avatar` / `ai-avatar-v2`
- `ai-gaming` / `ai-gaming-v2`
- `ai-music` / `ai-music-v2`
- `cdn-optimizer` / `cdn-optimizer-v2`
- `metaverse-ai` / `metaverse-ai-v2`
- `translation-ai-v2` versus older translation services
- `voice-ai` / `voice-ai-v2`
- `vr-ar-ai` / `vr-ar-ai-v2`
- `video-editor-ai` / `video-editor-ai-v2`

Recommended policy: mark the v2 endpoint canonical only if iOS/web callers use it; otherwise route calls through `agentProxy` and delete stale duplicate after logs show no traffic.

### High CPU ready services to evaluate

Services requesting `2 CPU` or `1 CPU` should be reviewed first because they block new deployments fastest. Do not delete blindly if they are core ML, but lower max instances / CPU if traffic is low.

High-impact categories:

- Recommendations/ranking
- Trending/feed personalization
- Moderation/security
- Thumbnail/video processing
- Ads prediction
- Watch-time prediction

## Firestore Rules Audit

### Deployed improvements

Deployed Firestore rules now explicitly allow active app paths:

- nested video comments
- nested video likes
- nested comment likes
- user subscribers
- user watch history variants
- user watch progress variants
- liked/disliked video variants
- watch-later variant
- comment drafts
- blocked users
- live stream variants
- content reports
- shorts/stories events

### Still too permissive for 100%

These remain too open for production YouTube-grade authority:

- `video_analytics/{videoId}/{document=**}` allows signed-in writes.
- `analytics/{document=**}` allows signed-in writes.
- `platformMetrics/{document=**}` allows signed-in writes.
- `videoViews/{document=**}` allows signed-in writes.
- `adClicks/{document=**}` allows signed-in writes.
- `payments/{document=**}` allows signed-in writes.
- `search_index/{document=**}` allows signed-in writes.
- `search_popularity/{document=**}` allows signed-in writes.
- `feeds/{document=**}` allows signed-in writes.
- video engagement counters can still be updated directly by signed-in users under limited diff rules.

These should be locked down only **after** server aggregation Functions deploy successfully.

## Storage Rules Audit

Storage rules were fixed and deployed for current upload paths:

- `videos/{userId}/{videoId}/{filename}`
- `thumbnails/{userId}/{videoId}/{filename}`

Remaining watchlist:

- `profile_images` in rules differs from `profile-images` in `AppConfig.Storage.profileImagePath`; keep both if app services use both legacy names.
- `user-banner-videos/{filename}` allows any authenticated write; safer long-term path is `user-banner-videos/{userId}/{filename}` or validate filename prefix.
- Stories Storage allows any authenticated write; acceptable for MVP, but should validate owner path for production.

## Firestore Index Audit

`firestore.indexes.json` is broad and includes many useful YouTube-style indexes:

- videos by user/creator/category/visibility/status/createdAt/trendingScore/viewCount/tags/searchKeywords
- comments by videoId/createdAt
- notifications by userId/read/timestamp
- subscriptions by user/channel/subscribedAt
- playlists by userId/updatedAt
- search analytics/trending searches
- views/videoViews
- moderation/content flags/strike cases

Issue: indexes reflect schema drift. There are indexes for both canonical and legacy fields such as `views` vs `viewCount`, `ownerId` vs `ownerUid` vs `creatorId` vs `userId`.

Recommended: keep current indexes until migration is complete, then prune stale indexes after query logs confirm no usage.

## Backend Service Stub Audit

Several `/services` backends still contain mock/TODO behavior that prevents full YouTube backend parity:

### High priority stubs

- `services/upload/main.ts` — TODO Firebase JWT verification.
- `services/video-understanding/workers/pipeline.py` — skeleton pipeline only.
- `services/video-understanding/indexing/faiss_index.py` — search placeholder returns empty.
- `services/video-understanding/api/routes/videos.py` — placeholder processing response.
- `services/video-understanding/api/routes/moderate.py` — placeholder moderation returns safe.
- `services/video-understanding/api/routes/chapters.py` — placeholder chapters empty.
- `services/ingest/workers/download.ts` — GCS upload mocked without credentials.
- `services/ingest/lib/adapters.ts` — Pixabay/Archive/Wiki adapters return empty.
- `services/pay-api/src/index.js` — mock Stripe mode if secret missing.
- `services/ads/src/routes/advertiser.js` — mock creative upload URL and mock payment fallback.
- `services/ads/src/routes/openrtb.js` — mock OpenRTB bidder/VAST.
- `services/channelboost-api/src/index.js` — positive-signal checks TODO.

### Medium priority

- `services/music/analytics.ts` contains mock demographic data.
- `services/recommendations/main.ts` can return empty candidates if backend data missing.
- `services/search/main.ts`, `services/content/main.ts`, and `services/creator/main.ts` should be reviewed against actual Firestore-backed app paths.

## Keep / Delete / Consolidate Recommendations

### Keep

- Security/securityGuard/agentProxy functions.
- Story cleanup and notifications.
- TMDB proxies, unless replaced by Cloud Run TMDB services.
- Core ML services actually referenced by iOS through `CloudRunAgentRouter`.
- Moderation/security services used in upload/comments.

### Consolidate

- Event counter triggers into one event pipeline.
- Duplicate `*-v2` Cloud Run services after traffic checks.
- TMDB Firebase Functions vs TMDB Cloud Run services: keep one authoritative implementation.
- Search/ranking services: route through one canonical `search-ranking` or `top-rank-ml` service via `agentProxy`.

### Delete or disable first

Only after reference/log checks:

- Failed/not-ready Cloud Run services with no active callers.
- Legacy `simple_email.py` if never deployed.
- Duplicate v1/v2 services with zero traffic.
- Mock-only services not wired to production.

## Required Path To 100%

1. Free Cloud Run CPU capacity:
   - delete failed/not-ready unused services, or
   - reduce CPU/max instances, or
   - request quota increase.
2. Deploy event aggregation Functions:
   - video view aggregator
   - shorts event aggregator
   - story event aggregator
3. Lock down client direct writes to trusted counters and analytics.
4. Canonicalize duplicate Firestore collection names.
5. Replace stubbed services with real implementations or remove them from production routes.
6. Route all high-trust writes through Admin SDK, callable Functions, or authenticated Cloud Run services.
7. Add traffic/log-based deprecation policy for old services.

## Current Status

- Firebase rules and Storage fixes are deployed.
- Event-based iOS local changes are in progress and ready for server aggregation.
- New Functions cannot deploy until CPU quota is resolved.
- 100% YouTube backend parity is blocked by infrastructure quota and remaining mock/stub services, not by missing feature ideas.
