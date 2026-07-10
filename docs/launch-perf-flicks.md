# Launch & Performance — Flicks Vertical Feed

Targets: **60 fps** scroll, **< 400 ms** cold launch (see `docs/launch-perf-checklist.md`), **visible+1** prefetch only.

## Scroll 60 fps (Flicks)

- Full-screen paging via `TabView` + `.tabViewStyle(.page)` in `FlicksFeedPager`.
- Engagement chrome uses `.drawingGroup()` on the static overlay only — not the video layer (see below).
- Springs: `response: 0.35`, `dampingFraction: 0.85`; respect `@Environment(\.accessibilityReduceMotion)`.
- Profile with Instruments → Core Animation during 30 s vertical swipe.

## Memory watermark (Flicks)

- Peak RSS target: **< 350 MB** on base iPhone (`docs/memory-watermark.md`).
- Prefetch window capped at **visible + 1** — never +5 ahead.
- `MemoryPressureMonitor` + `ImageCache` halve cache on `didReceiveMemoryWarning`.
- Pause off-screen `AVPlayer` when Flicks disappears; call `GlobalVideoPlayerManager.resumeAfterLeavingFlicks()` on return.

## Network waterfalls at launch

- `LazyServiceManager` keeps AI agents at `.deferred` — no Flicks network on cold path.
- `NetworkOptimizer` defers path monitoring to a background queue; URLCache warms after first frame.
- Flicks feed fetch runs in `NuclearFlicksViewModel.loadInitialFlicks()` after view appears, not in `MyChannelApp.init`.
- Avoid serializing: Firebase init → auth → feed. Feed load is independent once auth token is available.

## Prefetch only visible+1

```swift
// FeedMath.flicksPrefetchWindow — current index + next item only
FeedMath.preloadRange(around: index, before: 0, after: 1, total: flicks.count)
```

Call sites:

- `FlicksView.handleIndexChange` → `viewModel.preloadVideos(around:count: 1)`
- `NuclearFlicksViewModel.preloadVideos` → `before: 0, after: count`

Thumbnails: `ImagePrefetcher.prefetch` for URLs in the preload window only.

## SwiftUI body complexity (Flicks)

- `FlicksView.body` delegates to `flicksFeed`, sheets, and chrome subviews — no inline 200-line builders.
- `@ViewBuilder flickCard` closure keeps per-cell logic in `flickCardOverlay`.
- Extracted modules: `FlicksFeedPager`, `FlicksEngagementBar`, `FlicksActionRail`, `FlicksChromeViews`.

## drawingGroup — selective use

Apply **only** to static, frequently repainted overlays (engagement bar stack):

```swift
// FlicksView.flickCardOverlay — flatten chrome, not AVPlayerLayer
.drawingGroup()
```

Do **not** wrap:

- Video `AVPlayer` layers
- Gesture hit targets
- Sheets / modals

## Avoid AnyView in hot paths

- Flicks feed uses concrete generic `FlicksFeedPager<FlickCard: View>` — no `AnyView` in the pager loop.
- Tab roots may use `AnyView` in `TabSafeViews` (cold path only); never in per-frame Flicks cells.

## @StateObject vs @ObservedObject audit (Flicks)

| Property | Wrapper | Rationale |
|----------|---------|-----------|
| `viewModel` (`NuclearFlicksViewModel`) | `@StateObject` | View owns lifetime; survives tab re-select |
| `networkMonitor` | `@StateObject` | Same — created once per Flicks tab |
| Child views receiving `viewModel` | `@ObservedObject` | Parent owns storage |

Rule: **owner uses `@StateObject`; injected child uses `@ObservedObject`.**

## Image downsample

- `ImageCache.downsample(data:maxPixelSize:)` decodes via `CGImageSource` + `kCGImageSourceThumbnailMaxPixelSize`.
- `ImagePrefetcher` stores downsampled bitmaps (max 720 px edge) to cut RAM ~4× vs full-res decode.

## Video thumbnail decode off main

- `VideoStreamingService.generateVideoThumbnail` runs `AVAssetImageGenerator` on `DispatchQueue.global(qos: .userInitiated)`.
- Only the final `UIImage` hops to `@MainActor` for upload/publish.

## Combine sink cancel on deinit

Pattern (see `MemoryPressureMonitor`, `NetworkOptimizer`):

```swift
private var cancellables = Set<AnyCancellable>()

deinit {
    cancellables.removeAll() // tears down NotificationCenter / publisher sinks
}
```

Always use `[weak self]` inside sink bodies.

## Regression checklist

- [ ] Flicks swipe 30 s — no missed frames in Core Animation
- [ ] Memory warning — cache halves, no crash
- [ ] Prefetch count = 1 ahead (visible+1) in logs
- [ ] No main-thread thumbnail decode > 8 ms (Time Profiler)
