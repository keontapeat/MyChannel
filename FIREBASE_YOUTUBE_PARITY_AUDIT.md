# Firebase YouTube-Parity Backend Audit

Date: 2026-04-27
Project: `mychannel-ca26d`
Firebase account: `keontapeat@mychannel.live`

## Executive Summary

MyChannel is now substantially Firebase-backed for core YouTube-style behavior: users, videos, uploads, Storage media, comments, likes, subscriptions, playlists, watch history, stories, search metadata, analytics, notifications, reports, and creator monetization scaffolding are present in code and/or rules.

However, it is not yet production-hardening complete at YouTube scale. The biggest gap is not missing feature names; it is backend authority. Many high-trust writes are still allowed directly from signed-in clients instead of being enforced by Cloud Functions/Admin SDK. That means counters, analytics, feeds, moderation status, search indexes, live health, and some monetization-related records can be spoofed by a modified client.

## Confirmed Active Firebase Surface

- Firestore rules deployed from `firestore.rules` via `firebase.json`.
- Storage rules deployed from `storage.rules` via `firebase.json`.
- Firebase Functions are configured with two codebases:
  - `functions` Python codebase.
  - `firebase/functions` Node/TypeScript codebase.
- Firestore indexes are configured in `firestore.indexes.json`.
- iOS Swift code references 374 distinct Firestore collection names.

## Core YouTube Backend Domains

| Domain | Current Status | Notes |
| --- | --- | --- |
| Auth/users/channels | Partial parity | `users`, `user_profiles`, creator profile fields, banners, verification fields exist. Needs canonical channel collection model and stricter protected fields. |
| Video upload/media | Functional | Storage upload path fixed to `videos/{uid}/{videoId}/{filename}` and thumbnails to `thumbnails/{uid}/{videoId}/{filename}`. Needs server-side processing pipeline authority. |
| Video documents | Functional | `videos` includes creator IDs, URLs, metadata, status, visibility, counts. Rules allow broad create and engagement updates. Needs stricter owner validation and server-owned fields. |
| Comments/replies | Functional | App writes under `videos/{videoId}/comments`; Python triggers increment `commentCount`. Top-level `comments` rules also exist. Needs nested comment rules and delete/reply count authority. |
| Likes/dislikes | Functional | App writes `videos/{videoId}/likes/{uid}`; triggers increment `likeCount`. Some offline sync directly increments counts. Needs single authoritative pattern. |
| Subscriptions | Partial parity | Multiple shapes exist: `users/{uid}/subscriptions`, top-level `subscriptions`, and trigger for `users/{creatorId}/subscribers`. Needs canonical dual-write or Cloud Function fanout. |
| Playlists/watch later | Partial parity | Multiple naming variants exist: `watchLater`, `watch_later`, `watch-later`, user playlists. Needs normalized schema and indexes. |
| Watch history/progress | Partial parity | Several variants exist: `watch_history`, `watch-history`, `watchHistory`, `history`, `watch_progress`, `watch-progress`. Needs canonical user-private history model. |
| Search/discovery | Partial parity | Search services and indexes exist, plus `trending_searches`, `search_index`, `search_analytics`. Needs server-maintained search index and ranking pipeline. |
| Recommendations/feed | Partial parity | Cloud Run ML agents exist and feed collections exist. Needs server-owned feed materialization and anti-manipulation. |
| Notifications | Partial parity | `notifications/{uid}/items`, notification settings, story notifications Function. Needs video upload/subscription notification fanout and FCM delivery audit. |
| Stories/shorts/flicks | Functional | Stories cleanup and orphan cleanup exist; `shorts`/`flicks` rules exist. Needs consistent Storage and Firestore lifecycle. |
| Live streaming/live chat | Partial parity | `live`, `live_streams`, `liveStreams`, `live-chat` exist. Needs canonical stream state, server-managed stream keys, chat moderation, and playback session tracking. |
| Analytics | Partial parity | `video_analytics`, `analytics`, `platformMetrics`, `videoViews`, `views` exist. Needs server-owned analytics rollups. |
| Moderation/safety | Partial parity | Reports, security guard, Cloud Run security AI, spam detection in comments. Needs full upload moderation pipeline, appeals, strikes, and admin-only moderation decisions. |
| Copyright/Content ID | Scaffolded | `content_fingerprints`, `content_id_references`, `content_matches`, `dmca_requests`, `counter_notices` exist. Needs actual fingerprint matching pipeline and enforcement. |
| Monetization/ads | Scaffolded/partially gated | Premium, earnings, tips, ads collections exist. App Store-sensitive external payments are gated. Needs server-authoritative IAP receipt validation, revenue ledger, and payout controls. |
| Admin/config/ops | Partial parity | Feature flags, service configs, health checks, backups, emergency stops exist. Some health collections are public writable and should be locked down. |

## Critical Gaps To Fix Before Calling It 100% Backend Parity

1. Client-writable high-trust data

Collections/rules currently allow signed-in clients to write data that should be server-only, including analytics, search indexes, feeds, platform metrics, live TV health, video views, ad clicks, payments, and broad engagement counters.

Recommended fix: move these writes to callable/HTTP Cloud Functions and restrict Firestore rules to owner-only or admin-only.

2. Counter spoofing risk

`videos/{videoId}` allows engagement-only counter updates by any signed-in user. Offline sync also directly increments `likeCount`. YouTube-style backends should never trust client counter increments.

Recommended fix: clients write immutable event docs (`views`, `likes`, `comments`); Cloud Functions aggregate counts using Admin SDK.

3. Schema drift from multiple collection names

The app uses multiple names for the same concepts:

- Watch later: `watchLater`, `watch_later`, `watch-later`
- Watch history: `watch_history`, `watch-history`, `watchHistory`, `history`
- Live: `live`, `live_streams`, `liveStreams`
- Reports: `reports`, `content_reports`
- Likes: top-level `likes`, nested `videos/{videoId}/likes`, user liked collections

Recommended fix: choose canonical collections and add migration/compatibility adapters.

4. Firestore rules do not cover all active app paths precisely

Some active collection names are not explicitly covered or are covered by overly broad wildcard rules. This can cause either permission failures or over-permissive writes.

Recommended fix: generate a collection usage manifest and add precise rules for each canonical path.

5. Search index is not server-authoritative

`search_index`, `search_popularity`, and `trending_searches` are client-writable. Search index documents should be generated from video/user writes by Functions.

Recommended fix: `onVideoWrite`, `onUserWrite`, and `onSearchEvent` Functions maintain indexes and popularity.

6. Upload pipeline lacks full server authority

Client uploads video and thumbnail directly, then creates/updates video metadata. That works, but YouTube parity requires processing states: uploaded, scanning, transcoding, thumbnailing, content checks, published/rejected.

Recommended fix: Storage finalize trigger creates processing job, runs moderation/transcoding/thumbnailing, then marks video `published` only after checks.

7. Moderation and copyright are not fully enforced

Collections exist for reports, Content ID, disputes, DMCA, ratings, and security, but enforcement is incomplete unless Functions/agents write final decisions and rules block unsafe client updates.

Recommended fix: add server-only moderation result writes and gate video visibility/status changes through Functions.

8. Monetization must stay server-authoritative

Client-side writes to revenue/payment-like collections are dangerous and App Store sensitive. IAP products exist, but backend should verify App Store Server receipts/notifications before granting Plus or revenue status.

Recommended fix: Cloud Function receipt validation + immutable ledger + admin-only payouts.

## Recommended Canonical Firestore Schema

### Public/content

- `videos/{videoId}`
- `videos/{videoId}/comments/{commentId}`
- `videos/{videoId}/comments/{commentId}/likes/{uid}`
- `videos/{videoId}/likes/{uid}`
- `videos/{videoId}/views/{viewId}` or top-level sharded `videoViews/{viewId}`
- `shorts/{shortId}`
- `stories/{storyId}`
- `playlists/{playlistId}`
- `playlists/{playlistId}/items/{videoId}`
- `community_posts/{postId}`
- `community_posts/{postId}/likes/{uid}`

### Users/channels

- `users/{uid}`
- `users/{uid}/subscriptions/{creatorId}`
- `users/{uid}/subscribers/{subscriberId}` if reverse lookup is needed
- `users/{uid}/watch_history/{videoId}`
- `users/{uid}/watch_later/{videoId}`
- `users/{uid}/liked_videos/{videoId}`
- `users/{uid}/playlists/{playlistId}`
- `users/{uid}/notifications/{notificationId}`
- `users/{uid}/settings/{settingDoc}`

### Server-owned/indexes

- `search_index/{docId}`
- `search_events/{eventId}`
- `feed_items/{uid}/items/{itemId}`
- `trending/{bucket}/items/{itemId}`
- `video_analytics/{videoId}/daily/{yyyyMMdd}`
- `creator_analytics/{uid}/daily/{yyyyMMdd}`
- `moderation_results/{contentId}`
- `content_matches/{matchId}`
- `payments/{paymentId}`
- `ledger/{ledgerEntryId}`

## Priority Fix Plan

### P0: Security and permission correctness

- Lock down client writes to payments, analytics rollups, platform metrics, search indexes, feeds, health checks, and counters.
- Add precise nested rules for `videos/{videoId}/comments`, `videos/{videoId}/likes`, and user-private collections.
- Remove public write access from operational collections like `health_check`, `doctor_reports`, and `dr_drill_results`.

### P1: Canonical schema cleanup

- Choose canonical names for watch history, watch later, live streams, reports, likes, and playlists.
- Add compatibility reads temporarily.
- Migrate old documents into canonical paths.

### P2: Server-side video pipeline

- Add Storage finalize trigger for `videos/{uid}/{videoId}/video.mp4`.
- Create/update `videos/{videoId}` with `processingStatus`.
- Run moderation, metadata extraction, thumbnailing/transcoding, and publish only after success.

### P3: YouTube-parity backend services

- Subscription notification fanout.
- Server-maintained search index.
- Server-maintained trending/feed materialization.
- Creator analytics rollups.
- Copyright/Content ID enforcement.
- IAP receipt validation and revenue ledger.

## Current Verdict

MyChannel has broad YouTube-like Firebase coverage and many core features are present. It is not yet accurate to call the Firebase backend 100% YouTube-parity production hardened because too much trusted state is still client-writable and several domains have duplicate schemas.

The next best move is to harden rules and Functions around the canonical schema, then migrate duplicate collection names into one source of truth.
