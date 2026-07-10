# Cancel Tasks on Disappear — Pattern

SwiftUI views that start async work must cancel when the user navigates away.

## Template

```swift
@State private var loadTask: Task<Void, Never>?

var body: some View {
    content
        .task { await load() }           // auto-cancelled by SwiftUI
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
}

private func startPolling() {
    loadTask?.cancel()
    loadTask = Task {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }
}
```

## Examples in repo

| View | Pattern |
|------|---------|
| `VSMatchComplianceSheet` | `kycPollTask` cancelled `onDisappear` |
| `FlicksView` | `onDisappear` stops album art rotation |
| `NetworkOptimizer` | `cancelAllRequests()` on memory warning |

## Rules

1. Prefer `.task { }` for one-shot loads (built-in cancellation).
2. Long polling → stored `Task` + explicit cancel in `onDisappear`.
3. Never capture `self` strongly in polling loops — use `[weak self]` in classes.
4. `@MainActor` UI updates after `await` should check `Task.isCancelled`.
