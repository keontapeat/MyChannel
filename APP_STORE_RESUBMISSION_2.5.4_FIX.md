# App Store Resubmission – Guideline 2.5.4 Fix

**Rejection reason:** The app declared `external-accessory` in `UIBackgroundModes` but does not use the External Accessory framework or MFi hardware.

**Fix applied:**  
- **Info.plist**: Confirmed `UIBackgroundModes` does **not** include `external-accessory`. Only: `audio`, `fetch`, `remote-notification`, `processing`, `location`, `bluetooth-central`, `bluetooth-peripheral`.  
- Added a comment in Info.plist so this mode is not added in the future.

---

## Before you resubmit

### 1. Check Xcode Background Modes (important)

Apple can inject `external-accessory` from the target’s **Signing & Capabilities**:

1. Open the project in **Xcode**.
2. Select the **MyChannel** target.
3. Open the **Signing & Capabilities** tab.
4. If you see **Background Modes**, open it.
5. **Uncheck** **“External accessory communication”** if it is checked.  
   Leave only the modes you actually use (e.g. Audio, Background fetch, Remote notifications, etc.).

If “External accessory communication” is enabled here, it can add `external-accessory` to the built app even if it’s not in Info.plist.

### 2. New build and upload

1. **Increment build number** (e.g. 1.0 **(39)**):  
   Xcode → MyChannel target → **General** → **Build** (increase by 1).
2. **Product → Archive**.
3. **Distribute App** → **App Store Connect** → **Upload**.
4. In **App Store Connect**, select the new build for the version and **Resubmit to App Review**.

### 3. Optional: Reply to App Review

In App Store Connect → **App Review** → **Reply to App Review**, you can add a short note, for example:

> We have removed the external-accessory background mode. MyChannel does not use the External Accessory framework or MFi hardware; the app is a video/social platform and does not communicate with external accessories. We have also verified that "External accessory communication" is disabled in our target’s Background Modes capability.

---

After uploading a new build **without** `external-accessory` and resubmitting, the 2.5.4 issue should be resolved.
