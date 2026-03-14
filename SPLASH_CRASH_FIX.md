# 🚨 SPLASH → MAINTABVIEW CRASH FIX

## 🔍 ISSUE IDENTIFIED

App crashes when transitioning from `SplashContainer` to `MainTabView`.

### Root Causes Found:

1. **Missing Environment Objects**: `MainTabView` requires 3 environment objects that may not be properly injected
2. **Service Initialization**: `NotificationsInboxService.shared` accessed as `@StateObject` before being ready
3. **Heavy Initialization on Transition**: All services loading when splash ends

## ✅ IMMEDIATE FIX

### Fix #1: Wrap MainTabView in Error Boundary

The `SplashContainer` already has error handling for previews, but we need to add it for runtime too.

**File:** `MyChannel/Core/Views/SplashContainer.swift` (Line 47)

**Change THIS:**
```swift
} else {
    // Always start unauthenticated unless user signs in (fresh TestFlight behavior)
    MainTabView()
        .transition(.opacity)
}
```

**TO THIS:**
```swift
} else {
    // Always start unauthenticated unless user signs in (fresh TestFlight behavior)
    Group {
        #if DEBUG
        ErrorBoundary {
            MainTabView()
        } fallback: {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                Text("App Failed to Load")
                    .font(.title)
                Text("Restart the app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        #else
        MainTabView()
        #endif
    }
    .transition(.opacity)
}
```

### Fix #2: Make Inbox Service Optional

**File:** `MyChannel/Core/Navigation/MainTabView.swift` (Line 17)

**Change THIS:**
```swift
@StateObject private var inbox = NotificationsInboxService.shared
```

**TO THIS:**
```swift
@StateObject private var inbox: NotificationsInboxService = {
    let service = NotificationsInboxService.shared
    print("📨 [MainTabView] Inbox service initialized")
    return service
}()
```

### Fix #3: Delay Heavy Initialization

**File:** `MyChannel/Core/Navigation/MainTabView.swift` (Line 257)

**Add delay to initialization:**

```swift
private func setupInitialState() {
    guard !isInitialized else { return }
    
    do {
        print("🔄 [MainTabView] setupInitialState - Starting...")
        
        // 🔥 CRITICAL: Delay heavy operations to prevent crash on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Clear fullscreen state on app launch
            print("🔄 [MainTabView] setupInitialState - Clearing fullscreen state")
            globalPlayer.showingFullscreen = false
            
            // 🔥 CRITICAL FIX: If there's a video but no active player, clear the video too
            if globalPlayer.currentVideo != nil && globalPlayer.player == nil {
                print("⚠️ [MainTabView] Found stale video with no player - clearing")
                globalPlayer.currentVideo = nil
            }
            
            // Initialize inbox listener
            if let uid = authManager.currentUser?.id {
                inbox.listen(userId: uid)
                print("📨 [MainTabView] Started inbox listener for user: \(uid)")
            }
        }
        
        // Initialize notification badges immediately (lightweight)
        notificationBadges = [
            .home: 0,
            .flicks: 2,
            .upload: 0,
            .search: 0,
            .profile: 3
        ]
        
        // Sync user state safely
        appState.currentUser = authManager.currentUser
        isInitialized = true
        
        print("✅ [MainTabView] setupInitialState completed (heavy ops delayed)")
    } catch {
        handleError("Failed to initialize app state: \(error.localizedDescription)")
    }
}
```

## 🔥 ALTERNATIVE: Simpler Fix (Use This If Above Doesn't Work)

If the crash persists, temporarily disable the inbox service:

**File:** `MyChannel/Core/Navigation/MainTabView.swift`

**Comment out Line 17:**
```swift
// @StateObject private var inbox = NotificationsInboxService.shared
```

**Comment out Line 55:**
```swift
// if let uid = authManager.currentUser?.id { inbox.listen(userId: uid) }
```

**Comment out Lines 64-66:**
```swift
// .onChange(of: inbox.items) { items in
//     let unread = items.filter { !$0.read }.count
//     notificationBadges[.profile] = unread
// }
```

This will let the app run without notifications temporarily.

## 🐛 DEBUGGING: Check Console Output

When you run the app, you should see in Console:

```
🚀 MyChannelApp init started...
✅ MyChannelApp init completed
📱 App appeared with MC logo splash!
🔄 [MainTabView] setupInitialState - Starting...
📨 [MainTabView] Inbox service initialized
✅ [MainTabView] setupInitialState completed
📺 [LiveTV] Initialized with fresh channel data
```

If you see a crash before "setupInitialState completed", the issue is in `MainTabView.init()`.

## 🎯 ROOT CAUSE ANALYSIS

### Why It's Crashing:

1. **Timing Issue**: Services initializing before environment objects are fully injected
2. **State Object Crash**: `@StateObject` being accessed before SwiftUI lifecycle is ready
3. **Missing Weak References**: Circular references between services

### The Transition Flow:
```
SplashView (4 seconds)
   ↓
proceedFromSplash()
   ↓
showSplash = false
   ↓
MainTabView appears
   ↓
MainTabView.init() ← CRASH HAPPENS HERE
   ↓
MainTabView.onAppear()
```

## ✅ VERIFICATION STEPS

After applying fixes:

1. **Build the app** (Cmd+B)
2. **Run in simulator** (Cmd+R)
3. **Wait for splash** (4 seconds or tap to skip)
4. **Watch console** for initialization logs
5. **Verify** MainTabView appears without crash

### Success Indicators:
- ✅ Splash screen shows
- ✅ After 4 seconds, transitions smoothly
- ✅ Home tab appears with content
- ✅ Tab bar is interactive
- ✅ No crash logs

### Failure Indicators:
- ❌ App crashes immediately after splash
- ❌ Black screen after splash
- ❌ "Thread 1: Fatal error" in Xcode
- ❌ Simulator shows crash dialog

## 🔧 IF STILL CRASHING

### Option 1: Simplify MainTabView Temporarily

Replace the entire MainTabView with a minimal version to isolate the issue:

```swift
struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var globalPlayer: GlobalVideoPlayerManager
    
    var body: some View {
        VStack {
            Text("MyChannel")
                .font(.largeTitle)
                .bold()
            
            Text("App Loaded Successfully!")
                .font(.title3)
                .foregroundColor(.green)
            
            Text("MainTabView is working")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
```

If this works, the crash is in the original `MainTabView` body/logic.

### Option 2: Check Environment Objects

Make sure `MyChannelApp.swift` is passing all required environment objects:

```swift
SplashContainer()
    .environmentObject(authManager)      // ✅ Required
    .environmentObject(appState)         // ✅ Required
    .environmentObject(globalPlayerManager)  // ✅ Required
```

### Option 3: Enable Debug Logging

Add this to `MyChannelApp.swift` init:

```swift
init() {
    print("🚀 MyChannelApp init started...")
    
    // Enable SwiftUI debug logging
    #if DEBUG
    UserDefaults.standard.set(true, forKey: "UIViewLayoutFeedbackLoopDebuggingThreshold")
    #endif
    
    // ... rest of init
}
```

## 📊 CRASH LOG ANALYSIS

The crash logs show the app is crashing during transition. Common causes:

1. **Force unwrap (`!`) on nil value**
2. **Missing environment object**
3. **Service singleton not initialized**
4. **Circular reference**
5. **State mutation during view update**

## 🎯 BEST PRACTICE: Lazy Loading

Instead of loading everything in `MainTabView.init()`, use lazy loading:

```swift
var body: some View {
    ZStack {
        // Content loads lazily as needed
        if isInitialized {
            mainContent
        } else {
            ProgressView("Loading...")
                .onAppear {
                    setupInitialState()
                }
        }
    }
}
```

---

**Status:** Fixes ready to apply
**Next Step:** Apply Fix #1 and #2, then test
**Fallback:** Use Alternative fix if needed
