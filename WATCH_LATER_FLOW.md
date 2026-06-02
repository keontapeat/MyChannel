# Watch Later - User Flow Diagram

## 🎬 Complete User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                         HOME TAB                                 │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  ⭐ FEATURED                                            │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │                                               │      │    │
│  │  │         [Video Thumbnail]                     │      │    │
│  │  │                                               │      │    │
│  │  │  ⭐ Entertainment              0:35           │      │    │
│  │  │                                               │      │    │
│  │  │                                               │      │    │
│  │  │  👤 Keonta Peat  •  👁 0 views               │      │    │
│  │  │                                               │      │    │
│  │  │  ┌──────────────────────┐  ┌────┐            │      │    │
│  │  │  │  ▶ Play              │  │ +  │ ← TAP THIS │      │    │
│  │  │  └──────────────────────┘  └────┘            │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                         [User taps +]
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    TOAST NOTIFICATION                            │
│                                                                  │
│              ┌─────────────────────────────────┐                │
│              │ ✓ Added to Watch Later          │                │
│              └─────────────────────────────────┘                │
│                                                                  │
│  Button changes:  [+]  →  [✓]                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    [Video saved to cloud]
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       PROFILE TAB                                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  📊 Creator Studio                              →      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  🕐 History                                     →      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  🕐 Watch Later                        [1]      →      │ ← TAP THIS
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  ⬇️ Downloads                                   →      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    [User taps Watch Later]
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    WATCH LATER VIEW                              │
│                                                                  │
│  Watch Later                                    [⋯]              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  1 video  •  35 seconds  •  0% watched                 │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  🔍 Search videos...                                             │
│                                                                  │
│  Sort by: Date Added ▼                                           │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  ┌──────┐                                              │    │
│  │  │      │  Shot By Keonta Intro                        │    │
│  │  │ 📺   │  Keonta Peat                                 │    │
│  │  │      │  0 views • 0:35                              │    │
│  │  └──────┘                                              │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  [Tap video to watch]                                           │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 State Changes

### Button States on Featured Card

```
INITIAL STATE (Not Saved)
┌────┐
│ +  │  ← White background, black + icon
└────┘

         ↓ [User taps]

SAVED STATE
┌────┐
│ ✓  │  ← White background, primary color checkmark
└────┘

         ↓ [User taps again]

REMOVED STATE
┌────┐
│ +  │  ← Back to initial state
└────┘
```

## 📱 Navigation Path

```
Home Tab
   ↓
Tap + on Featured Card
   ↓
Toast: "Added to Watch Later"
   ↓
Profile Tab
   ↓
Scroll Down
   ↓
Tap "Watch Later" Button
   ↓
Watch Later View
   ↓
See All Saved Videos
```

## 🎯 Key Touchpoints

### 1. Save Action (Featured Card)
```
Location: Home Tab → Featured Section
Action:   Tap "+" button
Result:   
  - Button → Checkmark
  - Toast notification
  - Video saved to cloud
  - Count badge updates
```

### 2. View Saved Videos (Profile)
```
Location: Profile Tab → Watch Later Button
Action:   Tap button
Result:   
  - Opens Watch Later view
  - Shows all saved videos
  - Display count, stats
  - Sort/search options
```

### 3. Remove Video (Featured Card)
```
Location: Home Tab → Featured Section
Action:   Tap "✓" button
Result:   
  - Checkmark → Plus
  - Toast notification
  - Video removed from list
  - Count badge decrements
```

## 💾 Data Flow

```
User Action (Tap +)
        ↓
AppState.toggleWatchLater()
        ↓
Local State Update (watchLaterVideos.insert)
        ↓
Firebase Sync (UserCollectionsFirestoreService)
        ↓
Firestore: users/{userId}/watchLater/{videoId}
        ↓
Real-time Listener Updates
        ↓
UI Updates (Count Badge, Button State)
```

## 🎨 Visual Feedback

### Toast Notification
```
┌─────────────────────────────────┐
│                                 │
│  ✓  Added to Watch Later        │
│                                 │
└─────────────────────────────────┘
   ↑
   Appears for 2 seconds
   Fades out automatically
```

### Count Badge
```
Watch Later Button:

Without videos:
┌─────────────────────────────────┐
│ 🕐 Watch Later              →   │
└─────────────────────────────────┘

With videos:
┌─────────────────────────────────┐
│ 🕐 Watch Later         [5]  →   │
└─────────────────────────────────┘
                          ↑
                    Count badge
```

## ✅ Success Indicators

1. **Button Changes**: + → ✓
2. **Toast Appears**: "Added to Watch Later"
3. **Count Updates**: Badge shows number
4. **Video in List**: Appears in Watch Later view
5. **Synced**: Available on all devices

## 🔧 Troubleshooting

### Video Not Saving?
- Check if user is signed in (required)
- Check internet connection
- Check Firebase console for errors

### Count Not Updating?
- Check `appState.watchLaterVideos.count`
- Verify Firebase sync completed
- Check real-time listener is active

### Button Not Changing?
- Verify `appState.isVideoInWatchLater()` returns correct value
- Check button state binding
- Verify video ID is correct

## 🎉 Success!

When everything works:
1. ✅ Tap + on featured card
2. ✅ See toast notification
3. ✅ Button changes to checkmark
4. ✅ Go to Profile → Watch Later
5. ✅ See saved video in list
6. ✅ Count badge shows "1"

**Watch Later is fully functional!** 🚀
