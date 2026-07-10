# Scroll 60 fps — Checklist

Target: **16 ms/frame** (60 fps) on iPhone 12 and newer.

## Lists

- [ ] `LazyVStack` / `LazyVGrid` for 10+ items (never unbounded `VStack`)
- [ ] Pagination batch size 24 (`FeedMath` / feed view models)
- [ ] `.drawingGroup()` on complex animated cells (Flicks action rail)
- [ ] Prefetch next item only (Flicks: visible+1 via `FeedMath.flicksPrefetchWindow`, Home: +24)

## Flicks vertical feed

- `TabView` page style for full-screen paging
- `NuclearFlicksViewModel.preloadVideos(around:count:)` before swipe completes
- Reduce motion: respect `@Environment(\.accessibilityReduceMotion)` — skip spring on UI chrome

## Player

- Never block main thread on `AVPlayerItem` setup — use background queue + `@MainActor` publish
- PiP / mini player: separate layer from scroll view

## Profiling

1. Instruments → Time Profiler during 30s Flicks scroll
2. Instruments → Core Animation → missed frames
3. Fix any main-thread Firestore decode > 8 ms

## Constants

```swift
// Premium polish springs — response < 400 ms
.spring(response: 0.35, dampingFraction: 0.85)
```
