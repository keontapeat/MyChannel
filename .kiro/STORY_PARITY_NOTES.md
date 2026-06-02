# Instagram Stories Parity — Working Notes

Firebase project: **mychannel-ca26d** (logged in as keontapeat@mychannel.live)

## Live backend (verified via firebase CLI)

### Firestore collections (story-related)
- `stories/{storyId}` — main story doc. read: public, write: signed-in.
  - Written by `StoryService.saveStory` (rich: stickers/polls/links/music/content) AND `DatabaseService.saveStory` (slim + audience).
  - Read by `DatabaseService.storyFromFirestoreDoc` (currently DROPS stickers/polls/links/music — only parses scalar fields).
  - Subcollections (rules added + deployed):
    - `likes/{userId}` — StoryActionService
    - `polls/{pollId}` + `polls/{pollId}/votes/{userId}` — StoryInteractionService
    - `quizzes/{quizId}` + `/answers/{userId}`
    - `questions/{questionId}` + `/responses/{responseId}`
    - `sliders/{sliderId}` + `/results/{userId}`
    - `countdowns/{countdownId}` + `/reminders/{userId}`
- `story-collections/{creatorId}` — latest story pointer per creator.
- `story_views/{storyId}` — { viewCount, viewers[], lastViewedAt }. StoryViewTracker.
- `story_replies/{replyId}` — { storyId, creatorId, senderId, text } flat. StoryActionService.
- `story_shares/{shareId}` — flat.
- `story_seen/{userId_storyId}` — StorySeenTracker.
- `story_highlights` — TWO layouts supported in rules now:
  - nested `story_highlights/{userId}/{highlightId}`
  - flat `story_highlights/{highlightId}` w/ creatorId field (StoryHighlightsService uses flat)
- `story_reports/{reportId}` — abuse reports.
- `story_analytics/{userId}/**` — creator only.
- `users/{uid}/liked_stories/{storyId}` — private.
- `users/{uid}/viewed_stories/{storyId}` — private.
- `notifications/{notificationId}` — FLAT, queried by userId field (NotificationsInboxService + StoryActionService). Rule ADDED.
- `notifications/{uid}/items/{itemId}` — NESTED, written by Cloud Function notifyFollowersOnStoryCreated. Rule ADDED.

### Storage
- `stories/{userId}/{file}` — read public, write signed-in. OK for `stories/{uid}/{uuid}.jpg|mp4`.

### Cloud Functions (firebase/functions/src/index.ts, codebase "story-functions", nodejs20)
- `deleteExpiredStories` — hourly, deletes expired stories + media + story_views.
- `cleanupOrphanedMedia` — daily.
- `notifyFollowersOnStoryCreated` — onCreate stories/{id} → notifications/{follower}/items.
- Plus securityGuard / agentProxy etc. (unrelated).

## Rules status
- Updated root `firestore.rules` (the deployed one per firebase.json) + DEPLOYED successfully.
- Pre-existing harmless warnings: Unused function getUser, get/request name warnings.

## Client architecture (from prior investigation)
- LIVE creator: UltimateStoryCreatorView + UltimateStoryViewModel (+ ProCameraEngine).
- LIVE viewer: AssetStoriesPagerView (grouped by user). Tray: AssetBouncyStoriesRow in HomeView.
- Compositor added: StoryCompositor.swift (bakes overlays into image/video).
- Text composer added: StoryTextComposer.swift.
- Interaction service added: StoryInteractionService.swift.

## TODO for parity
- [ ] Render interactive stickers in viewer (poll/quiz/question/slider/countdown/link/mention/location).
- [ ] Creator UI to ADD interactive stickers (currently only text + emoji stickers).
- [ ] storyFromFirestoreDoc must parse stickers/polls/links/music so viewer can render them.
- [ ] "Seen by" sheet with viewer avatars (owner only).
- [ ] Upload progress + CANCEL in creator.
- [ ] Verify build after each phase.

## Build
- Scheme: MyChannel. Sim: iPhone 17. Deployment target iOS 17.
- Use derivedDataPath OUTSIDE ./build-verify to avoid DB lock with stale builds. Use /tmp/story-build.
- Project uses PBXFileSystemSynchronizedRootGroup → new files auto-included, no pbxproj edits needed.

## ⚠️ MULTIPLE AIs EDITING CONCURRENTLY
- User has OTHER AIs editing other tabs/features at the same time.
- Full `xcodebuild` keeps failing on THEIR in-progress files, NOT mine:
  - SmartPlaylistsView.swift (Int.abbreviated) — I added Int+Abbreviated.swift to fix.
  - NuclearFlicksViewModel.swift (loadLegacyShortsFlicks not in scope) — THEIRS, do not touch.
  - ProVideoEditor / MultiClipEngine VideoFilter clash — I renamed Stories' struct to ClipVideoFilter.
- DO NOT edit Flicks/Shorts/Playlists files — other AIs own them. Avoid collisions.
- VERIFY my work via getDiagnostics on the specific Stories files, NOT full builds.
- As of last check: ALL my Stories files report ZERO diagnostics. ✅

## Files I created/own (all clean)
- Features/Stories/StoryCompositor.swift (WYSIWYG bake)
- Features/Stories/StoryTextComposer.swift
- Features/Stories/InteractiveStickerPicker.swift
- Features/Stories/InteractiveStickerBadge.swift
- Features/Home/Stories/StoryViewerInteractives.swift
- Core/Services/StoryInteractionService.swift
- Core/Extensions/Int+Abbreviated.swift
- Modified: UltimateStoryViewModel, UltimateStoryCreatorView, ProCameraEngine,
  EditableElementView, EditingToolsBar, AssetStoriesPagerView, DatabaseService,
  SharedModels (StoryError.uploadCancelled), MultiClipEngine (VideoFilter→ClipVideoFilter).
