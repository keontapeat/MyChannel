# Equatable View Models — Note

## Why

SwiftUI diffing skips body re-evaluation when `@ObservedObject`/`@StateObject` publishes unchanged logical state. Conforming view models to `Equatable` (or using `@Observable` macro with stable identity) reduces scroll jank.

## Guidelines

1. **Value-type state** preferred for row models (`struct FeedItem: Identifiable, Equatable`).
2. **Reference-type VMs:** implement `Equatable` on published snapshot or use `@Published private(set)` with manual `objectWillChange` only when needed.
3. **Exclude non-UI fields** from equality (e.g. internal cache timestamps).
4. **Child views:** pass primitives (`let count: Int`) instead of whole parent VM when possible.

## Candidates

| Type | Status |
|------|--------|
| `NuclearFlick` | Should be `Equatable` on `id` + playback-relevant fields |
| `VideoPlayerViewModel` | Compare `videoId` + `isPlaying` for chrome subviews |
| `EnhancedFlicksViewModel` | Avoid republishing entire `flicks` array on single-like tap — patch index |

## Anti-pattern

```swift
// ❌ Re-renders entire LazyVStack
viewModel.flicks = viewModel.flicks // new array reference every poll

// ✅
viewModel.updateLike(at: index, liked: true) // publishes one index
```

## Testing

SwiftUI Preview + Instruments Core Animation — toggle one like, verify only action rail redraws.
