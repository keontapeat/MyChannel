# Memory Watermark Handling

## Targets

- Peak RSS during Flicks scroll: <350 MB on base iPhone
- Release listeners/timers on view disappear

## Automatic responses

| Signal | Handler |
|--------|---------|
| `didReceiveMemoryWarning` | `NetworkOptimizer.clearCaches()` |
| Scene background | Pause off-screen `AVPlayer` instances |
| Flicks disappear | `GlobalVideoPlayerManager.resumeAfterLeavingFlicks()` |

## Manual patterns

```swift
// Async closures
Task { [weak self] in
    guard let self else { return }
    ...
}

// Firestore listeners — cap count (RealtimeViewTracker maxConcurrentViewListeners = 12)
deinit { listener?.remove() }
```

## Lazy services

Heavy AI (`OpenAIAgent`, `AgentLog`, `MyChannelAI`) stay at `.deferred` in `LazyServiceManager` — do not promote to `.medium` without memory budget review.

## Profiling

Instruments → Allocations → mark generations around tab switches. Leaks in `ListenerRegistration` = missing `remove()` on disappear.
