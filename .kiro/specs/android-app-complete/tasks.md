# Implementation Plan: MyChannel Android App

## Overview

Build the complete MyChannel Android app in 17 sequential/parallel tasks, progressing from foundation through data layer, auth, screens, and polish. Each task produces compilable, testable code. Tasks are ordered to respect dependencies — foundation first, then data layer, then screens that depend on both.

## Tasks

- [x] 1. Foundation — Application, Theme & DI Setup
  - Create `MyChannelApp.kt` with `@HiltAndroidApp` annotation and Firebase initialization
  - Create `ui/theme/Color.kt` with brand colors (BrandRed `#E85D5D`, dark/light backgrounds, surface colors)
  - Create `ui/theme/Typography.kt` with Material Design 3 type scale
  - Create `ui/theme/Shape.kt` with standardized corner radii
  - Create `ui/theme/Theme.kt` with `MyChannelTheme` composable supporting light/dark/system modes
  - Create `di/FirebaseModule.kt` providing `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`, `FirebaseDatabase`, `FirebaseMessaging`
  - Create `di/DatabaseModule.kt` providing `AppDatabase` (Room) and all DAOs
  - Create `di/NetworkModule.kt` providing `OkHttpClient` with auth interceptor and certificate pinning, and `Retrofit`
  - Create `di/RepositoryModule.kt` binding all repository interfaces to implementations
  - Create `di/AppModule.kt` providing `DataStore<Preferences>` and `WorkManager`
  - Update `AndroidManifest.xml` with `android:name=".MyChannelApp"`, internet permission, deep link intent filters (`mychannel://`), and splash screen theme
  - Create `res/values/strings.xml`, `res/values/colors.xml`, and `res/drawable/` vector icons for bottom nav (ic_home, ic_flicks, ic_upload, ic_subscriptions, ic_library, ic_search, ic_profile)
  - **Acceptance:** App compiles and launches with MyChannel brand theme applied

- [x] 2. Data Layer — Models, Room, and Repository Interfaces
  - Create `domain/model/` data classes: `User`, `Video`, `Channel`, `LiveStream`, `Comment`, `Playlist`, `Notification`, `VSMatch`, `Story`
  - Create `data/local/entity/` Room entities: `VideoEntity`, `ChannelEntity`, `SearchHistoryEntity`, `PlaylistEntity`, `NotificationEntity`
  - Create `data/local/dao/` DAOs: `VideoDao`, `ChannelDao`, `SearchHistoryDao`, `PlaylistDao`, `NotificationDao` with Flow-returning queries
  - Create `data/local/AppDatabase.kt` with all entities and DAOs, version 1
  - Create `domain/repository/` interfaces: `AuthRepository`, `VideoRepository`, `ChannelRepository`, `SearchRepository`, `VSMatchRepository`, `NotificationRepository`
  - Create `data/remote/` Firebase data sources: `FirebaseAuthDataSource`, `FirestoreVideoDataSource`, `FirestoreChannelDataSource`, `FirestoreVSMatchDataSource`
  - Create `data/repository/` implementations: `AuthRepositoryImpl`, `VideoRepositoryImpl`, `ChannelRepositoryImpl`, `SearchRepositoryImpl`, `VSMatchRepositoryImpl`, `NotificationRepositoryImpl`
  - All repository implementations MUST use `callbackFlow` for real-time Firestore listeners and `withContext(Dispatchers.IO)` for one-shot reads/writes
  - **Acceptance:** Room database compiles; repository interfaces and implementations compile with Hilt bindings
  - **Depends on:** 1

- [x] 3. Authentication Flow
  - Create `AuthViewModel.kt` with `StateFlow<AuthUiState>` covering loading, authenticated, unauthenticated, and error states; methods: `signInWithEmail`, `signInWithGoogle`, `signInAnonymously`, `register`, `resetPassword`, `signOut`
  - Create `ui/screens/auth/LoginScreen.kt` with email/password fields, Google Sign-In button, "Forgot Password" link, and "Create Account" navigation
  - Create `ui/screens/auth/RegisterScreen.kt` with email, password, confirm password fields and validation
  - Create `ui/screens/auth/ProfileSetupScreen.kt` for first-time users: username input, avatar picker, bio field
  - Update `MyChannelNavigation.kt` to route to `LoginScreen` when unauthenticated and `HomeScreen` when authenticated; observe `AuthViewModel` at the nav root
  - Implement Google Sign-In using `CredentialManager` API with fallback to `GoogleSignInClient`
  - Store Firebase ID token in `EncryptedSharedPreferences` backed by Android Keystore
  - Handle auth state persistence: `FirebaseAuth.currentUser` check on app start
  - **Acceptance:** User can sign in with email/password and Google, session persists across restarts, unauthenticated users are redirected to login
  - **Depends on:** 1, 2

- [x] 4. Home Screen — Full Implementation
  - Create `HomeViewModel.kt` with `HomeUiState` (trendingVideos, recommendedVideos, liveStreams, stories, selectedFilter, isLoading, error); implement `loadFeed()`, `selectFilter()`, `retry()`; use Paging 3 `Pager` for the main feed
  - Create `ui/components/FilterChips.kt` — horizontal scrollable `LazyRow` of `FilterChip` composables (All, Live, Shorts, Music, Movies, Gaming, News)
  - Create `ui/components/StoriesRow.kt` — horizontal `LazyRow` of circular avatar cards with a pulsing red ring for live creators
  - Create `ui/components/VideoCard.kt` — card with thumbnail (16:9 `AsyncImage`), duration badge, title (2 lines max), channel avatar + name, view count + upload date, overflow menu
  - Create `ui/components/LiveBadge.kt` — red "LIVE" pill badge composable
  - Create `ui/components/SkeletonLoader.kt` — shimmer effect composable for loading placeholders
  - Update `HomeScreen.kt` to use `LazyColumn` with: StoriesRow, FilterChips, trending section, Live Now section, Recommended section; implement pull-to-refresh; show `SkeletonLoader` on first load
  - **Acceptance:** Home screen displays real data from Firestore with skeleton loading, filter chips work, pull-to-refresh works
  - **Depends on:** 2, 3

- [ ] 5. Video Player Screen
  - Create `VideoPlayerViewModel.kt` owning an `ExoPlayer` instance; manage `VideoPlayerUiState`; implement `loadVideo(videoId)`, `togglePlayPause()`, `seekTo()`, `setQuality()`, `setSpeed()`, `toggleLike()`, `toggleSave()`, `postComment()`, `loadComments()`; release player in `onCleared()`
  - Create `ui/screens/video/VideoPlayerScreen.kt` with: full-width `AndroidView` wrapping `PlayerView`, custom overlay controls (play/pause, seek bar, time, quality, speed, fullscreen, PiP, cast), video metadata section, like/dislike/share/save action row, expandable description, comments `LazyColumn` with nested replies, related videos list
  - Implement quality selection and playback speed `ModalBottomSheet` dialogs
  - Implement fullscreen mode toggling system UI visibility and landscape orientation
  - Implement PiP: override `onUserLeaveHint` in `MainActivity` to call `enterPictureInPictureMode()` when video is playing
  - Create `services/MediaPlaybackService.kt` extending `MediaSessionService` for background audio with notification controls
  - Update `AndroidManifest.xml` with PiP support and `MediaPlaybackService` declaration
  - Add `VideoPlayer` route to `MyChannelNavigation.kt` with `videoId` argument
  - **Acceptance:** Videos play with HLS, controls work, PiP works, background audio works, comments load
  - **Depends on:** 2, 4

- [ ] 6. Floating Mini Player
  - Create `MiniPlayerState.kt` data class and `LocalMiniPlayer` `CompositionLocalProvider` at the nav root
  - Update `FloatingMiniPlayer.kt` to use Media3 `ExoPlayer` (fix legacy ExoPlayer2 imports), add proper swipe-to-dismiss with `Animatable` offset, add tap-to-expand navigation back to `VideoPlayerScreen`
  - Integrate `FloatingMiniPlayer` into the main `Scaffold` above the `NavigationBar` — show only when `MiniPlayerState.isVisible`
  - Wire `VideoPlayerViewModel` to update `MiniPlayerState` when the user navigates away from the player screen
  - Ensure the same `ExoPlayer` instance is shared between `VideoPlayerScreen` and `FloatingMiniPlayer` via `MiniPlayerState`
  - **Acceptance:** Mini player appears when navigating away from a playing video, tap expands back to player, swipe dismisses
  - **Depends on:** 5

- [ ] 7. Flicks (Shorts) Screen
  - Create `FlicksViewModel.kt` with a `Pager` backed by a Firestore `PagingSource` querying `isShort == true`; manage current index, like state, follow state
  - Create `ui/screens/flicks/FlicksScreen.kt` using `VerticalPager` for full-screen swipe navigation; each page hosts an `ExoPlayer` instance that auto-plays when active and pauses when not; overlay: creator avatar + username + follow button, like/comment/share buttons, caption text, audio attribution row
  - Implement like action updating Firestore atomically
  - Implement share via Android `ShareCompat`
  - Implement comment bottom sheet reusing the comments component from `VideoPlayerScreen`
  - Manage ExoPlayer lifecycle: create player for current ± 1 pages, release others
  - **Acceptance:** Flicks feed loads, videos auto-play on swipe, like/share/comment work
  - **Depends on:** 4, 5

- [ ] 8. Search Screen
  - Create `SearchViewModel.kt` with `SearchUiState`; implement `search(query)` with 300ms debounce using `Flow.debounce`; implement `saveToHistory()`, `clearHistory()`, `loadTrending()`
  - Create `ui/screens/search/SearchScreen.kt` with: `SearchBar` composable at top, history list (with delete per item + clear all), trending searches section, results `LazyColumn` with filter tabs (All, Videos, Channels, Playlists, Live) using `TabRow`
  - Create `ui/components/ChannelCard.kt` — channel avatar, name, subscriber count, subscribe button
  - Implement voice search using `SpeechRecognizer` with microphone permission request via Accompanist Permissions
  - Persist search history in Room `SearchHistoryDao`
  - **Acceptance:** Search returns results, history persists, voice search works, filter tabs filter results
  - **Depends on:** 2, 4

- [ ] 9. Profile & Channel Screen
  - Create `ProfileViewModel.kt` with `ProfileUiState`; implement `loadProfile(userId)`, `subscribe()`, `unsubscribe()`, `editProfile()`, `uploadAvatar()`
  - Create `ui/screens/profile/ProfileScreen.kt` with: banner image, circular avatar, username + verified badge, subscriber/video counts, bio, Subscribe/Edit Profile button (context-aware), tab row (Videos, Playlists, About), `LazyVerticalGrid` for videos tab
  - Implement subscribe/unsubscribe with optimistic UI update and Firestore atomic increment
  - Implement profile edit bottom sheet (username, bio, avatar picker)
  - Implement avatar upload to Firebase Storage with progress indicator
  - Add `Profile` route to navigation with `userId` argument
  - **Acceptance:** Profile loads, subscribe/unsubscribe works, own profile shows edit option, avatar upload works
  - **Depends on:** 2, 4

- [ ] 10. Upload & Creator Studio
  - Create `UploadViewModel.kt` managing upload state (idle, selecting, uploading with progress, processing, complete, error); implement `selectVideo()`, `startUpload()`, `cancelUpload()`
  - Create `services/UploadWorker.kt` extending `CoroutineWorker`; implement chunked Firebase Storage upload with `setProgress()` for progress reporting; on completion write Firestore video document with `status: "processing"`
  - Create `ui/screens/upload/UploadScreen.kt` with: video picker (gallery intent), thumbnail selector, form fields (title, description, tags, category, privacy), upload progress `LinearProgressIndicator`, cancel button
  - Create `ui/screens/upload/StudioScreen.kt` with: stats cards (total views, subscribers, watch time, estimated revenue), `LazyColumn` of uploaded videos with edit/delete/analytics per item
  - Request `READ_MEDIA_VIDEO` permission (Android 13+) or `READ_EXTERNAL_STORAGE` (Android 12-)
  - **Acceptance:** Video can be selected and uploaded with progress, WorkManager job survives app backgrounding, Studio shows video list
  - **Depends on:** 2, 3

- [ ] 11. Subscriptions & Library Screens
  - Create `SubscriptionsViewModel.kt` loading videos from followed channels sorted by `uploadedAt` desc using Paging 3
  - Create `ui/screens/subscriptions/SubscriptionsScreen.kt` with: `LazyColumn` of `VideoCard` items, "Manage Subscriptions" bottom sheet with unsubscribe and notification bell toggle per channel
  - Create `LibraryViewModel.kt` managing watch history, saved videos, playlists, and downloads
  - Create `ui/screens/library/LibraryScreen.kt` with tab row: History (clear all + swipe-to-delete), Saved, Playlists (create playlist FAB), Downloads
  - Implement playlist creation dialog (name + privacy)
  - Implement offline playback: `ExoPlayer` with `file://` URI for downloaded videos
  - **Acceptance:** Subscriptions feed shows latest videos from followed channels, Library tabs all load correct data, offline playback works
  - **Depends on:** 4, 5

- [ ] 12. Live Streaming Viewer & Creator
  - Create `LiveViewModel.kt` managing `LiveUiState` (stream metadata, chat messages, viewer count, isLive); implement `loadStream(streamId)`, `sendMessage(text)`, `sendSuperChat(text, amount)`, `startStream()`, `endStream()`
  - Create `ui/screens/live/LiveScreen.kt` with: full-width `PlayerView` for HLS live stream, LIVE badge + viewer count overlay, real-time chat panel (`LazyColumn` with `reverseLayout = true`), chat input row with send and Super Chat buttons, creator end-stream button
  - Implement real-time chat via Firebase Realtime Database listener using `callbackFlow`
  - Implement Super Chat bottom sheet with amount selector ($1, $5, $10, $50, $100) calling Cloud Function `sendSuperChat`
  - Create live stream creation screen: title, category, thumbnail; calls Cloud Function `createLiveStream` returning RTMP ingest URL
  - Add `Live` route to navigation
  - **Acceptance:** Live streams play, chat updates in real-time, Super Chat flow works, stream creation returns ingest URL
  - **Depends on:** 5, 3

- [ ] 13. VS Match Screen
  - Create `VSMatchViewModel.kt` with `VSMatchUiState`; implement `loadOpenMatches()`, `createMatch(wagerAmount)`, `acceptMatch(matchId)`, `loadMyMatches()`; all match creation/acceptance calls go through Cloud Function `createVSMatch` callable
  - Create `ui/screens/vsmatch/VSMatchScreen.kt` with: tab row (Open Challenges, My Matches, Leaderboard), open challenges `LazyColumn` with match cards (challenger avatar, wager amount, division belt icon, accept button), My Matches list with status chips, Leaderboard with belt rankings
  - Implement compliance gate: check `user.age >= 18` and `user.termsAccepted` before showing create/accept UI; show age verification dialog if needed; show KYC prompt for wagers ≥ $500 (50000 cents)
  - Display championship belt division badge per wager tier (Lightweight through Ultra Heavyweight) using colored icons
  - Implement match result screen showing winner, payout (wager × 2 × 0.9), and updated belt ranking
  - All wager amounts stored and transmitted as integer cents
  - **Acceptance:** Open matches load, compliance checks fire correctly, match creation calls Cloud Function, result screen shows correct payout
  - **Depends on:** 2, 3

- [ ] 14. Notifications
  - Create `services/MyChannelMessagingService.kt` extending `FirebaseMessagingService`; handle `onMessageReceived` for foreground notifications using `NotificationCompat`; handle `onNewToken` to update Firestore user document
  - Create `NotificationViewModel.kt` loading notifications from Firestore `notifications/{uid}/items` ordered by `createdAt` desc; implement `markAsRead(notifId)`, `markAllAsRead()`, `deleteNotification(notifId)`
  - Create `ui/screens/notifications/NotificationsScreen.kt` with `LazyColumn` of notification items (icon by type, title, body, timestamp, unread indicator); swipe-to-delete; "Mark all read" action in top bar
  - Request `POST_NOTIFICATIONS` permission on Android 13+ at app start
  - Create notification channels: "New Content", "Live Streams", "VS Matches", "Payouts"
  - Handle notification tap deep links: route to correct screen based on `data` payload
  - **Acceptance:** FCM notifications arrive and display, tapping navigates to correct screen, in-app center shows notification history
  - **Depends on:** 1, 3

- [ ] 15. Settings Screen
  - Create `SettingsViewModel.kt` reading/writing `DataStore<Preferences>`; manage: `themeMode` (Light/Dark/System), `videoQuality` (Auto/144p/.../1080p), `dataSaverEnabled`, `downloadQuality`, `notificationPreferences` map, `autoplayEnabled`
  - Create `ui/screens/settings/SettingsScreen.kt` with grouped `LazyColumn` sections: Appearance (theme selector), Playback (quality, autoplay, data saver toggles), Downloads (quality, storage info), Notifications (per-type toggles), Account (edit profile link, privacy policy, terms, sign out with confirmation dialog)
  - Apply `themeMode` change immediately by passing it to `MyChannelTheme` via a `StateFlow` observed at the root
  - Apply `dataSaverEnabled` to `VideoPlayerViewModel` to cap quality at 480p and disable autoplay on metered networks
  - **Acceptance:** Theme changes apply immediately, data saver caps quality, sign out works, all preferences persist across restarts
  - **Depends on:** 1, 3

- [ ] 16. AdMob Integration & Monetization
  - Add AdMob dependency and initialize `MobileAds` in `MyChannelApp`
  - Create `AdManager.kt` singleton (Hilt `@Singleton`) managing banner, interstitial, and rewarded ad loading and display
  - Integrate banner ad in `HomeScreen` between feed sections (hidden for premium users)
  - Integrate interstitial ad on video player open (max once per 3 videos, hidden for premium users)
  - Check `user.isPremium` from Firestore before showing any ad; premium users see no ads
  - Add Google Play Billing dependency and create `BillingManager.kt` handling `BillingClient` connection, product details query, purchase flow, and purchase verification via Cloud Function
  - Add "Go Premium" button in Settings and profile screen linking to the billing flow
  - **Acceptance:** Ads show for non-premium users, premium users see no ads, billing flow launches correctly
  - **Depends on:** 3, 15

- [ ] 17. Performance, Accessibility & Polish
  - Audit all `LazyColumn`/`LazyRow` usages to ensure `key = { item.id }` is set on all items
  - Add `contentDescription` to all `Icon`, `IconButton`, and `AsyncImage` composables that lack one
  - Ensure all interactive elements have minimum 48×48dp touch targets
  - Replace all `CircularProgressIndicator` first-load states with `SkeletonLoader` shimmer composables
  - Add `semantics` blocks for complex custom composables (VideoCard, FloatingMiniPlayer)
  - Verify Dynamic Type scaling works by testing with large font sizes in the emulator
  - Implement `ConnectivityObserver` using `NetworkCallback` to show a "No internet" snackbar when offline
  - Write unit tests for `HomeViewModel`, `VideoPlayerViewModel`, `AuthViewModel`, `SearchViewModel` using Mockito-Kotlin with mock repositories
  - Run lint and fix all warnings; ensure ProGuard rules are complete for Retrofit, Gson, Firebase, and ExoPlayer
  - **Acceptance:** No accessibility warnings in Accessibility Scanner, unit tests pass, lint passes clean
  - **Depends on:** 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2"] },
    { "wave": 3, "tasks": ["3"] },
    { "wave": 4, "tasks": ["4", "10", "14"] },
    { "wave": 5, "tasks": ["5", "8", "9", "13", "15"] },
    { "wave": 6, "tasks": ["6", "7", "11", "12", "16"] },
    { "wave": 7, "tasks": ["17"] }
  ],
  "dependencies": {
    "1": [],
    "2": ["1"],
    "3": ["1", "2"],
    "4": ["2", "3"],
    "5": ["2", "4"],
    "6": ["5"],
    "7": ["4", "5"],
    "8": ["2", "4"],
    "9": ["2", "4"],
    "10": ["2", "3"],
    "11": ["4", "5"],
    "12": ["5", "3"],
    "13": ["2", "3"],
    "14": ["1", "3"],
    "15": ["1", "3"],
    "16": ["3", "15"],
    "17": ["4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]
  }
}
```

## Notes

- The existing `FloatingMiniPlayer.kt` uses the legacy `com.google.android.exoplayer2` package. Task 6 must migrate it to `androidx.media3`.
- The existing `HomeScreen.kt` references `painterResource(R.drawable.ic_search)` and other drawables that don't exist yet — Task 1 creates them.
- The existing `MyChannelNavigation.kt` references `FlicksScreen`, `UploadScreen`, `SubscriptionsScreen`, `LibraryScreen` which don't exist yet — stub implementations are acceptable until their respective tasks run.
- VS Match money handling: all amounts in integer cents, all mutations via Cloud Functions, never direct Firestore writes from the client for money fields.
- The `google-services.json` file must be placed at `android/app/google-services.json` before the app can connect to Firebase. This is a manual step outside the scope of these tasks.
