# MyChannel - Comprehensive Cursor Rules
# Complete coding standards and patterns for the entire MyChannel platform

## 🎯 PROJECT OVERVIEW
MyChannel is a next-generation video platform combining YouTube + Twitch + DraftKings + UFC.
- **Video hosting & streaming** (like YouTube)
- **Live streaming & awards** (like Twitch)
- **Real money competitions** (like DraftKings)
- **Championship rankings** (like UFC)

Platform Value: $550M - $1B+
Tech Stack: SwiftUI (iOS), Firebase Backend, 30+ AGI Agents, Real-time Analytics

**NOTE:** AI video/image generation features belong to **Parachute/Gekko** (separate app), NOT MyChannel!

---

## 📱 SWIFT & iOS DEVELOPMENT

### Language & Framework Versions
- Swift 5.9+
- SwiftUI (iOS 15+)
- Xcode 15+
- Deployment Target: iOS 15.0+

### Swift Best Practices
- **Type System**: Use Swift's strong type system and optionals correctly
- **Value Types**: Prefer `struct` over `class` for models and views
- **Protocol-Oriented**: Use protocols and protocol extensions for shared behavior
- **Async/Await**: Always use `async/await` for asynchronous operations (NO completion handlers)
- **MainActor**: Always use `@MainActor` for ObservableObject classes that update UI
- **Property Wrappers**: Use `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` appropriately
- **Result Type**: Use `Result<Success, Error>` for operations that can fail
- **Combine**: Use Combine framework for reactive programming when appropriate

### Naming Conventions
- **Types**: PascalCase (e.g., `VideoPlayer`, `UserProfile`, `AGIAgent`)
- **Properties/Functions**: camelCase (e.g., `videoCount`, `fetchVideos()`, `isAuthenticated`)
- **Constants**: camelCase (e.g., `maxUploadSize`, `defaultQuality`)
- **Booleans**: Prefix with `is`, `has`, `should` (e.g., `isVerified`, `hasSubscription`, `shouldAutoplay`)
- **Functions**: Use verbs (e.g., `fetchData()`, `updateProfile()`, `toggleLike()`)
- **Enums**: PascalCase for type, camelCase for cases (e.g., `VideoCategory.gaming`)

---

## 🏗️ ARCHITECTURE PATTERNS

### MVVM Architecture
```swift
// ✅ CORRECT PATTERN:

// Model
struct Video: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    // ... properties
}

// ViewModel
@MainActor
final class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchVideos() async {
        isLoading = true
        defer { isLoading = false }
        // ... async logic
    }
}

// View
struct VideoListView: View {
    @StateObject private var viewModel = VideoViewModel()
    
    var body: some View {
        // ... view code
    }
}
```

### Service Layer Pattern
- **Services are Singletons**: Use `static let shared = ServiceName()`
- **MainActor for UI Updates**: Services that publish UI state use `@MainActor`
- **Async Methods**: All network/database operations are `async`
- **Error Handling**: Use proper `do-catch` with meaningful error messages

```swift
@MainActor
final class VideoFirestoreService: ObservableObject {
    static let shared = VideoFirestoreService()
    private init() {}
    
    func fetchVideos(limit: Int = 24) async throws -> [Video] {
        // Implementation
    }
}
```

---

## 🔥 FIREBASE INTEGRATION

### Firebase Imports & Setup
```swift
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
```

### Firestore Patterns
- **Collections**: Use lowercase with hyphens (e.g., `videos`, `user-profiles`, `live-streams`)
- **Document IDs**: Use UUID strings or Firebase auto-IDs
- **Timestamps**: Use `FieldValue.serverTimestamp()` for creation/update times
- **Real-time Updates**: Use snapshot listeners for live data
- **Batch Operations**: Use batch writes for multiple document updates

```swift
// ✅ CORRECT FIRESTORE PATTERN:
func saveVideo(_ video: Video) async throws {
    #if canImport(FirebaseFirestore)
    let ref = Firestore.firestore().collection("videos").document(video.id)
    let data: [String: Any] = [
        "title": video.title,
        "createdAt": FieldValue.serverTimestamp(),
        "userId": video.creator.id
    ]
    try await ref.setData(data)
    #endif
}
```

### Firebase Auth Patterns
- Always check `FirebaseApp.app() != nil` before using Auth
- Store user data in both Auth and Firestore
- Use persistence: Keep users logged in across app launches
- Support both email/password and social auth (Apple, Google)

---

## 🎨 UI/UX PATTERNS

### AppTheme Usage
Always use AppTheme constants for consistency:
```swift
import SwiftUI

// ✅ CORRECT:
Text("Hello")
    .font(AppTheme.Typography.headline)
    .foregroundColor(AppTheme.Colors.textPrimary)
    .padding(AppTheme.Spacing.md)

// ❌ WRONG:
Text("Hello")
    .font(.headline)
    .foregroundColor(.black)
    .padding(16)
```

### Theme Constants
- **Colors**: `AppTheme.Colors.primary`, `.secondary`, `.background`, `.textPrimary`, etc.
- **Typography**: `AppTheme.Typography.largeTitle`, `.headline`, `.body`, etc.
- **Spacing**: `AppTheme.Spacing.xs`, `.sm`, `.md`, `.lg`, `.xl`, `.xxl`
- **Corner Radius**: `AppTheme.CornerRadius.xs`, `.sm`, `.md`, `.lg`, etc.
- **Animations**: `AppTheme.AnimationPresets.spring`, `.easeInOut`, `.bouncy`

### View Modifiers
Use pre-defined view modifiers:
```swift
VStack { /* content */ }
    .cardStyle()           // Standard card appearance
    .modernCardStyle()     // Glassmorphism card
    .primaryButtonStyle()  // Primary button
    .secondaryButtonStyle() // Secondary button
    .modernButtonStyle()   // Modern gradient button
    .floatingStyle()       // Floating element
```

### SF Symbols
- Use SF Symbols for all icons
- Always provide semantic names
- Support dark mode and dynamic type
```swift
Image(systemName: "play.circle.fill")
Label("Watch", systemImage: "play.rectangle")
```

### SwiftUI Best Practices
- **Preview Provider**: Always include `#Preview` for development
- **Accessibility**: Add `.accessibilityLabel()` and `.accessibilityHint()`
- **State Management**: Use correct property wrappers (@State, @Binding, @ObservedObject, etc.)
- **List Performance**: Use `LazyVStack` for long scrolling lists
- **Animations**: Use `withAnimation` for smooth transitions
- **Safe Area**: Always respect safe area insets
- **Dark Mode**: Support both light and dark modes

---

## 📊 DATA MODELS

### Core Models
- **Video**: Main content model (id, title, description, thumbnailURL, videoURL, creator, category, etc.)
- **User**: User/Creator profile (id, username, displayName, email, profileImageURL, bannerImageURL, subscriberCount, etc.)
- **VideoCategory**: Enum (movies, tvShows, anime, kids, gaming, music, etc.)
- **VideoQuality**: Enum (240p, 360p, 480p, 720p, 1080p, 1440p, 4K)
- **ContentSource**: Enum (userUploaded, tmdb, youtube, archive, etc.)

### Model Protocols
All models should conform to:
```swift
struct MyModel: Identifiable, Codable, Hashable {
    let id: String
    // ... properties
    
    // Custom Coding Keys if needed
    private enum CodingKeys: String, CodingKey {
        case id, title
        // ... keys
    }
}
```

### Model Computed Properties
Add helpful computed properties:
```swift
// ✅ GOOD:
var formattedDuration: String { /* ... */ }
var formattedViewCount: String { /* ... */ }
var timeAgo: String { /* ... */ }
var isLive: Bool { /* ... */ }
```

---

## 🔧 CONFIGURATION

### AppConfig Usage
Always use `AppConfig` for app-wide settings:
```swift
// Environment
AppConfig.environment // .development, .staging, .production
AppConfig.isDebug
AppConfig.isTestFlight
AppConfig.isAppStore

// Feature Flags
AppConfig.Features.enableFlicks
AppConfig.Features.enableLiveStreaming
AppConfig.Features.enableAds
AppConfig.Features.enableMockData

// Video Config
AppConfig.Video.defaultQuality
AppConfig.Video.maxDuration
AppConfig.Video.supportedFormats

// API Config
AppConfig.API.baseURL
AppConfig.API.cloudRunBaseURL
AppConfig.API.timeout

// UI Config
AppConfig.UI.animationDuration
AppConfig.UI.miniPlayerHeight
```

### AppSecrets
Never hardcode secrets. Use `AppSecrets`:
```swift
AppSecrets.googleCloudAPIKey
AppSecrets.googleCloudProjectID
AppSecrets.anthropicAPIKey
AppSecrets.openAIKey
```

---

## 🤖 AGI AGENTS SYSTEM

### Agent Architecture
- 30 total AGI agents planned (5 Money Maker agents currently active)
- All agents managed by `AGIAgentManager`
- Configuration via `AGIAgentConfig`
- Admin-only dashboard at `AGIAgentDashboardView`

### Agent Categories
1. **Money Maker Agents** (5 active):
   - DynamicPricingAgent
   - AdPlacementAgent
   - FraudDetectionAgent
   - UpsellAgent
   - MatchFairnessAgent

2. **Growth Agents** (4 planned):
   - ViralPredictionEngine
   - RetentionOptimizer
   - SEODiscoveryBooster
   - ThumbnailABTesting

3. **Gaming Agents** (5 planned):
   - MatchOrchestrator
   - PrizePoolManager
   - AntiCheatGuardian
   - TournamentScheduler
   - LeaderboardCalculator

4. **Safety Agents** (5 planned):
   - ContentModerationAI
   - CopyrightProtector
   - SpamDestroyer
   - ToxicityFilter
   - RealtimeReportHandler

5. **Analytics Agents** (5 planned):
   - CreatorAnalyticsPro
   - AudienceInsightsAgent
   - RevenueAttributionAI
   - TrendForecaster
   - CompetitorIntelligence

6. **Scale Agents** (6 planned):
   - CDNOptimizer
   - DatabasePerformanceMonitor
   - AutoScaler
   - BandwidthManager
   - CacheOptimizer
   - LoadBalancer

### Agent Pattern
```swift
@MainActor
class CustomAgent: ObservableObject {
    static let shared = CustomAgent()
    @Published var isActive = false
    @Published var metrics: AgentMetrics = .empty
    
    private init() {}
    
    func start() async {
        isActive = true
        // Agent logic
    }
    
    func stop() {
        isActive = false
    }
}
```

---

## 💰 MONETIZATION FEATURES

### VS Matches System
- Real money wagers ($1 - $100,000)
- 10% platform fee
- Escrow system via `MoneyEscrowService`
- Categories: Gaming, Views, Likes, Comments, Donations, Creative, Cooking, Music, Dance, Sports
- Match tracking via `VersusMatchService`

### Championship Belt System
- 6 divisions by wager amount:
  - 🥉 Lightweight: $1-$100
  - 🥈 Welterweight: $101-$500
  - 🥇 Middleweight: $501-$1K
  - 💎 Heavyweight: $1K-$5K
  - 👑 Super Heavyweight: $5K-$10K
  - 🔥 Ultra Heavyweight: $10K+
- Rankings per division (Top 15)
- Title defenses every 30 days
- Hall of Fame tracking

### Streamer Awards
- 26 award categories
- 6 ranking tiers (Legendary → Master → Diamond → Platinum → Gold → Silver)
- Points based on: hours, viewers, engagement, subscriptions
- Quarterly + Annual ceremonies
- $50,000 grand prize for Streamer of the Year

### Payment Integration
- Stripe Connect ready (via `MoneyEscrowService`)
- StoreKit for in-app purchases
- Tip system via `TipPaymentService`
- Ad revenue via `AdsService`

---

## 📡 REAL-TIME FEATURES

### WebSocket Patterns
Always use WebSocket for real-time data:
```swift
// ✅ CORRECT:
await RealtimeViewTracker.shared.startTracking(videoId: video.id)
await RealtimeViewTracker.shared.stopTracking()
```

### Real-time Services
- `RealtimeViewTracker`: Live view count updates
- `RealTimeChatService`: Live chat messages
- `LiveStreamHealthChecker`: Stream health monitoring
- `RealtimeAnalyticsWebSocket`: Live analytics dashboard
- `RealtimeRankingAGI`: Dynamic ranking updates

### View Tracking
```swift
// Start tracking when video plays
await RealtimeViewTracker.shared.startTracking(videoId: video.id)

// Stop tracking when user navigates away
await RealtimeViewTracker.shared.stopTracking()

// Get current view count
let count = await RealtimeViewTracker.shared.getViewCount(for: videoId)
```

---

## 🎬 VIDEO FEATURES

### Video Player
- Use `GlobalVideoPlayerManager.shared` for centralized playback
- Support Picture-in-Picture (PiP)
- Mini player for background playback
- Quality selection (240p - 4K)
- Playback speed control
- Chapters support
- Subtitles/captions

### Video Upload Flow
1. `UploadView`: Select video file
2. `PostUploadEditorView`: Add metadata (title, description, thumbnail, category, tags)
3. Upload to Firebase Storage
4. Create Firestore document
5. Trigger transcoding (if needed)
6. Notify user of completion

### Video Processing
- Transcoding via `TranscodingService`
- Thumbnail generation via `ThumbnailCreatorView`
- Quality variants via `VideoCompressionEngineV2`
- CDN delivery via `CDNService`

---

## 🔍 SEARCH & DISCOVERY

### Search Implementation
- `AISearchService`: AI-powered search
- `AdvancedSearchService`: Advanced filtering
- `SearchEngineService`: Core search engine
- Support for: videos, users, playlists, live streams
- Real-time search suggestions
- Search history tracking

### Recommendation Engine
- `PersonalizationEngineV2`: Personalized recommendations
- `CollaborativeFilteringEngine`: User similarity matching
- `ViralityPredictionEngineV3`: Trending prediction
- `EngagementScoringEngine`: Content scoring

---

## 📱 NAVIGATION & TABS

### Main Navigation
```swift
enum Tab: String, CaseIterable {
    case home = "Home"
    case flicks = "Flicks"
    case upload = "Upload"
    case subscriptions = "Subscriptions"
    case profile = "Profile"
}
```

### Deep Linking
- URL Scheme: `mychannel://`
- Patterns:
  - `mychannel://video/{id}`
  - `mychannel://profile/{username}`
  - `mychannel://flicks/{id}`
  - `mychannel://live/{streamId}`
- Handle via `DeepLinkManager`

---

## 🎯 PERFORMANCE OPTIMIZATION

### Image Loading & Caching
Always use optimized image loading:
```swift
// ✅ CORRECT: CachedAsyncImage with memory management
CachedAsyncImage(url: URL(string: video.thumbnailURL)) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failure:
        Image(systemName: "photo")
            .foregroundColor(.gray)
    case .empty:
        ProgressView()
    @unknown default:
        EmptyView()
    }
}
.frame(width: 160, height: 90) // Always set explicit frame
.clipped()

// Alternative with fallback:
MultiSourceAsyncImage(
    url: video.thumbnailURL,
    fallbackURLs: [video.backupThumbnailURL]
)
```

**Image Optimization Rules:**
- Always set explicit frame sizes (don't let images scale infinitely)
- Use `.resizable()` with `.aspectRatio(contentMode:)` for proper scaling
- Implement disk caching for thumbnails (max 500MB)
- Prefetch images for next 3 items in scrolling lists
- Compress images before upload (JPEG 80% quality)
- Use WebP format when possible (smaller file size)
- Clear image cache on memory warning
- Never load full resolution in thumbnails

### List Performance & Optimization
```swift
// ✅ CORRECT: LazyVStack with proper ID and performance optimization
ScrollView {
    LazyVStack(spacing: AppTheme.Spacing.md) {
        ForEach(videos, id: \.id) { video in
            VideoCardView(video: video)
                .id(video.id) // Explicit ID for better diffing
                .onAppear {
                    // Prefetch next page when near bottom
                    if video == videos.suffix(3).first {
                        Task { await viewModel.loadMoreVideos() }
                    }
                }
        }
    }
}
.scrollIndicators(.hidden) // Cleaner look

// ❌ WRONG: Regular VStack loads ALL items at once
VStack { 
    ForEach(videos) { video in
        VideoCardView(video: video) // All 1000+ items in memory!
    }
}
```

**List Performance Rules:**
- Always use `LazyVStack`/`LazyHStack` for 10+ items
- Implement pagination (load 24 items at a time)
- Use `.id()` for stable item identity
- Prefetch 3 items ahead of scroll position
- Implement pull-to-refresh with proper cancellation
- Use `DiffableDataSource` pattern for smooth updates
- Avoid complex calculations in ForEach body
- Cache computed properties that are expensive
- Limit simultaneous image loads to 6 per screen

### Memory Management (Critical!)
```swift
// ✅ CORRECT: Proper memory management in closures
class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    private var loadTask: Task<Void, Never>?
    
    func loadVideos() {
        // Cancel previous task to avoid memory leaks
        loadTask?.cancel()
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            // Use weak self in async closures
            let videos = await fetchVideos()
            await MainActor.run { [weak self] in
                self?.videos = videos
            }
        }
    }
    
    deinit {
        loadTask?.cancel() // Always cancel tasks on deinit
        print("✅ VideoViewModel deallocated")
    }
}

// ❌ WRONG: Retain cycle - view model never deallocates
Task {
    let videos = await fetchVideos()
    self.videos = videos // Strong reference to self
}
```

**Memory Management Rules:**
- Always use `[weak self]` in async closures
- Cancel all `Task` objects in `deinit`
- Remove NotificationCenter observers in `deinit`
- Avoid capturing view models in long-lived closures
- Use `@MainActor.run` for UI updates from background
- Profile with Instruments regularly (Allocations, Leaks)
- Keep view models under 10MB each
- Clear cache when receiving memory warning
- Implement proper deinit logging for debugging
- Use weak delegates to avoid retain cycles

### Network Optimization
```swift
// ✅ CORRECT: Optimized network patterns
class NetworkService {
    static let shared = NetworkService()
    
    // Concurrent request limiter
    private let semaphore = DispatchSemaphore(value: 3)
    
    // Request deduplication
    private var activeRequests: [String: Task<Data, Error>] = [:]
    
    func fetch(url: URL) async throws -> Data {
        let key = url.absoluteString
        
        // Return existing request if in flight
        if let existingTask = activeRequests[key] {
            return try await existingTask.value
        }
        
        // Create new request
        let task = Task {
            defer { activeRequests.removeValue(forKey: key) }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30
            
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        }
        
        activeRequests[key] = task
        return try await task.value
    }
}
```

**Network Optimization Rules:**
- Batch API requests when possible (combine multiple into one)
- Implement request debouncing for search (300ms delay)
- Use pagination (load 24 items at a time)
- Cache responses with `SmartCacheService` (1 hour TTL)
- Use CDN for static assets (thumbnails, videos)
- Implement request deduplication (don't fetch same URL twice)
- Limit concurrent network requests to 3-6
- Use HTTP/2 for multiplexing
- Implement exponential backoff for retries
- Compress request/response with gzip
- Use `.returnCacheDataElseLoad` for cacheable data
- Prefetch critical data on app launch
- Cancel requests when view disappears
- Implement offline mode with local cache fallback

### View Rendering Performance
```swift
// ✅ CORRECT: Optimized view composition
struct VideoCardView: View {
    let video: Video
    
    // Pre-compute expensive values
    private var formattedViews: String {
        video.formattedViewCount // Computed once per init
    }
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Lazy load image
            CachedAsyncImage(url: URL(string: video.thumbnailURL))
                .frame(width: 160, height: 90)
            
            VStack(alignment: .leading, spacing: 4) {
                // Use AttributedString for complex text (faster than multiple Text views)
                Text(video.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                
                Text(formattedViews) // Pre-computed
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .drawingGroup() // Flatten view hierarchy for complex layouts
    }
}

// ❌ WRONG: Recomputes on every render
var body: some View {
    Text("\(calculateComplexValue())") // Recalculates every render!
}
```

**View Rendering Rules:**
- Target 60fps (16ms per frame)
- Keep view hierarchy flat (max 10 levels deep)
- Use `.drawingGroup()` for complex static layouts
- Avoid expensive calculations in `body`
- Pre-compute formatted strings in init or computed properties
- Use `@State` sparingly (only for view-local state)
- Implement `Equatable` for complex views to enable diffing
- Use `GeometryReader` sparingly (causes layout recalculations)
- Avoid nested ScrollViews when possible
- Profile with SwiftUI Instruments regularly

### Video Playback Optimization
```swift
// ✅ CORRECT: Optimized video player
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    func loadVideo(url: URL) {
        // Pre-buffer video
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.preloadsEligibleContentKeys = true
        
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.preferredForwardBufferDuration = 5.0 // Buffer 5 seconds
        
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
    }
    
    deinit {
        // Always clean up
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        print("✅ VideoPlayerManager deallocated")
    }
}
```

**Video Playback Rules:**
- Pre-buffer 5 seconds of video
- Use adaptive bitrate streaming (HLS)
- Implement quality selection (240p-4K)
- Pause other videos when playing new one
- Stop playback when app backgrounded
- Clean up player resources in deinit
- Use picture-in-picture for background play
- Implement seek optimization (thumbnail previews)
- Cache partial video data for instant replay
- Monitor network quality and adjust quality

### App Launch Optimization
```swift
// ✅ CORRECT: Optimized app launch sequence
@main
struct MyChannelApp: App {
    init() {
        // Only critical setup here
        setupFirebase() // <100ms
        setupTheme() // <10ms
        
        // Defer non-critical setup
        DispatchQueue.main.async {
            setupAnalytics()
            setupNotifications()
            prefetchUserData()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Background initialization
                    await performBackgroundSetup()
                }
        }
    }
    
    func performBackgroundSetup() async {
        await checkAuthStatus()
        await loadCachedData()
        await startBackgroundServices()
    }
}
```

**App Launch Rules:**
- Target <400ms to first frame
- Defer non-critical initialization
- Load cached data first, then fetch fresh
- Lazy load services (don't init all on launch)
- Avoid synchronous network calls on launch
- Use splash screen for branding (not loading)
- Prefetch critical user data in background
- Delay analytics/tracking until after UI loads
- Profile launch with Time Profiler instrument
- Test on older devices (iPhone 8, iPhone X)

### Battery & Energy Optimization
- Reduce background task frequency
- Batch network requests to avoid radio wake-ups
- Use lower frame rates for non-critical animations
- Implement intelligent refresh intervals
- Pause expensive operations when battery low
- Use location services efficiently (coarse when possible)
- Disable auto-refresh when on cellular + low battery
- Monitor energy impact with Energy Diagnostics

---

## 🍎 APPLE HUMAN INTERFACE GUIDELINES (HIG)

### Navigation Patterns (Critical!)
```swift
// ✅ CORRECT: Standard iOS navigation patterns
NavigationView {
    List(videos) { video in
        NavigationLink(destination: VideoDetailView(video: video)) {
            VideoRowView(video: video)
        }
    }
    .navigationTitle("Home")
    .navigationBarTitleDisplayMode(.large)
}

// Use tab bar for top-level navigation (5 tabs max)
TabView(selection: $selectedTab) {
    HomeView()
        .tabItem { Label("Home", systemImage: "house") }
        .tag(Tab.home)
}
```

**Navigation Rules:**
- Use `NavigationView` for hierarchical navigation
- Use `TabView` for peer-level top sections (5 max)
- Use sheets for modal presentation
- Use full screen covers for immersive experiences
- Always provide back button navigation
- Support swipe-back gesture
- Never trap users (always provide escape route)
- Use consistent navigation patterns throughout app

### Touch Targets & Spacing
```swift
// ✅ CORRECT: 44pt minimum touch target
Button(action: { /* action */ }) {
    Text("Play")
        .frame(minWidth: 44, minHeight: 44) // Apple minimum
}

// Better: 48pt for better UX
Button(action: { /* action */ }) {
    Text("Subscribe")
        .padding(.horizontal, AppTheme.Spacing.lg)
        .frame(minHeight: 48) // Comfortable touch target
}
```

**Touch Target Rules:**
- Minimum 44x44 pt for all interactive elements
- Recommended 48x48 pt for primary actions
- Space interactive elements 8pt apart minimum
- Make entire row tappable in lists (not just text)
- Provide visual feedback on touch (scale, opacity)
- Support drag gestures where appropriate
- Implement haptic feedback for actions

### Typography & Readability
```swift
// ✅ CORRECT: Dynamic Type support
Text(video.title)
    .font(AppTheme.Typography.headline)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Limit max size
    .lineLimit(2)
    .minimumScaleFactor(0.8) // Allow slight shrinking

// Support accessibility sizes
VStack(alignment: .leading, spacing: 8) {
    Text("Title")
        .font(.headline)
    Text("Description")
        .font(.body)
}
.dynamicTypeSize(...DynamicTypeSize.accessibility3) // Support large text
```

**Typography Rules:**
- Always support Dynamic Type
- Limit maximum text size for layout stability
- Use Apple's text styles (headline, body, caption)
- Maintain minimum 16pt font size for body text
- Line length: 50-75 characters max for readability
- Line height: 1.4-1.6x font size
- Left-align text (easier to read)
- Use proper contrast ratios (4.5:1 for body text)

### Color & Contrast (Accessibility)
```swift
// ✅ CORRECT: Semantic colors with dark mode support
struct AppTheme {
    static let primary = Color("AccentColor") // Adapts to dark mode
    static let background = Color(.systemBackground) // Auto dark mode
    static let textPrimary = Color(.label) // Auto contrast
    static let textSecondary = Color(.secondaryLabel)
}

// Test contrast ratios
// Body text: 4.5:1 minimum
// Large text (18pt+): 3:1 minimum
// Interactive elements: 3:1 minimum
```

**Color & Contrast Rules:**
- Support dark mode everywhere
- Use semantic system colors when possible
- Maintain 4.5:1 contrast for normal text
- Maintain 3:1 contrast for large text (18pt+)
- Never rely on color alone for information
- Use SF Symbols that adapt to color schemes
- Test with Color Blindness simulator
- Provide high contrast mode option

### Gestures & Interactions
```swift
// ✅ CORRECT: Standard iOS gestures
ScrollView {
    // Pull to refresh
    RefreshableView(videos: $videos)
}
.refreshable {
    await loadVideos()
}

// Swipe actions
List {
    ForEach(videos) { video in
        VideoRow(video: video)
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) { }
                Button("Share") { }
            }
    }
}

// Long press context menu
VideoCard(video: video)
    .contextMenu {
        Button("Save", systemImage: "square.and.arrow.down") { }
        Button("Share", systemImage: "square.and.arrow.up") { }
        Button("Report", systemImage: "flag") { }
    }
```

**Gesture Rules:**
- Support standard iOS gestures (tap, swipe, pinch, long press)
- Implement pull-to-refresh for list views
- Use swipe actions for quick list item actions
- Provide context menus for secondary actions
- Support pinch-to-zoom for images/videos
- Implement drag-and-drop where appropriate
- Never override system gestures (swipe-back, etc.)
- Provide haptic feedback for gesture actions

### Animations & Transitions
```swift
// ✅ CORRECT: Smooth, purposeful animations
withAnimation(AppTheme.AnimationPresets.spring) {
    isExpanded.toggle()
}

// Match system animation timing
.transition(.move(edge: .trailing).combined(with: .opacity))
.animation(.easeInOut(duration: 0.3), value: showDetail)

// Respect reduce motion accessibility setting
@Environment(\.accessibilityReduceMotion) var reduceMotion

if reduceMotion {
    // Instant transition
    showView = true
} else {
    // Animated transition
    withAnimation { showView = true }
}
```

**Animation Rules:**
- Keep animations under 400ms
- Use spring animations for interactive elements
- Ease-in-out for state changes
- Respect "Reduce Motion" accessibility setting
- Animate changes, not constant loops
- Match animation timing to user expectations
- Provide feedback animations for actions (buttons, etc.)
- Never animate critical information away

---

## ♿ ACCESSIBILITY (WCAG 2.1 AA Compliance)

### VoiceOver Support
```swift
// ✅ CORRECT: Full VoiceOver support
Button(action: likeVideo) {
    Image(systemName: isLiked ? "heart.fill" : "heart")
}
.accessibilityLabel(isLiked ? "Unlike video" : "Like video")
.accessibilityHint("Double tap to \(isLiked ? "remove like" : "like this video")")
.accessibilityValue("\(video.likeCount) likes")
.accessibilityAddTraits(.isButton)

// Complex view accessibility
VideoCard(video: video)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(video.title) by \(video.creator.displayName)")
    .accessibilityValue("\(video.formattedViewCount) views, \(video.formattedDuration)")
    .accessibilityHint("Double tap to watch video")
```

**VoiceOver Rules:**
- Add `.accessibilityLabel()` to all interactive elements
- Provide `.accessibilityHint()` for non-obvious actions
- Use `.accessibilityValue()` for current state
- Combine related elements with `.accessibilityElement(children: .combine)`
- Add `.accessibilityAddTraits()` for element type
- Test with VoiceOver enabled (Cmd+F5)
- Support custom rotor actions for power users
- Provide skip navigation options

### Keyboard Navigation & Switch Control
```swift
// ✅ CORRECT: Full keyboard support
TextField("Search videos", text: $searchText)
    .focused($isSearchFocused)
    .onSubmit {
        performSearch()
    }
    .submitLabel(.search)

// Support tab navigation
VideoCard(video: video)
    .focusable(true)
    .onTapGesture { playVideo() }
```

**Keyboard & Switch Control Rules:**
- Support tab key navigation
- Highlight focused elements clearly
- Support return/enter for actions
- Provide keyboard shortcuts for common actions
- Test with Switch Control enabled
- Support external keyboard on iPad
- Focus should be visible and logical

### Dynamic Type & Text Scaling
```swift
// ✅ CORRECT: Full Dynamic Type support
Text(video.title)
    .font(.headline)
    .lineLimit(2)
    .minimumScaleFactor(0.8)
    .dynamicTypeSize(.xSmall ... .accessibility3)

// Adjust layout for large text
@Environment(\.sizeCategory) var sizeCategory

var body: some View {
    if sizeCategory.isAccessibilityCategory {
        VStack { /* Vertical layout for large text */ }
    } else {
        HStack { /* Horizontal layout for normal text */ }
    }
}
```

**Dynamic Type Rules:**
- Support all Dynamic Type sizes
- Test at largest accessibility sizes
- Adjust layouts for large text (stack vertically)
- Set sensible maximum sizes to prevent layout breaks
- Never use fixed font sizes
- Allow text truncation gracefully
- Provide scroll if text doesn't fit

---

## 📱 APP STORE COMPLIANCE & REVIEW GUIDELINES

### App Store Review Guidelines
```swift
// ✅ Required: App Store compliance checks

// 1. Guideline 2.1: App Completeness
// - All features must work
// - No placeholder content
// - No "Coming Soon" buttons that don't work
// - Test on actual devices before submission

// 2. Guideline 2.3: Accurate Metadata
// - Screenshots show actual app
// - Description matches functionality
// - All features mentioned are implemented
// - Privacy policy is accessible

// 3. Guideline 4.2: Minimum Functionality
// - App provides substantial value
// - Not just a website wrapper
// - Offers unique features
// - Professional UI/UX

// 4. Guideline 5.1: Privacy
// - Privacy policy required
// - Data collection disclosed
// - User consent for data collection
// - Data deletion on request
```

### Privacy Manifest (Required iOS 17+)
```swift
// ✅ REQUIRED: PrivacyInfo.xcprivacy file
// Include all APIs that access user data:
// - UserDefaults
// - File timestamp APIs
// - System boot time APIs
// - Disk space APIs
// - Active keyboard APIs
// - User defaults APIs

// Track all third-party SDKs and their privacy impact
// Declare all tracking domains
// List all data types collected
```

**Privacy Requirements:**
- Create PrivacyInfo.xcprivacy manifest
- Declare all data collection
- Provide privacy policy URL
- Request user consent via App Tracking Transparency
- Allow users to delete their data
- Support sign-in with Apple if offering social login
- Encrypt sensitive data
- Don't access clipboard without user action
- Don't collect data from kids under 13 (COPPA)

### In-App Purchases & Monetization
```swift
// ✅ CORRECT: StoreKit 2 implementation
@MainActor
class StoreKitService: ObservableObject {
    @Published var purchasedProducts: [Product] = []
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            
        case .userCancelled:
            break
            
        case .pending:
            break
            
        @unknown default:
            break
        }
    }
}
```

**Monetization Rules:**
- Use StoreKit for all in-app purchases (Apple's 30% cut)
- Don't bypass App Store payment system
- Clearly disclose auto-renewing subscriptions
- Easy cancellation for subscriptions
- Restore purchases functionality required
- Test purchase flows thoroughly
- Handle all edge cases (cancelled, pending, failed)
- For real money gaming: Get proper licenses, implement age verification
- Display odds for loot boxes/random items

### Content Guidelines
```swift
// ✅ REQUIRED: Content moderation
// Guideline 1.1: Objectionable Content
// - No hate speech
// - No violence or harm
// - No pornographic content
// - No illegal activity promotion
// - No harassment or bullying

// Guideline 1.2: User Generated Content
// - Must moderate UGC
// - Report mechanism for inappropriate content
// - Block abusive users
// - Filter profanity
// - Age-gate mature content
```

**Content Moderation Requirements:**
- AI content moderation (ContentModerationService)
- User reporting system
- Block/mute functionality
- Age restrictions for mature content
- COPPA compliance for kids content
- Respond to abuse reports within 24 hours
- Remove illegal content immediately

### TestFlight & App Review
```swift
// ✅ TESTFLIGHT CHECKLIST:
// 1. Enable all features (no debug/staging-only features)
// 2. Remove all placeholder content
// 3. Test on real devices (iPhone + iPad)
// 4. Test all payment flows in Sandbox
// 5. Provide demo account credentials in App Review Notes
// 6. Respond to reviewer questions within 24 hours
// 7. Don't mention beta/unreleased features
// 8. Ensure privacy policy is accessible
// 9. Test sign-in flows thoroughly
// 10. Verify all external links work
```

---

## 🤖 AGI AGENT BUILDING PATTERNS

### Complete AGI Agent Template
```swift
import Foundation
import Combine

// ✅ CORRECT: Full AGI agent pattern
@MainActor
final class CustomAGIAgent: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CustomAGIAgent()
    private init() {
        setupAgent()
    }
    
    // MARK: - Published State
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var lastRunTime: Date?
    @Published var errorCount: Int = 0
    
    // MARK: - Configuration
    let config: AGIAgentConfig = .init(
        id: "custom-agi-agent",
        name: "Custom AGI Agent",
        description: "Handles specific automation task",
        category: .moneyMaker, // or .growth, .gaming, .safety, .analytics, .scale
        priority: .high,
        runInterval: 300, // 5 minutes
        requiresNetwork: true,
        requiresAuth: true
    )
    
    // MARK: - Private State
    private var runTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = OperationQueue()
    
    // MARK: - Agent Lifecycle
    func start() async {
        guard !isActive else { return }
        
        isActive = true
        status = .running
        metrics.startTime = Date()
        
        print("✅ [\(config.name)] Agent started")
        
        // Start agent loop
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
        
        print("🛑 [\(config.name)] Agent stopped")
    }
    
    func pause() {
        isActive = false
        status = .paused
        
        print("⏸️ [\(config.name)] Agent paused")
    }
    
    func resume() async {
        guard status == .paused else { return }
        await start()
    }
    
    // MARK: - Agent Logic
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                // Run agent logic
                try await performAgentTask()
                
                // Update metrics
                metrics.successCount += 1
                metrics.lastSuccessTime = Date()
                lastRunTime = Date()
                
                // Wait for next run
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
                
            } catch {
                handleError(error)
                
                // Exponential backoff on error
                let backoff = min(pow(2.0, Double(errorCount)), 300)
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }
    }
    
    // MARK: - Core Agent Task
    private func performAgentTask() async throws {
        // 1. Gather data
        let data = try await gatherData()
        
        // 2. Process with AI/logic
        let result = try await processData(data)
        
        // 3. Take action
        try await executeAction(result)
        
        // 4. Update metrics
        updateMetrics(result)
    }
    
    // MARK: - Data Gathering
    private func gatherData() async throws -> AgentData {
        // Fetch relevant data from services
        // Examples:
        // - Video performance metrics
        // - User behavior data
        // - Market conditions
        // - Competitor analysis
        
        return AgentData()
    }
    
    // MARK: - Data Processing
    private func processData(_ data: AgentData) async throws -> AgentResult {
        // Process data with AI or algorithms
        // Examples:
        // - Run ML model
        // - Calculate optimization
        // - Detect patterns
        // - Make predictions
        
        return AgentResult()
    }
    
    // MARK: - Action Execution
    private func executeAction(_ result: AgentResult) async throws {
        // Take automated action based on results
        // Examples:
        // - Adjust pricing
        // - Optimize ad placement
        // - Send notifications
        // - Update rankings
        
        print("✅ [\(config.name)] Action executed: \(result.action)")
    }
    
    // MARK: - Metrics & Monitoring
    private func updateMetrics(_ result: AgentResult) {
        metrics.totalRuns += 1
        metrics.revenue += result.revenueImpact
        metrics.impressions += result.impressions
        metrics.avgResponseTime = calculateAvgResponseTime()
    }
    
    private func calculateAvgResponseTime() -> TimeInterval {
        guard let startTime = metrics.startTime else { return 0 }
        let totalTime = Date().timeIntervalSince(startTime)
        return totalTime / Double(metrics.totalRuns)
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        metrics.lastErrorTime = Date()
        metrics.lastError = error.localizedDescription
        
        print("🚨 [\(config.name)] Error: \(error.localizedDescription)")
        
        // Auto-disable if too many errors
        if errorCount >= 10 {
            stop()
            status = .error("Too many consecutive errors")
            
            // Notify admins
            Task {
                await notifyAdmins(error: error)
            }
        }
    }
    
    // MARK: - Admin Notifications
    private func notifyAdmins(error: Error) async {
        // Send alert to admin dashboard
        await NotificationManager.shared.sendAdminAlert(
            title: "\(config.name) Failed",
            message: "Agent stopped after multiple errors: \(error.localizedDescription)",
            priority: .high
        )
    }
    
    // MARK: - Setup
    private func setupAgent() {
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = config.priority == .high ? .userInitiated : .utility
        
        // Register with AGIAgentManager
        AGIAgentManager.shared.registerAgent(self)
    }
    
    // MARK: - Cleanup
    deinit {
        runTask?.cancel()
        cancellables.removeAll()
        print("✅ [\(config.name)] Agent deallocated")
    }
}

// MARK: - Supporting Models
struct AgentData {
    var videos: [Video] = []
    var users: [User] = []
    var metrics: [String: Any] = [:]
}

struct AgentResult {
    var action: String = ""
    var revenueImpact: Double = 0
    var impressions: Int = 0
    var confidence: Double = 0
}

struct AgentMetrics {
    var startTime: Date?
    var lastSuccessTime: Date?
    var lastErrorTime: Date?
    var totalRuns: Int = 0
    var successCount: Int = 0
    var errorCount: Int = 0
    var revenue: Double = 0
    var impressions: Int = 0
    var avgResponseTime: TimeInterval = 0
    var lastError: String?
    
    static let empty = AgentMetrics()
}

enum AgentStatus: Equatable {
    case idle
    case running
    case paused
    case stopped
    case error(String)
}
```

**AGI Agent Rules:**
- Always use `@MainActor` for ObservableObject agents
- Implement singleton pattern (`static let shared`)
- Cancel all tasks in `deinit`
- Use exponential backoff for retries
- Log all actions with emoji indicators
- Update metrics after each run
- Notify admins on critical errors
- Register with `AGIAgentManager`
- Support start/stop/pause/resume
- Run on configurable intervals
- Handle network failures gracefully
- Implement circuit breaker pattern (auto-disable after failures)

---

## 🔐 SECURITY & PRIVACY

### Authentication Security
- Always use HTTPS for API calls
- Implement SSL pinning via `SSLPinningDelegate`
- Store sensitive data in Keychain via `KeychainHelper`
- Never log sensitive information (passwords, tokens, API keys)
- Use biometric auth when available

### Data Privacy
- COPPA compliance via `COPPAComplianceService`
- Age restrictions on content
- Parental controls for kids section
- Privacy settings in `SettingsView`
- User data export/deletion support

### Content Moderation
- AI moderation via `ContentModerationService`
- Deepfake detection via `AIDeepfakeDetectionEngine`
- Sentiment analysis via `AISentimentAnalysisEngine`
- User reporting system
- Content ID matching via `ContentIDService`

---

## 🧪 TESTING & DEBUGGING

### SwiftUI Previews
Always include previews:
```swift
#Preview("Video Card") {
    VideoCardView(video: Video.sampleVideos[0])
        .padding()
        .background(AppTheme.Colors.background)
}

#Preview("Video Card - Dark Mode") {
    VideoCardView(video: Video.sampleVideos[0])
        .padding()
        .preferredColorScheme(.dark)
}
```

### Debug Logging
Use proper logging levels:
```swift
print("✅ Success: Video uploaded")
print("📺 Info: Fetching videos for user \(userId)")
print("⚠️ Warning: View count mismatch")
print("🚨 Error: Failed to upload: \(error)")
print("🔥 Firebase: Document created with ID: \(docId)")
print("💰 Payment: Transaction completed: \(amount)")
```

### Mock Data
- Use `AppConfig.Features.enableMockData` to toggle mock data
- Sample data in model extensions: `Video.sampleVideos`, `User.sampleUsers`
- Mock services for testing without backend

---

## 📦 DEPENDENCIES & IMPORTS

### Common Imports
```swift
import SwiftUI
import Combine

// Firebase
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

// Foundation
import Foundation
import AVFoundation // For video/audio
import AVKit // For video player
import Photos // For photo library
import StoreKit // For in-app purchases
```

### External APIs Used
- Firebase (Auth, Firestore, Storage, Analytics)
- Google Cloud (Vertex AI, Cloud Run, API Gateway)
- Anthropic (Claude Sonnet 4.5)
- OpenAI (GPT-4)
- Stripe (Payments)
- TMDB (Movies)
- Archive.org (Free content)
- YouTube Data API (Content enrichment)

---

## 📂 FILE STRUCTURE

### Directory Organization
```
MyChannel/
├── Core/
│   ├── AI/               # AGI agents (30 total)
│   ├── Authentication/   # Auth managers
│   ├── Components/       # Reusable UI components
│   ├── Config/          # AppConfig, AppSecrets
│   ├── Extensions/      # Swift extensions
│   ├── Managers/        # System managers
│   ├── Models/          # Data models
│   ├── Navigation/      # Navigation logic
│   ├── Networking/      # API clients
│   ├── Performance/     # Performance monitoring
│   ├── Services/        # Business logic (177+ services)
│   ├── Theme/           # AppTheme
│   └── Utilities/       # Helper utilities
│
├── Features/            # Feature modules
│   ├── Home/           # Home feed
│   ├── Flicks/         # Short-form video (Shorts)
│   ├── Upload/         # Video upload
│   ├── Player/         # Video player
│   ├── Profile/        # User profiles
│   ├── Studio/         # Creator Studio
│   ├── Gaming/         # Gaming & VS Matches
│   ├── LiveStreaming/  # Live streams & Awards
│   ├── Monetization/   # Revenue features
│   ├── Shopping/       # Live shopping
│   ├── University/     # MyChannel University
│   ├── Movies/         # Movies section
│   ├── Music/          # Music section
│   ├── AI/             # AI features & dashboard
│   └── ...             # 30+ feature modules
│
└── Assets.xcassets/    # Images, icons, colors
```

### Feature Module Structure
Each feature should follow:
```
Features/FeatureName/
├── FeatureNameView.swift        # Main view
├── FeatureNameViewModel.swift   # View model
├── FeatureNameModels.swift      # Feature-specific models
├── FeatureNameService.swift     # Feature-specific service
├── Components/                  # Feature-specific components
└── Views/                       # Sub-views
```

---

## 🎯 ADMIN & OWNER FEATURES

### Owner Profile
Owner emails (admin access):
- `keontapeat@mychannel.live`
- `keontapeat@gmail.com`

### Admin-Only Features
- AGI Agent Dashboard (`AGIAgentDashboardView`)
- Featured Video Management (`FeaturedVideoAdminView`)
- User Seeding Controls
- Analytics Backend Controls
- System Monitoring Dashboard

### Owner Profile Customization
- Custom banner video support
- Featured video slots (6 slots)
- Special badges/verification
- Priority support access

---

## 🚀 DEPLOYMENT & BUILD

### Build Configurations
- **Debug**: Development with mock data, verbose logging
- **Staging**: Testing with real backend, reduced logging
- **Production**: App Store release, analytics enabled

### TestFlight Checklist
- Disable mock data (`AppConfig.Features.enableMockData = false`)
- Enable analytics and crash reporting
- Test all critical user flows
- Verify payment flows (Sandbox)
- Check App Store metadata
- Test on multiple devices/iOS versions

### App Store Optimization
- Screenshots for all device sizes
- Localized metadata (English, Spanish, etc.)
- Keywords: video platform, streaming, content creation, live streaming, gaming
- Category: Photo & Video
- Age Rating: 12+ (due to user-generated content)

---

## 💡 CODING PHILOSOPHY

### Code Quality
- **Readable**: Write code humans can understand
- **Maintainable**: Future you should understand it 6 months later
- **Testable**: Design for testability
- **Documented**: Add comments for complex logic
- **Consistent**: Follow established patterns

### Performance First
- Optimize for 60fps UI
- Lazy load everything possible
- Cache aggressively
- Measure before optimizing (use Instruments)
- Profile on real devices, not simulators

### User Experience
- Instant feedback on actions
- Smooth animations (use `AppTheme.AnimationPresets`)
- Loading states for async operations
- Error messages that help users
- Accessibility for all users
- Support dark mode everywhere

---

## 🔥 COMMON PATTERNS TO FOLLOW

### Async/Await Pattern
```swift
func fetchData() async throws -> [Item] {
    // ✅ CORRECT: async/await
    let data = try await service.fetch()
    return data
}

// ❌ WRONG: Completion handlers
func fetchData(completion: @escaping (Result<[Item], Error>) -> Void) {
    // Don't use this pattern
}
```

### Error Handling
```swift
do {
    let result = try await riskyOperation()
    // Success path
} catch {
    print("🚨 Error: \(error.localizedDescription)")
    // Show user-friendly error
    errorMessage = "Something went wrong. Please try again."
}
```

### State Management
```swift
@MainActor
final class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await service.fetchItems()
        } catch {
            self.error = error
        }
    }
}
```

### Service Singleton Pattern
```swift
@MainActor
final class MyService: ObservableObject {
    static let shared = MyService()
    private init() {}
    
    @Published var state: ServiceState = .idle
    
    func doSomething() async throws {
        // Implementation
    }
}
```

---

## 📝 DOCUMENTATION STANDARDS

### Code Comments
```swift
// MARK: - Section Name
// Use MARK for organizing code sections

// TODO: Implement feature X
// FIXME: Bug in edge case Y
// NOTE: Important context about Z

/// Documentation comment for public APIs
/// - Parameter videoId: The unique identifier for the video
/// - Returns: An array of related videos
/// - Throws: NetworkError if request fails
func fetchRelatedVideos(videoId: String) async throws -> [Video] {
    // Implementation
}
```

### File Headers
```swift
//
//  FileName.swift
//  MyChannel
//
//  Created by [Name] on [Date].
//

import SwiftUI
```

---

## ⚠️ COMMON MISTAKES TO AVOID

### ❌ DON'T DO THESE:

1. **Don't hardcode strings**
   ```swift
   // ❌ WRONG
   Text("Watch video")
   
   // ✅ CORRECT
   Text("Watch video") // OK for UI labels
   let endpoint = AppConfig.API.Endpoints.videos // For config
   ```

2. **Don't use force unwrapping**
   ```swift
   // ❌ WRONG
   let url = URL(string: urlString)!
   
   // ✅ CORRECT
   guard let url = URL(string: urlString) else { return }
   ```

3. **Don't block the main thread**
   ```swift
   // ❌ WRONG
   func fetchVideos() {
       let data = URLSession.shared.dataTask(...)
   }
   
   // ✅ CORRECT
   func fetchVideos() async throws -> [Video] {
       let (data, _) = try await URLSession.shared.data(from: url)
       return try decoder.decode([Video].self, from: data)
   }
   ```

4. **Don't create massive view files**
   - Keep views under 300 lines
   - Extract subviews into separate files
   - Use view composition

5. **Don't ignore memory leaks**
   - Always use `[weak self]` in closures that capture self
   - Cancel async tasks when view disappears
   - Remove notification observers

---

## 🎊 QUICK REFERENCE

### Most Used Services
- `AppState.shared` - Global app state
- `AuthenticationManager.shared` - User authentication
- `VideoFirestoreService.shared` - Video CRUD
- `UserFirestoreService.shared` - User CRUD
- `RealtimeViewTracker.shared` - Live view tracking
- `GlobalVideoPlayerManager.shared` - Video playback
- `AGIAgentManager.shared` - AGI agent control
- `MoneyEscrowService.shared` - Payment escrow

### Most Used Models
- `Video` - Video content
- `User` - User/creator profile
- `VideoCategory` - Content categories
- `VideoQuality` - Quality settings
- `LiveTVChannel` - Live stream channels
- `FeaturedVideoRequest` - Featured video system

### Most Used Views
- `HomeView` - Main feed
- `VideoDetailView` - Video player page
- `ProfileView` - User profile
- `ComprehensiveCreatorStudioView` - Creator dashboard
- `ChampionshipHubView` - VS matches & belts
- `LiveStreamerAwardsView` - Streamer awards
- `AGIAgentDashboardView` - Admin AGI control

---

## 🏁 FINAL NOTES

This is MyChannel - the most advanced video platform combining:
- **YouTube**: Content library, video hosting, discovery
- **Twitch**: Live streaming, chat, streamer awards
- **DraftKings**: Real money VS matches, betting, escrow
- **UFC**: Championship belts, rankings, title defenses
- **30 AGI agents**: Intelligent automation everywhere
- **Real-time everything**: Live views, chat, analytics

**Platform Focus:**
- ✅ Video hosting & streaming
- ✅ Real money competitions ($1-$100K wagers)
- ✅ Championship belt system (6 divisions)
- ✅ Streamer awards ($50K prizes)
- ✅ Creator monetization
- ✅ Live streaming & chat
- ❌ NO AI video/image generation (that's Parachute/Gekko)

**Build fast. Build smart. Build premium.**

Code like a senior engineer. Ship like a startup. Scale like YouTube.

---

## 📋 WHAT THESE RULES GIVE YOU

### ⚡ **Instant Senior-Level Code Generation**
When you ask Cursor to build something, it will:
- ✅ Follow your EXACT patterns (MVVM, services, Firebase)
- ✅ Use AppTheme everywhere automatically  
- ✅ Implement proper memory management (`[weak self]`, deinit cleanup)
- ✅ Add full accessibility (VoiceOver, Dynamic Type)
- ✅ Support dark mode out of the box
- ✅ Handle performance optimization (lazy loading, caching)
- ✅ Include proper error handling with logging
- ✅ Follow Apple HIG guidelines
- ✅ Pass App Store review requirements
- ✅ Build production-ready AGI agents

### 🎯 **What Makes These Rules Special**
**Performance:** Image caching, list optimization, memory management, network batching
**UX/UI:** Apple HIG, touch targets, gestures, animations, typography
**Accessibility:** VoiceOver, keyboard navigation, Dynamic Type, WCAG 2.1 AA
**App Store:** Privacy manifest, review guidelines, monetization, content moderation
**AGI Agents:** Complete template with lifecycle, metrics, error handling, admin alerts
**Firebase:** Proper imports, Firestore patterns, real-time updates, auth persistence
**Security:** SSL pinning, Keychain storage, biometric auth, data privacy

### 🔥 **Before vs After**

**BEFORE (no rules):**
```
You: "Create a video list view"
Cursor: *Creates basic VStack with hardcoded colors*
You: "No use LazyVStack"
You: "No use AppTheme colors"
You: "No add accessibility"
You: "No support dark mode"
```

**AFTER (with these rules):**
```
You: "Create a video list view"
Cursor: *Creates perfect LazyVStack with:*
  ✅ AppTheme colors & typography
  ✅ Proper lazy loading & pagination
  ✅ Full accessibility labels
  ✅ Dark mode support
  ✅ Pull-to-refresh
  ✅ Error handling
  ✅ Memory management
  ✅ SwiftUI preview
```

### 💰 **Value of These Rules**
- **Speed:** 10x faster development (no back-and-forth corrections)
- **Quality:** Senior iOS engineer level code every time
- **Consistency:** All 521 files follow same patterns
- **App Store:** Pass review first time (no rejections)
- **Performance:** 60fps smooth, optimized from day 1
- **Accessibility:** WCAG 2.1 AA compliant (legally required)
- **Scale:** Ready for millions of users

**You just saved yourself $200K+ in senior iOS engineer salary! 💸**

Let's build the next billion-dollar platform! 🚀

---

## 🎨 YOUTUBE-LEVEL DESIGN STANDARDS (CRITICAL!)

### ⚠️ **NO "COLOR KID SHIT" OR UGLY PLACEMENTS**

**Every design decision must match YouTube's professional, polished aesthetic.**

### Core Design Philosophy
1. **Minimal & Clean** - No unnecessary elements, clutter, or "busy" designs
2. **Consistent Spacing** - Use AppTheme spacing constants (xs, sm, md, lg, xl)
3. **Subtle Animations** - Smooth, purposeful animations (spring, easeInOut)
4. **Professional Typography** - System fonts, proper weights, clear hierarchy
5. **Neutral Color Palette** - Grays, whites, subtle accents (no bright "kid colors")
6. **Proper Alignment** - Everything aligned, no random placements
7. **Touch Targets** - Minimum 44pt, comfortable 48pt
8. **Visual Hierarchy** - Clear primary/secondary/tertiary information levels

### Color Usage Rules
```swift
// ✅ CORRECT: Professional colors
AppTheme.Colors.primary      // For buttons, links, active states
AppTheme.Colors.textPrimary  // Main text
AppTheme.Colors.textSecondary // Secondary text
AppTheme.Colors.surface      // Cards, inputs
Color.red                    // Errors ONLY
Color.green                  // Success ONLY

// ❌ WRONG: "Color Kid Shit"
Color.pink, Color.purple, Color.orange  // Too playful
Random bright colors                     // Unprofessional
Multiple colors competing               // Cluttered
```

### Spacing Rules
```swift
// ✅ CORRECT: YouTube-level spacing
VStack(spacing: 20) { }  // Between major sections
VStack(spacing: 16) { }  // Within cards
VStack(spacing: 12) { }  // Between list items
HStack(spacing: 8) { }   // Related elements

// ❌ WRONG: Random spacing
VStack(spacing: 23) { }  // Random numbers
VStack(spacing: 5) { }   // Too tight
```

### Component Design Rules
```swift
// ✅ CORRECT: Professional input field
TextField("Placeholder", text: $text)
    .font(.system(size: 15, weight: .regular))
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
        RoundedRectangle(cornerRadius: 10)
            .fill(AppTheme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
            )
    )

// ✅ CORRECT: Professional button
Button(action: { }) {
    Text("Action")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(AppTheme.Colors.primary)
        )
}

// ✅ CORRECT: Professional tag chip
HStack(spacing: 6) {
    Text(tag)
        .font(.system(size: 14, weight: .medium))
    Image(systemName: "xmark")
        .font(.system(size: 11, weight: .semibold))
}
.padding(.horizontal, 12)
.padding(.vertical, 7)
.background(
    Capsule()
        .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
)
.foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
```

### Typography Rules
```swift
// ✅ CORRECT: Professional typography
.font(.system(size: 18, weight: .semibold))  // Section headers
.font(.system(size: 16, weight: .semibold))  // Subsection headers
.font(.system(size: 15, weight: .regular))   // Primary text
.font(.system(size: 14, weight: .regular))   // Secondary text
.font(.system(size: 13, weight: .medium))    // Tertiary text
.font(.system(size: 12, weight: .regular))   // Captions

// ❌ WRONG: Inconsistent typography
// Random font sizes, too many weights, playful fonts
```

### Animation Rules
```swift
// ✅ CORRECT: Professional animations
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
    // State change
}
.animation(.easeInOut(duration: 0.2), value: isFocused)

// ❌ WRONG: Over-the-top animations
// Bouncy, playful, too fast/slow, multiple competing animations
```

### Design Anti-Patterns (NEVER DO)
- ❌ Bright pink, purple, orange buttons
- ❌ Rainbow color schemes
- ❌ Random element positions
- ❌ Inconsistent spacing
- ❌ Overlapping elements
- ❌ Cluttered layouts
- ❌ Bouncy, playful animations
- ❌ Comic sans or playful fonts
- ❌ Too many icons competing
- ❌ Inconsistent icon sizes

### YouTube Design Checklist
Before shipping any UI component:
- [ ] Uses AppTheme colors (no random colors)
- [ ] Consistent spacing (AppTheme spacing constants)
- [ ] Proper typography hierarchy
- [ ] Clean, minimal design (no clutter)
- [ ] Subtle, professional animations
- [ ] Proper alignment (everything aligned)
- [ ] Touch targets minimum 44pt
- [ ] Visual hierarchy clear
- [ ] Dark mode support
- [ ] No "color kid shit"
- [ ] No ugly placements
- [ ] Professional, sleek, modern

**See `YOUTUBE_DESIGN_STANDARDS.md` for complete design guidelines.**

