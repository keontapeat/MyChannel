# Native PiP Debugging Guide

## 🐛 Issue: Mini Player Slides Down But Never Shows

**Problem**: When backing out of a video, the video slides down but native iOS PiP doesn't appear.

**✅ FIXED**: PiP controller now properly initialized in `adoptExternalPlayerManager()`

---

## 🔍 **What I Fixed**

### 1. Changed `canStartPictureInPictureAutomaticallyFromInline` to `false`
**Files Changed:**
- `NativePiPController.swift` (line 37)
- `GlobalPlayerViewController.swift` (line 23)

**Why**: This prevents automatic PiP and gives us manual control.

### 2. Added KVO Observer for `isPictureInPicturePossible`
**What**: Now we observe when PiP becomes ready.
**Why**: PiP might not be immediately possible after player setup.

### 3. Added Retry Logic
**What**: If PiP isn't possible, wait 0.5 seconds and try again.
**Why**: Player might need time to load before PiP is possible.

### 4. Added Extensive Logging
**What**: Console now shows detailed PiP status.
**Why**: To debug exactly what's happening.

---

## 📊 **Console Logs to Watch For**

### **When You Back Out of Video:**
```
✅ [NativePiP] Controller setup complete, possible: true/false
🔍 [NativePiP] PiP Status:
   - Controller exists: ✅
   - isPictureInPictureActive: false
   - isPictureInPicturePossible: true/false
```

### **If PiP is Possible:**
```
▶️ [NativePiP] Starting PiP...
🎬 [NativePiP] Will start PiP
✅ [NativePiP] Did start PiP
```

### **If PiP Controller Was Nil (FIXED):**
```
⚠️ [NativePiP] Cannot start PiP - controller is nil
```
**Fix Applied**: Added `pipController.setup(with: player)` in `adoptExternalPlayerManager()` at line ~495

### **If PiP is NOT Possible:**
```
⚠️ [NativePiP] PiP not possible yet - waiting for player to be ready
[After 0.5 seconds]
✅ [NativePiP] PiP now possible, retrying...
▶️ [NativePiP] Starting PiP...
```

### **If PiP Fails:**
```
❌ [NativePiP] Failed to start: [error message]
```

---

## 🧪 **How to Test**

1. **Run the app on a physical device** (PiP doesn't work in simulator)
2. **Open Xcode Console** (Cmd+Shift+Y)
3. **Play a video**
4. **Back out of the video** (swipe down or tap back)
5. **Watch the console** for the logs above

---

## 🔧 **Possible Issues & Fixes**

### **Issue 1: `isPictureInPicturePossible` is Always False**

**Cause**: Player might not be fully loaded.

**Fix**: Check if video is actually playing:
```swift
// In Console:
po globalPlayer.player?.timeControlStatus
// Should be: playing (1)

po globalPlayer.player?.currentItem?.status
// Should be: readyToPlay (1)
```

### **Issue 2: PiP Controller is Nil**

**Cause**: `setup(with: player)` wasn't called or failed.

**Fix**: Check console for:
```
✅ [NativePiP] Controller setup complete
```

If you don't see this, the setup failed. Check if player exists:
```swift
po globalPlayer.player
// Should NOT be nil
```

### **Issue 3: Video Slides Down But PiP Doesn't Start**

**Cause**: `startPiP()` isn't being called when backing out.

**Fix**: Check if `VideoDetailView.onDisappear` is calling `startPiP()`:
```swift
// Should see in console:
🔍 [NativePiP] PiP Status:
```

If you don't see this, `startPiP()` isn't being called. Check `VideoDetailView`:
```swift
.onDisappear {
    if globalPlayer.currentVideo != nil && !globalPlayer.showingFullscreen {
        globalPlayer.startPiP()  // This should be called
    }
}
```

### **Issue 4: Background Audio Not Configured**

**Cause**: `Info.plist` missing background audio mode.

**Fix**: Verify `Info.plist` has:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### **Issue 5: Audio Session Not Configured**

**Cause**: `AVAudioSession` not set to `.playback`.

**Fix**: Check `GlobalVideoPlayerManager.configureAudioSession()`:
```swift
try AVAudioSession.sharedInstance().setCategory(.playback, options: [.allowAirPlay])
```

---

## 🎯 **Expected Behavior**

### **Correct Flow:**
1. User plays video → Video appears fullscreen
2. User backs out → `VideoDetailView.onDisappear` triggers
3. Calls `globalPlayer.startPiP()`
4. `NativePiPController.startPiP()` is called
5. Checks if `isPictureInPicturePossible` is true
6. If true → Calls `pipController.startPictureInPicture()`
7. ✅ **Native iOS PiP window appears**

### **What You Should See:**
- ✅ Video slides down (dismiss animation)
- ✅ Native iOS PiP floating window appears in corner
- ✅ Video continues playing in PiP
- ✅ PiP controls visible (play/pause, close, expand)

---

## 📝 **Debug Commands**

### **Check Player Status:**
```bash
# In Xcode console:
po globalPlayer.player
po globalPlayer.player?.rate  # Should be > 0 if playing
po globalPlayer.player?.timeControlStatus  # Should be 1 (playing)
```

### **Check PiP Controller:**
```bash
po globalPlayer.pipController.pipController
po globalPlayer.pipController.pipController?.isPictureInPicturePossible
po globalPlayer.pipController.pipController?.isPictureInPictureActive
```

### **Check Audio Session:**
```bash
po AVAudioSession.sharedInstance().category
# Should be: AVAudioSessionCategoryPlayback
```

---

## 🚨 **Common Mistakes**

### **Mistake 1: Testing in Simulator**
❌ **Problem**: iOS Simulator doesn't support PiP.  
✅ **Solution**: MUST test on physical device.

### **Mistake 2: Video Not Playing**
❌ **Problem**: Video is paused or not loaded.  
✅ **Solution**: Ensure video is actually playing before backing out.

### **Mistake 3: showingFullscreen is True**
❌ **Problem**: If `showingFullscreen` is true, `startPiP()` won't be called.  
✅ **Solution**: Check `globalPlayer.showingFullscreen` value.

---

## 🔍 **Detailed Debugging Steps**

### **Step 1: Verify Player Exists**
```bash
# In Xcode console:
po globalPlayer.player
```
**Expected**: `<AVPlayer: 0x...>` (NOT nil)

### **Step 2: Verify Video is Playing**
```bash
po globalPlayer.player?.rate
```
**Expected**: `1.0` (playing) or `0.0` (paused)

### **Step 3: Verify PiP is Possible**
```bash
po globalPlayer.pipController.pipController?.isPictureInPicturePossible
```
**Expected**: `true`

### **Step 4: Manually Trigger PiP**
```bash
# In Xcode console:
expression globalPlayer.startPiP()
```
**Expected**: PiP window should appear

### **Step 5: Check for Errors**
Watch console for:
```
❌ [NativePiP] Failed to start: [error]
```

---

## 📱 **Test on Real Device**

1. **Connect iPhone/iPad** to Mac
2. **Select device** in Xcode (not simulator)
3. **Run app** (Cmd+R)
4. **Open Console** (Cmd+Shift+Y)
5. **Play video**
6. **Back out**
7. **Watch console** for logs

---

## ✅ **If PiP Works:**

You should see:
```
✅ [NativePiP] Controller setup complete, possible: true
🔍 [NativePiP] PiP Status:
   - Controller exists: ✅
   - isPictureInPictureActive: false
   - isPictureInPicturePossible: true
▶️ [NativePiP] Starting PiP...
🎬 [NativePiP] Will start PiP
✅ [NativePiP] Did start PiP
```

And:
- ✅ Native iOS PiP window appears
- ✅ Video continues playing
- ✅ Can tap to return to fullscreen

---

## 🎉 **If Everything Works:**

Congratulations! Native iOS PiP is working correctly! 🚀

Now test the other scenarios:
1. ✅ Back out of video → PiP starts
2. ✅ Swipe down video → PiP starts
3. ✅ Background app → PiP continues
4. ✅ Tap PiP button → PiP starts

---

## 📞 **Still Not Working?**

Share these console logs:
1. The full console output when backing out
2. The result of `po globalPlayer.pipController.pipController?.isPictureInPicturePossible`
3. Any error messages

This will help identify the exact issue!

