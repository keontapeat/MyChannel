# 🔥 Firebase Crashlytics Fix Instructions

## The Issue
Xcode 15+ enables "User Script Sandboxing" by default, which prevents Firebase Crashlytics from accessing the GoogleService-Info.plist file and extracting the GOOGLE_APP_ID.

## Solution 1: Disable Sandboxing in Xcode (Recommended)

### Step 1: Open Project Settings
1. Open your MyChannel project in Xcode
2. Select the **MyChannel** project (top level) in the navigator
3. Select the **MyChannel** target (under TARGETS)

### Step 2: Modify Build Settings
1. Go to the **Build Settings** tab
2. Search for "ENABLE_USER_SCRIPT_SANDBOXING"
3. Set this value to **No** for both Debug and Release configurations

### Step 3: Move Crashlytics Script (Optional)
1. Go to **Build Phases** tab
2. Find the "[Firebase] Crashlytics" script phase
3. Drag it to be the **last** item in the build phases list

### Step 4: Clean and Rebuild
1. Press `Shift + Cmd + K` to clean
2. Press `Cmd + B` to rebuild

## Solution 2: Alternative Script (If Solution 1 doesn't work)

Replace the Firebase Crashlytics script content with: