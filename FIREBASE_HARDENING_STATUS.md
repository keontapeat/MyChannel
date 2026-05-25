# Firebase Backend Hardening Status

Date: 2026-04-27
Project: `mychannel-ca26d`

## Deployed

- Storage rules allow current iOS video upload paths:
  - `videos/{uid}/{videoId}/{filename}`
  - `thumbnails/{uid}/{videoId}/{filename}`
- Firestore rules now explicitly support active app paths:
  - `videos/{videoId}/comments/{commentId}`
  - `videos/{videoId}/likes/{userId}`
  - `videos/{videoId}/comments/{commentId}/likes/{userId}`
  - `users/{uid}/subscribers/{subscriberId}`
  - `users/{uid}/watch-history/{...}`
  - `users/{uid}/watch-progress/{...}`
  - `users/{uid}/watch_progress/{...}`
  - `users/{uid}/liked-videos/{...}`
  - `users/{uid}/disliked-videos/{...}`
  - `users/{uid}/watch-later/{...}`
  - `users/{uid}/comment-drafts/{...}`
  - `users/{uid}/blockedUsers/{...}`
  - `live_streams/{streamId}`
  - `liveStreams/{streamId}`
  - `content_reports/{reportId}`
  - `shorts/{shortId}/events/{eventId}`
  - `stories/{storyId}/events/{eventId}`

## Local Code Changes Ready

- `RealtimeViewTracker.swift` now writes view/watch-time events to `video_analytics/{videoId}/views/{viewId}` instead of directly incrementing `videos/{videoId}` counters.
- `DownloadSyncService.swift` now syncs offline likes through `videos/{videoId}/likes/{uid}` instead of direct `likeCount` increments.
- `DownloadSyncService.swift` now syncs subscriptions through `users/{channelId}/subscribers/{uid}` instead of direct subscriber count increments.
- `EnhancedSubscriptionService.swift` now writes/deletes `users/{channelId}/subscribers/{uid}` instead of direct subscriber count increments.
- `ShortsFirestoreService.swift` now writes `shorts/{shortId}/events/{eventId}` instead of directly incrementing shorts counters.
- `functions/main.py` contains local Firestore triggers for:
  - `on_video_view_created`
  - `on_short_event_created`
  - `on_story_event_created`

## Deployment Blocker

Deploying new Python Gen 2 Functions is blocked by Google Cloud regional CPU quota:

```text
Quota exceeded for total allowable CPU per project per region.
```

The failed function stub `on_video_view_created` was deleted successfully, but recreating it is still blocked by quota.

## Required To Reach Production 100%

1. Increase Cloud Run / Cloud Functions Gen 2 CPU quota in `us-central1`, or consolidate/delete unused Functions/services.
2. Deploy the new Firestore event aggregation Functions.
3. After server aggregation Functions are live, tighten Firestore rules to block direct client counter writes on:
   - `videos/{videoId}.viewCount`
   - `videos/{videoId}.likeCount`
   - `videos/{videoId}.commentCount`
   - `videos/{videoId}.shareCount`
   - `shorts/{shortId}` counters
   - `stories/{storyId}` counters
4. Move analytics/search/feed/payment writes behind callable Functions or Admin SDK services.
5. Canonicalize duplicate collections for watch history, watch later, live streams, reports, and engagement.

## Current Verdict

The Firebase backend is closer to YouTube-parity after rule and app-path hardening, but true 100% server-authoritative parity is blocked until the GCP CPU quota issue is resolved and the new Functions can be deployed.
