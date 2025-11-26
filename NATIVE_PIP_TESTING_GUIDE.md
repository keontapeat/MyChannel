# Native iOS PiP Testing Guide

## 🎯 **Objective**
Verify that native iOS Picture-in-Picture works correctly across all scenarios.

---

## ✅ **Test Scenarios**

### **Scenario 1: User Backs Out of Video**
**Action**: 
1. Open MyChannel app
2. Play any video in fullscreen
3. Swipe down or tap the back button to exit

**Expected Result**:
- ✅ Native iOS PiP floating window appears
- ✅ Video continues playing in PiP
- ✅ Can see PiP controls (play/pause, close, expand)
- ✅ Can tap PiP window to return to fullscreen

**How to Test**:
```swift
// VideoDetailView should call:
globalPlayer.startPiP()

// On .onDisappear:
.onDisappear {
    if globalPlayer.currentVideo != nil && !globalPlayer.showingFullscreen {
        globalPlayer.startPiP()
    }
}
```

---

### **Scenario 2: User Swipes Down Video**
**Action**:
1. Play video in fullscreen
2. Swipe down from top of video
3. Video should minimize to PiP

**Expected Result**:
- ✅ Native iOS PiP starts automatically
- ✅ Video continues playing
- ✅ PiP window appears in corner

**How to Test**:
Same as Scenario 1 - swipe down triggers `.onDisappear` which calls `startPiP()`

---

### **Scenario 3: App Goes to Background**
**Action**:
1. Play video in fullscreen
2. Swipe up to go to Home screen (or switch to another app)
3. Video should continue in PiP

**Expected Result**:
- ✅ Native iOS PiP starts automatically when app backgrounds
- ✅ Video continues playing in floating window
- ✅ Can see PiP across other apps (Home, Safari, Messages)
- ✅ When returning to MyChannel, PiP stops and video returns inline

**How to Test**:
```swift
// GlobalVideoPlayerManager.applicationDidEnterBackground:
func applicationDidEnterBackground() {
    if globalPlayer.currentVideo != nil {
        globalPlayer.startPiP()  // Auto-start PiP
    }
}
```

**Verification Steps**:
1. Play video
2. Press Home button (or swipe up)
3. ✅ Verify PiP window appears on Home screen
4. Open another app (Safari, Messages)
5. ✅ Verify PiP continues floating
6. Return to MyChannel
7. ✅ Verify PiP stops and video is back inline

---

### **Scenario 4: User Taps PiP Button**
**Action**:
1. Play video in fullscreen
2. Tap the PiP button in video controls (if visible)
3. Video should minimize to PiP

**Expected Result**:
- ✅ Native iOS PiP starts when button tapped
- ✅ Video continues playing
- ✅ PiP window appears

**How to Test**:
```swift
// PiP button in controls:
Button(action: {
    globalPlayer.startPiP()
    dismiss()
}) {
    Image(systemName: "pip.enter")
}
.accessibilityLabel("Minimize to Picture in Picture")
```

**Verification Steps**:
1. Play video
2. Locate PiP button in controls (may need to add if not visible)
3. Tap PiP button
4. ✅ Verify PiP starts

---

## 🔧 **Manual Testing Checklist**

### **Device Testing**
- [ ] Test on iPhone (iOS 15+)
- [ ] Test on iPad (iOS 15+)
- [ ] Test on physical device (not simulator)

### **PiP Lifecycle**
- [ ] PiP starts correctly (all 4 scenarios)
- [ ] PiP continues when app backgrounds
- [ ] PiP stops when returning to app
- [ ] PiP expands to fullscreen when tapped
- [ ] PiP closes when X button tapped
- [ ] Multiple start/stop cycles work correctly

### **Audio Continuation**
- [ ] Audio continues when PiP starts
- [ ] Audio continues when app backgrounds
- [ ] Audio stops when PiP closes
- [ ] Audio doesn't interfere with other apps

### **Edge Cases**
- [ ] Start PiP, lock device, unlock → PiP resumes
- [ ] Start PiP, rotate device → PiP adjusts correctly
- [ ] Start PiP, receive phone call → PiP pauses/resumes correctly
- [ ] Start PiP, play another video → Old PiP stops, new PiP starts

---

## 🐛 **Common Issues & Fixes**

### **Issue 1: PiP Doesn't Start**
**Symptoms**: Nothing happens when backing out or backgrounding app

**Possible Causes**:
1. `allowsPictureInPicturePlayback` is `false`
2. `NativePiPController` not setup
3. Background audio mode not enabled

**Fixes**:
```swift
// Verify GlobalPlayerViewController.swift:
controller.allowsPictureInPicturePlayback = true  // Must be true

// Verify Info.plist has background audio:
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

// Verify NativePiPController is setup:
pipController.setup(with: player)
```

---

### **Issue 2: PiP Starts But Video Doesn't Play**
**Symptoms**: PiP window appears but video is frozen

**Possible Causes**:
1. Player not properly initialized
2. Video URL is invalid
3. Network issue

**Fixes**:
- Check player state before starting PiP
- Verify video URL is valid
- Check network connection

---

### **Issue 3: PiP Doesn't Stop When Returning to App**
**Symptoms**: PiP continues floating even when app is foreground

**Possible Causes**:
1. `applicationWillEnterForeground` not calling `stopPiP()`
2. PiP controller not properly managing state

**Fixes**:
```swift
// Verify GlobalVideoPlayerManager.applicationWillEnterForeground:
func applicationWillEnterForeground() {
    if pipController.isActive {
        pipController.stopPiP()
    }
}
```

---

## 📊 **Test Results Template**

Copy this template and fill it out after testing:

```markdown
## Test Results

**Date**: [Date]
**Device**: [iPhone/iPad model]
**iOS Version**: [iOS version]
**Build**: [Build number]

### Scenario 1: Back Out
- [ ] ✅ PASS / ❌ FAIL
- **Notes**: 

### Scenario 2: Swipe Down
- [ ] ✅ PASS / ❌ FAIL
- **Notes**: 

### Scenario 3: Background App
- [ ] ✅ PASS / ❌ FAIL
- **Notes**: 

### Scenario 4: PiP Button
- [ ] ✅ PASS / ❌ FAIL
- **Notes**: 

### Edge Cases
- [ ] Lock/Unlock: ✅ PASS / ❌ FAIL
- [ ] Rotation: ✅ PASS / ❌ FAIL
- [ ] Phone Call: ✅ PASS / ❌ FAIL
- [ ] Multiple Videos: ✅ PASS / ❌ FAIL

### Overall Status
- [ ] ✅ ALL TESTS PASSED
- [ ] ❌ SOME TESTS FAILED (see notes)
```

---

## 🚀 **Next Steps After Testing**

1. **If All Tests Pass**:
   - ✅ Mark Task 8 as complete
   - ✅ Update status document
   - ✅ Ready for production!

2. **If Tests Fail**:
   - 🔍 Debug using console logs
   - 🔧 Fix issues in code
   - 🔄 Re-test until all pass

---

## 📝 **Debug Commands**

### Check if PiP is Active
```bash
# In Xcode console:
po globalPlayer.pipController.isActive
```

### Check Player State
```bash
po globalPlayer.player?.timeControlStatus
po globalPlayer.currentVideo?.title
```

### Check Background Audio
```bash
po AVAudioSession.sharedInstance().category
# Should be: .playback
```

---

**Ready to test!** 🎬📱

Run through all 4 scenarios on a real device and report results!






