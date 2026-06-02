# Design Document

## Overview

The MyChannel Android app is a Jetpack Compose application following Clean Architecture with MVVM. It mirrors the iOS app's feature set and connects to the same Firebase backend. The architecture is organized into four layers: UI (Compose screens + ViewModels), Domain (use cases + models), Data (repositories + Room + Firebase), and DI (Hilt modules).

## Architecture

### Layer Structure

```
com.mychannel/
├── MyChannelApp.kt              # @HiltAndroidApp Application
├── MainActivity.kt              # Single activity, Compose host
│
├── ui/
│   ├── theme/
│   │   ├── Color.kt
│   │   ├── Typography.kt
│   │   ├── Shape.kt
│   │   └── Theme.kt             # MyChannelTheme
│   ├── navigation/
│   │   ├── Screen.kt            # Route definitions
│   │   └── MyChannelNavigation.kt
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── LoginScreen.kt
│   │   │   ├── RegisterScreen.kt
│   │   │   └── ProfileSetupScreen.kt
│   │   ├── home/
│   │   │   └── HomeScreen.kt
│   │   ├── video/
│   │   │   └── VideoPlayerScreen.kt
│   │   ├── flicks/
│   │   │   └── FlicksScreen.kt
│   │   ├── upload/
│   │   │   ├── UploadScreen.kt
│   │   │   └── StudioScreen.kt
│   │   ├── subscriptions/
│   │   │   └── SubscriptionsScreen.kt
│   │   ├── library/
│   │   │   └── LibraryScreen.kt
│   │   ├── search/
│   │   │   └── SearchScreen.kt
│   │   ├── profile/
│   │   │   └── ProfileScreen.kt
│   │   ├── live/
│   │   │   └── LiveScreen.kt
│   │   ├── vsmatch/
│   │   │   └── VSMatchScreen.kt
│   │   ├── notifications/
│   │   │   └── NotificationsScreen.kt
│   │   └── settings/
│   │       └── SettingsScreen.kt
│   ├── components/
│   │   ├── VideoCard.kt
│   │   ├── ChannelCard.kt
│   │   ├── FloatingMiniPlayer.kt
│   │   ├── StoriesRow.kt
│   │   ├── FilterChips.kt
│   │   ├── SkeletonLoader.kt
│   │   └── LiveBadge.kt
│   └── viewmodel/
│       ├── AuthViewModel.kt
│       ├── HomeViewModel.kt
│       ├── VideoPlayerViewModel.kt
│       ├── FlicksViewModel.kt
│       ├── UploadViewModel.kt
│       ├── SearchViewModel.kt
│       ├── ProfileViewModel.kt
│       ├── LibraryViewModel.kt
│       ├── SubscriptionsViewModel.kt
│       ├── LiveViewModel.kt
│       ├── VSMatchViewModel.kt
│       └── SettingsViewModel.kt
│
├── domain/
│   ├── model/
│   │   ├── User.kt
│   │   ├── Video.kt
│   │   ├── Channel.kt
│   │   ├── LiveStream.kt
│   │   ├── Comment.kt
│   │   ├── Playlist.kt
│   │   ├── Notification.kt
│   │   └── VSMatch.kt
│   └── repository/
│       ├── AuthRepository.kt    # interface
│       ├── VideoRepository.kt   # interface
│       ├── ChannelRepository.kt # interface
│       ├── SearchRepository.kt  # interface
│       └── VSMatchRepository.kt # interface
│
├── data/
│   ├── local/
│   │   ├── AppDatabase.kt
│   │   ├── entity/
│   │   │   ├── VideoEntity.kt
│   │   │   ├── ChannelEntity.kt
│   │   │   └── SearchHistoryEntity.kt
│   │   └── dao/
│   │       ├── VideoDao.kt
│   │       ├── ChannelDao.kt
│   │       └── SearchHistoryDao.kt
│   ├── remote/
│   │   ├── FirebaseAuthDataSource.kt
│   │   ├── FirestoreVideoDataSource.kt
│   │   ├── FirestoreChannelDataSource.kt
│   │   └── FirestoreVSMatchDataSource.kt
│   └── repository/
│       ├── AuthRepositoryImpl.kt
│       ├── VideoRepositoryImpl.kt
│       ├── ChannelRepositoryImpl.kt
│       ├── SearchRepositoryImpl.kt
│       └── VSMatchRepositoryImpl.kt
│
├── services/
│   ├── MediaPlaybackService.kt  # MediaSessionService for background audio
│   ├── UploadWorker.kt          # WorkManager for background uploads
│   └── MyChannelMessagingService.kt # FCM handler
│
└── di/
    ├── AppModule.kt
    ├── DatabaseModule.kt
    ├── FirebaseModule.kt
    ├── NetworkModule.kt
    └── RepositoryModule.kt
```

## Theme System

### Colors (`Color.kt`)
```kotlin
val BrandRed = Color(0xFFE85D5D)
val BrandRedDark = Color(0xFFCC4444)
val BackgroundDark = Color(0xFF0F0F0F)
val BackgroundLight = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF1A1A1A)
val SurfaceLight = Color(0xFFF5F5F5)
```

### Typography
- Display: System default bold, 57sp
- Headline: System default semibold, 32sp / 28sp / 24sp
- Body: System default regular, 16sp / 14sp
- Label: System default medium, 12sp / 11sp

### Theme (`Theme.kt`)
`MyChannelTheme` wraps `MaterialTheme` with custom `ColorScheme` (light/dark), `Typography`, and `Shapes`. It reads the system dark mode setting and the user's DataStore preference.

## Navigation Design

### Route Definitions
```kotlin
sealed class Screen(val route: String) {
    object Auth : Screen("auth")
    object Login : Screen("login")
    object Register : Screen("register")
    object ProfileSetup : Screen("profile_setup")
    object Home : Screen("home")
    object VideoPlayer : Screen("video/{videoId}") {
        fun createRoute(id: String) = "video/$id"
    }
    object Flicks : Screen("flicks")
    object Upload : Screen("upload")
    object Studio : Screen("studio")
    object Subscriptions : Screen("subscriptions")
    object Library : Screen("library")
    object Search : Screen("search")
    object Profile : Screen("profile/{userId}") {
        fun createRoute(id: String) = "profile/$id"
    }
    object Live : Screen("live/{streamId}") {
        fun createRoute(id: String) = "live/$id"
    }
    object VSMatch : Screen("vsmatch")
    object Notifications : Screen("notifications")
    object Settings : Screen("settings")
}
```

### Navigation Graph
- Root `NavHost` starts at `Screen.Auth` if unauthenticated, `Screen.Home` if authenticated.
- Auth graph: Login → Register → ProfileSetup → Home
- Main graph: Scaffold with bottom nav (Home, Flicks, Upload, Subscriptions, Library) + full-screen routes (VideoPlayer, Search, Profile, Live, VSMatch, Notifications, Settings)
- Deep link handling: `mychannel://video/{id}`, `mychannel://channel/{id}`, `mychannel://live/{id}`

## Data Models

### Video
```kotlin
data class Video(
    val id: String,
    val title: String,
    val description: String,
    val thumbnailUrl: String,
    val videoUrl: String,       // HLS manifest URL
    val channelId: String,
    val channelName: String,
    val channelAvatarUrl: String,
    val viewCount: Long,
    val likeCount: Long,
    val dislikeCount: Long,
    val commentCount: Long,
    val duration: Long,         // seconds
    val uploadedAt: Timestamp,
    val tags: List<String>,
    val category: String,
    val isLive: Boolean,
    val isShort: Boolean,
    val privacyStatus: String   // "public" | "unlisted" | "private"
)
```

### User / Channel
```kotlin
data class User(
    val uid: String,
    val username: String,
    val displayName: String,
    val avatarUrl: String,
    val bio: String,
    val subscriberCount: Long,
    val videoCount: Long,
    val isVerified: Boolean,
    val createdAt: Timestamp
)
```

### VSMatch
```kotlin
data class VSMatch(
    val id: String,
    val challengerId: String,
    val challengerName: String,
    val opponentId: String?,
    val opponentName: String?,
    val wagerAmount: Long,      // integer cents
    val division: String,       // "lightweight" | "welterweight" | etc.
    val status: String,         // "open" | "active" | "completed" | "cancelled"
    val winnerId: String?,
    val escrowId: String,
    val createdAt: Timestamp
)
```

## Key Component Designs

### HomeViewModel State
```kotlin
data class HomeUiState(
    val isLoading: Boolean = true,
    val trendingVideos: List<Video> = emptyList(),
    val recommendedVideos: List<Video> = emptyList(),
    val liveStreams: List<LiveStream> = emptyList(),
    val stories: List<Story> = emptyList(),
    val selectedFilter: String = "All",
    val error: String? = null
)
```

### VideoPlayerViewModel State
```kotlin
data class VideoPlayerUiState(
    val video: Video? = null,
    val isPlaying: Boolean = false,
    val currentPosition: Long = 0,
    val duration: Long = 0,
    val isBuffering: Boolean = false,
    val selectedQuality: String = "Auto",
    val playbackSpeed: Float = 1f,
    val comments: List<Comment> = emptyList(),
    val relatedVideos: List<Video> = emptyList(),
    val isLiked: Boolean = false,
    val isDisliked: Boolean = false,
    val isSaved: Boolean = false,
    val error: String? = null
)
```

### FloatingMiniPlayer
Persists in the `Scaffold` slot above the bottom nav bar. Controlled by a `MiniPlayerState` held in a `@Composable` at the navigation root level, shared via `CompositionLocal`. Supports swipe-to-dismiss and tap-to-expand.

## Firebase Data Architecture

### Firestore Collections
```
users/{uid}
  - username, displayName, avatarUrl, bio, subscriberCount, videoCount, isVerified, createdAt

channels/{channelId}  (same as users for creator channels)

videos/{videoId}
  - title, description, thumbnailUrl, videoUrl, channelId, channelName
  - viewCount, likeCount, dislikeCount, commentCount, duration
  - uploadedAt, tags, category, isLive, isShort, privacyStatus

videos/{videoId}/comments/{commentId}
  - userId, username, avatarUrl, text, likeCount, createdAt, parentId

liveStreams/{streamId}
  - channelId, title, thumbnailUrl, hlsUrl, viewerCount, startedAt, status

vsMatches/{matchId}
  - challengerId, opponentId, wagerAmount, division, status, escrowId, createdAt

escrow/{escrowId}  (read-only from client; written only by Cloud Functions)

notifications/{userId}/items/{notifId}
  - type, title, body, data, isRead, createdAt
```

### Realtime Database (Live Chat)
```
chats/{streamId}/messages/{messageId}
  - userId, username, avatarUrl, text, type (normal|superchat), amount, timestamp
```

## Video Playback Architecture

### Media3 ExoPlayer Setup
- `VideoPlayerViewModel` owns the `ExoPlayer` instance (created in `init`, released in `onCleared`).
- HLS `MediaItem` built from the video's `videoUrl`.
- `MediaSessionService` (`MediaPlaybackService`) enables background playback and lock-screen controls.
- PiP: `MainActivity` overrides `onUserLeaveHint()` to enter PiP mode when a video is playing.
- Mini player: `MiniPlayerController` (singleton scoped to the nav graph) holds player state and is observed by both `VideoPlayerScreen` and `FloatingMiniPlayer`.

## Upload Architecture

### WorkManager Flow
1. User selects video → `UploadViewModel` creates a `UploadWorker` via `WorkManager`.
2. `UploadWorker` uploads to Firebase Storage in chunks, reporting progress via `WorkInfo`.
3. On completion, a Cloud Function trigger (`onFinalize`) processes the video (thumbnail extraction, transcoding metadata).
4. `UploadWorker` writes the video document to Firestore with `status: "processing"`.
5. The Studio screen observes the video document and updates the UI when `status` changes to `"ready"`.

## VS Match Compliance Flow

All VS Match creation/acceptance goes through a Cloud Function (`createVSMatch` callable). The Android client:
1. Checks local user data for age (18+) and terms acceptance before showing the UI.
2. Calls the Cloud Function with match parameters.
3. The Cloud Function performs all server-side compliance checks (age, KYC, region, daily limits) and locks escrow atomically.
4. The client observes the match document in Firestore for status updates.

## Dependency Injection (Hilt Modules)

### FirebaseModule
Provides: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`, `FirebaseDatabase`, `FirebaseMessaging`

### DatabaseModule
Provides: `AppDatabase`, `VideoDao`, `ChannelDao`, `SearchHistoryDao`

### RepositoryModule
Binds: `AuthRepositoryImpl → AuthRepository`, `VideoRepositoryImpl → VideoRepository`, etc.

### NetworkModule
Provides: `OkHttpClient` (with auth interceptor + certificate pinning), `Retrofit`

## Security Design

- **Certificate Pinning**: OkHttp `CertificatePinner` for `api.mychannel.live`.
- **Encrypted Storage**: `EncryptedSharedPreferences` backed by Android Keystore for auth tokens.
- **ProGuard**: Release builds use R8 with full minification and resource shrinking.
- **No secrets in code**: API keys in `local.properties` (gitignored), accessed via `BuildConfig`.
- **Firebase Rules**: Firestore and Storage rules enforce auth and ownership — client is untrusted.

## Performance Design

- **Paging 3**: All feed screens use `Pager` + `PagingSource` backed by Firestore cursors.
- **Coil**: Image loading with memory + disk cache; `AsyncImage` with `crossfade`.
- **LazyColumn keys**: All `LazyColumn`/`LazyRow` items use stable `key = { item.id }`.
- **Skeleton loaders**: `ShimmerEffect` composable shown while Paging loads the first page.
- **Adaptive bitrate**: ExoPlayer `DefaultTrackSelector` with `AdaptiveTrackSelection.Factory`.
- **Data Saver**: `DataStore` flag caps quality at 480p and disables autoplay on metered networks.
