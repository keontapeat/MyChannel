---
inclusion: fileMatch
fileMatchPattern: ['**/*.swift', 'MyChannel/**', 'MyChannelTV/**', 'MyChannelTests/**', 'MyChannelUITests/**']
---

# iOS / SwiftUI Standards

Applies when working in the iOS app (`MyChannel/`, `MyChannelTV/`) or any `.swift` file.

## Language & Frameworks
- Swift 5.9+, SwiftUI, iOS 15+ deployment target, Xcode 15+.
- Prefer `struct` over `class` for models and views. Use protocol-oriented design for shared behavior.
- Use `async/await` for all async work — no completion handlers.
- Use `@MainActor` on `ObservableObject` classes that drive UI.
- Use the right property wrappers: `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `@State`, `@Binding`.
- Use `Result<Success, Error>` for fallible operations; Combine only where it genuinely fits.

## Naming
- Types: PascalCase. Properties/functions/constants: camelCase.
- Booleans: prefix `is`/`has`/`should`. Functions: verbs (`fetchVideos()`).
- Enum cases: camelCase.

## Architecture
- MVVM: Model (`Identifiable, Codable, Hashable`) → `@MainActor final class XViewModel: ObservableObject` → View.
- Services are singletons: `static let shared = ServiceName()` with `private init() {}`, `@MainActor` if they publish UI state, async methods, proper `do/catch`.

## Firebase
- Guard imports: `#if canImport(FirebaseFirestore) ... #endif`, and check `FirebaseApp.app() != nil` before using Auth.
- Firestore collections: lowercase-with-hyphens. Use `FieldValue.serverTimestamp()` for timestamps. Use snapshot listeners for live data and batch writes for multi-doc updates.

## Theming — Always Use AppTheme
- Colors: `AppTheme.Colors.*`; Typography: `AppTheme.Typography.*`; Spacing: `AppTheme.Spacing.*`; CornerRadius: `AppTheme.CornerRadius.*`; Animations: `AppTheme.AnimationPresets.*`.
- Don't hardcode `.black`, `.headline`, `padding(16)`, etc. Use the theme constants and view modifiers (`.cardStyle()`, `.primaryButtonStyle()`, etc.).

## Config & Secrets
- App settings via `AppConfig` (`.environment`, `.Features.*`, `.Video.*`, `.API.*`, `.UI.*`).
- Secrets via `AppSecrets` only — never hardcode keys.

## Video Playback (YouTube parity — required)
- Centralize via `GlobalVideoPlayerManager.shared`.
- Dual playback: in-app `FloatingMiniPlayer` plus native iOS PiP when leaving the app (`AppState.autoPiPEnabled` gates auto-PiP). Fall back to audio-only `BackgroundPlayService` if PiP is unavailable.
- Background playback is required: configure `AVAudioSession` with `.playback`, keep Remote Command Center controls working, let users disable background play in Settings.
- Pre-buffer ~5s, adaptive bitrate (HLS), quality selection 240p–4K, clean up player resources in `deinit`.

## Performance & Memory
- `LazyVStack`/`LazyHStack` for 10+ items, paginate (24 at a time), prefetch ~3 ahead, stable `.id()`.
- Use `[weak self]` in async closures; cancel `Task`s and remove observers in `deinit`.
- `CachedAsyncImage` with explicit frames; never load full-res in thumbnails.
- Target 60fps; keep view hierarchy shallow; precompute expensive values outside `body`; `.drawingGroup()` for complex static layouts.

## Apple HIG & Accessibility
- 44pt minimum touch targets (48pt for primary actions).
- Support Dynamic Type, dark mode, and `accessibilityReduceMotion`.
- Provide `accessibilityLabel`/`accessibilityHint`. Maintain 4.5:1 contrast (3:1 for large text).
- Standard navigation patterns; never trap the user or override system gestures (swipe-back).

## Premium Polish (apply to all views)
- Count-up animation for numeric stats (`AnimatedStatItem`).
- Haptics via `HapticManager.shared`: light (tabs/chips), medium (primary actions), rigid (toggles), warning (destructive), success (completed).
- Spring animations for interactive state changes (response 0.3–0.6, damping 0.7–0.9).
- `.contentTransition(.numericText())` for changing numbers; asymmetric transitions for panels/bars.

## Build / Verify
- Lint with SwiftLint (`.swiftlint.yml`). Don't run long-lived simulator/Xcode build watchers in the agent; ask the user to run device/simulator builds when needed.
