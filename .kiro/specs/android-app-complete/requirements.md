# Requirements Document

## Introduction

MyChannel Android is a production-ready native Android application that delivers full feature parity with the iOS app. It serves creators and viewers on the Android platform with video streaming, live broadcasting, VS Match competitions, social features, and monetization tools — all built on Firebase and following Material Design 3 with Jetpack Compose.

The app targets Android 8.0+ (API 26+), uses Kotlin with Jetpack Compose, and integrates the same Firebase backend as the iOS and web clients.

## Requirements

### 1. Foundation & Architecture

**REQ-1.1** The app MUST use MVVM + Clean Architecture with Hilt dependency injection, Jetpack Compose UI, and Compose Navigation.

**REQ-1.2** The app MUST implement a `MyChannelTheme` with brand colors (primary red `#E85D5D`), adaptive dark/light mode, Material Design 3 typography, and a 4dp spacing grid.

**REQ-1.3** The app MUST integrate Firebase Auth, Firestore, Storage, FCM, Analytics, Crashlytics, and Performance Monitoring via the Firebase BOM.

**REQ-1.4** The app MUST use Room for local caching of videos, channels, and user data to support offline browsing.

**REQ-1.5** The app MUST use DataStore Preferences for user settings (theme, quality, notifications).

**REQ-1.6** The app MUST implement a `MyChannelApplication` class annotated with `@HiltAndroidApp` as the application entry point.

**REQ-1.7** The app MUST include a splash screen using `androidx.core:core-splashscreen` that transitions to the main UI.

### 2. Authentication

**REQ-2.1** The app MUST support Email/Password sign-in and registration via Firebase Auth.

**REQ-2.2** The app MUST support Google Sign-In via Firebase Auth with the Google Identity Services SDK.

**REQ-2.3** The app MUST support anonymous authentication for unauthenticated browsing.

**REQ-2.4** The app MUST support password reset via Firebase Auth email link.

**REQ-2.5** The app MUST persist auth state across app restarts and route unauthenticated users to the auth flow.

**REQ-2.6** The app MUST display a profile setup screen on first sign-in (username, avatar, bio).

### 3. Navigation & Shell

**REQ-3.1** The app MUST implement a bottom navigation bar with five tabs: Home, Flicks, Upload (+), Subscriptions, Library.

**REQ-3.2** The app MUST support deep links using the `mychannel://` scheme (e.g., `mychannel://video/{id}`, `mychannel://channel/{id}`).

**REQ-3.3** The app MUST display a floating mini player that persists across tab navigation when a video is playing.

**REQ-3.4** The app MUST support back-stack state restoration when switching tabs.

### 4. Home Screen

**REQ-4.1** The home screen MUST display a horizontal filter chip row (All, Live, Shorts, Music, Movies, Gaming, News).

**REQ-4.2** The home screen MUST display a Stories row with circular avatars and a pulsing live indicator for active streams.

**REQ-4.3** The home screen MUST display a Trending section with video cards showing thumbnail, title, channel name, view count, and duration.

**REQ-4.4** The home screen MUST display a Live Now section with live stream cards showing viewer count and a LIVE badge.

**REQ-4.5** The home screen MUST support infinite scroll with Paging 3 and display skeleton loading placeholders while fetching.

**REQ-4.6** The home screen MUST support pull-to-refresh.

### 5. Video Player

**REQ-5.1** The video player MUST use Media3 ExoPlayer with HLS and DASH support.

**REQ-5.2** The video player MUST support quality selection (Auto, 144p, 240p, 360p, 480p, 720p, 1080p, 4K where available).

**REQ-5.3** The video player MUST support playback speed control (0.25×, 0.5×, 0.75×, 1×, 1.25×, 1.5×, 1.75×, 2×).

**REQ-5.4** The video player MUST support Picture-in-Picture (PiP) mode on Android 8.0+.

**REQ-5.5** The video player MUST support background audio playback via a foreground `MediaSessionService`.

**REQ-5.6** The video player MUST display a floating mini player when the user navigates away without stopping playback.

**REQ-5.7** The video player MUST display video metadata: title, channel name, view count, like/dislike counts, description, and tags.

**REQ-5.8** The video player MUST display a comments section with nested replies, pagination, and the ability to post comments.

**REQ-5.9** The video player MUST display an "Up Next" / related videos list below the comments.

**REQ-5.10** The video player MUST support captions/subtitles when available.

**REQ-5.11** The video player MUST support casting via the Cast SDK (Chromecast).

### 6. Search

**REQ-6.1** The search screen MUST support real-time search with 300ms debounce against Firestore.

**REQ-6.2** The search screen MUST display search history (stored locally in Room) and allow clearing history.

**REQ-6.3** The search screen MUST display trending searches fetched from Firestore.

**REQ-6.4** The search screen MUST support filter tabs: All, Videos, Channels, Playlists, Live.

**REQ-6.5** The search screen MUST support voice search via Android's `SpeechRecognizer`.

### 7. Flicks (Shorts)

**REQ-7.1** The Flicks screen MUST display a vertical full-screen swipe feed of short-form videos (≤ 60 seconds).

**REQ-7.2** Each Flick MUST auto-play on scroll and loop continuously.

**REQ-7.3** Each Flick MUST display like, comment, share, and follow actions as an overlay.

**REQ-7.4** The Flicks screen MUST support swipe-up/down navigation between videos.

**REQ-7.5** The Flicks screen MUST display the creator's username, video caption, and audio attribution as overlays.

### 8. Upload & Creator Studio

**REQ-8.1** The upload flow MUST support selecting a video from the device gallery or recording directly.

**REQ-8.2** The upload flow MUST support chunked upload to Firebase Storage with a visible progress indicator and resume capability.

**REQ-8.3** The upload form MUST collect title, description, tags, category, thumbnail (auto-generated or custom), and privacy setting (Public, Unlisted, Private).

**REQ-8.4** The Creator Studio MUST display a dashboard with total views, subscribers, watch time, and revenue.

**REQ-8.5** The Creator Studio MUST list the creator's uploaded videos with edit, delete, and analytics actions.

**REQ-8.6** The upload MUST run as a background `WorkManager` job so it continues if the user leaves the screen.

### 9. Subscriptions Feed

**REQ-9.1** The Subscriptions screen MUST display the latest videos from channels the user follows, sorted by upload date.

**REQ-9.2** The Subscriptions screen MUST display a "Manage" option to unsubscribe from channels.

**REQ-9.3** The Subscriptions screen MUST show a notification bell icon per channel to toggle upload alerts.

### 10. Library

**REQ-10.1** The Library screen MUST display the user's Watch History with the ability to clear individual entries or all history.

**REQ-10.2** The Library screen MUST display Watch Later / Saved videos.

**REQ-10.3** The Library screen MUST display the user's Playlists with create, edit, and delete actions.

**REQ-10.4** The Library screen MUST display Downloaded videos for offline playback.

**REQ-10.5** Downloaded videos MUST be playable offline via ExoPlayer with a local file URI.

### 11. Profile & Channel Pages

**REQ-11.1** The profile screen MUST display the user's avatar, username, subscriber count, video count, and bio.

**REQ-11.2** The profile screen MUST display a grid of the user's uploaded videos.

**REQ-11.3** Other users' channel pages MUST display a Subscribe/Unsubscribe button that updates Firestore atomically.

**REQ-11.4** The profile screen MUST allow the authenticated user to edit their profile (avatar, username, bio).

### 12. Live Streaming

**REQ-12.1** The live viewer screen MUST display the live stream via HLS with a LIVE badge and real-time viewer count.

**REQ-12.2** The live viewer screen MUST display a real-time chat panel backed by Firebase Realtime Database.

**REQ-12.3** Authenticated users MUST be able to send chat messages and Super Chat tips during a live stream.

**REQ-12.4** The live creation flow MUST allow creators to start a stream, set a title/category, and receive an RTMP ingest URL.

### 13. VS Match (Real-Money Competitions)

**REQ-13.1** The VS Match screen MUST display open challenges with wager amounts, divisions, and creator stats.

**REQ-13.2** Creating or accepting a VS Match MUST enforce all compliance checks: age 18+, KYC for wagers ≥ $500, terms acceptance, region check, and daily limits.

**REQ-13.3** All wager funds MUST flow through the escrow system via Cloud Functions — never directly from the client.

**REQ-13.4** The VS Match screen MUST display the championship belt division for each wager tier (Lightweight through Ultra Heavyweight).

**REQ-13.5** The VS Match result screen MUST display the winner, payout amount (after 10% platform fee), and updated belt ranking.

### 14. Notifications

**REQ-14.1** The app MUST register for FCM push notifications and handle foreground, background, and terminated-state messages.

**REQ-14.2** The app MUST display an in-app notification center listing recent notifications with read/unread state.

**REQ-14.3** Notification types MUST include: new subscriber, new comment, live stream started, VS Match challenge, VS Match result, and payout received.

**REQ-14.4** The user MUST be able to configure notification preferences per type in Settings.

### 15. Settings

**REQ-15.1** Settings MUST include: Theme (Light / Dark / System), Video Quality (Auto / specific), Data Saver mode, Download quality, Notification preferences, Account management, Privacy settings, and Sign Out.

**REQ-15.2** Settings MUST persist via DataStore Preferences and apply immediately without restart.

**REQ-15.3** The app MUST respect the system dark mode setting when Theme is set to "System".

### 16. Monetization

**REQ-16.1** The app MUST integrate AdMob for banner, interstitial, and rewarded ads.

**REQ-16.2** Premium subscribers MUST see no ads; the app MUST check subscription status via Firebase before showing ads.

**REQ-16.3** The app MUST support in-app purchases via Google Play Billing for channel memberships and premium subscriptions.

### 17. Performance & Quality

**REQ-17.1** Cold start time MUST be under 2 seconds on a mid-range device.

**REQ-17.2** Video start time MUST be under 2 seconds on a 4G connection.

**REQ-17.3** The feed MUST scroll at 60fps with no dropped frames during normal use.

**REQ-17.4** The app MUST implement adaptive bitrate streaming so video quality adjusts to network conditions.

**REQ-17.5** The app MUST support a Data Saver mode that caps streaming quality at 480p and disables autoplay on mobile data.

### 18. Accessibility & Localization

**REQ-18.1** All interactive elements MUST have content descriptions for TalkBack.

**REQ-18.2** The app MUST support Dynamic Type / font scaling.

**REQ-18.3** Minimum touch target size MUST be 48×48dp.

**REQ-18.4** The app MUST support English as the primary locale with the strings.xml infrastructure ready for additional languages.

### 19. Security

**REQ-19.1** All API keys and secrets MUST be stored in `local.properties` or Android Keystore — never hardcoded.

**REQ-19.2** Firebase Security Rules MUST be the authoritative access control layer; client-side checks are supplementary only.

**REQ-19.3** All network communication MUST use HTTPS. Certificate pinning MUST be implemented for the `api.mychannel.live` domain.

**REQ-19.4** User authentication tokens MUST be stored in Android Keystore via `EncryptedSharedPreferences`.

## Glossary

- **Flicks**: MyChannel's short-form vertical video format (≤ 60 seconds), equivalent to YouTube Shorts or TikTok.
- **VS Match**: A real-money video competition between two creators where viewers vote and the winner receives the wager payout minus the 10% platform fee.
- **Championship Belt**: A ranked tier system for VS Match wager amounts (Lightweight $1–$100 through Ultra Heavyweight $10K+).
- **Super Chat**: A paid highlighted message sent during a live stream.
- **Mini Player**: A compact floating video player that persists while the user navigates other parts of the app.
- **HLS**: HTTP Live Streaming — the primary video delivery protocol used by MyChannel.
- **ExoPlayer / Media3**: Google's open-source media player library used for all video playback on Android.
- **Hilt**: Google's dependency injection framework for Android, built on Dagger.
- **Room**: Android's SQLite ORM used for local data caching.
- **DataStore**: Jetpack's replacement for SharedPreferences used for user settings.
