# 🔧 MyChannel Troubleshooting Guide

Quick fixes for common build issues you might encounter.

---

## 🔥 Firebase Package Errors

### Symptoms:
```
Missing package product 'FirebaseMessaging'
Missing package product 'FirebaseAnalytics'
Unable to find module dependency: 'FirebaseStorage'
```

### Quick Fix:
```bash
./Scripts/fix-firebase-packages.sh
```

### Manual Fix:
1. **Close Xcode completely**
2. **Run these commands:**
   ```bash
   cd /Users/keonta/Documents/MyChannel
   rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*
   rm -rf ~/Library/Caches/org.swift.swiftpm
   xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel
   ```
3. **Open Xcode**
4. **In Xcode:** File → Packages → Reset Package Caches
5. **Clean Build:** Cmd+Shift+K
6. **Build:** Cmd+B

### Why This Happens:
- SPM cache corruption
- Network interruption during package download
- Xcode version changes
- Package resolution conflicts

---

## 🧹 DerivedData Issues

### Symptoms:
```
Build input file cannot be found
lstat(...): No such file or directory
Command PhaseScriptExecution failed
```

### Quick Fix:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*
```

### When to Clear DerivedData:
- After git branch switches
- When build errors don't make sense
- After updating Xcode
- When "phantom" errors appear
- After SPM package updates

### Full Clean:
```bash
# Nuclear option - clears everything
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
```

---

## 📦 Swift Package Manager Issues

### Symptoms:
```
Missing package product
Package dependency not found
Unable to resolve package graph
```

### Fix Steps:

**1. In Xcode:**
- File → Packages → Reset Package Caches
- File → Packages → Update to Latest Package Versions

**2. If that fails:**
```bash
cd /Users/keonta/Documents/MyChannel
rm -rf .build
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel
```

**3. If THAT fails:**
- Close Xcode
- Delete `MyChannel.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`
- Reopen Xcode
- Let it re-resolve packages

---

## 🐛 Linter/Compiler Errors

### Type Ambiguity Errors:
```
'SearchResult' is ambiguous for type lookup
'VideoAnalysis' is ambiguous for type lookup
Invalid redeclaration of 'HowItWorksStep'
```

**Fix:** Rename one of the conflicting types
```swift
// From:
struct SearchResult { ... }

// To:
struct ElasticsearchSearchResult { ... }
```

### SwiftUI Compiler Timeouts:
```
The compiler is unable to type-check this expression in reasonable time
```

**Fix:** Break down complex views
```swift
// Instead of one massive body
var body: some View {
    VStack {
        // 100 lines of complex UI
    }
}

// Split into smaller views
var body: some View {
    VStack {
        headerSection
        contentSection
        footerSection
    }
}

private var headerSection: some View { ... }
private var contentSection: some View { ... }
private var footerSection: some View { ... }
```

### Missing Properties/Methods:
```
Value of type 'Video' has no member 'url'
Cannot find 'population' in scope
```

**Fix:** Check the actual property name or add it
```swift
// Wrong
video.url

// Correct
video.videoURL
```

---

## 🚀 Build Performance Issues

### Slow Builds?

**1. Clean DerivedData:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*
```

**2. Disable Indexing Temporarily:**
- Xcode → Settings → Locations → Derived Data
- Delete the folder
- Disable "Enable background indexing" during active coding

**3. Reduce Parallel Builds:**
- Xcode → Settings → Locations → Derived Data → Advanced
- Set "Build System" to "Legacy Build System" (temporary)

---

## 📱 Simulator Issues

### App Won't Launch:
1. Reset simulator: Device → Erase All Content and Settings
2. Restart simulator: Quit and relaunch
3. Clean and rebuild: Cmd+Shift+K, then Cmd+B

### Simulator Crashes:
```bash
killall Simulator
xcrun simctl erase all
```

### Wrong Device Target:
- Product → Destination → Choose a different simulator
- Or select from toolbar dropdown

---

## 🔐 Signing Issues

### Symptoms:
```
unable to spawn process '/usr/bin/codesign'
Signing certificate not found
```

### Fix:
1. Xcode → Settings → Accounts
2. Select your Apple ID
3. Download Manual Profiles
4. Project → Signing & Capabilities
5. Check "Automatically manage signing"

---

## 🌐 Network-Related Issues

### Package Download Failures:
```bash
# Use a different DNS
networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4

# Or try cellular/different network
# Then re-resolve packages
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel
```

---

## 💥 Nuclear Options

### When Everything Fails:

**1. Fresh Start (keeps code):**
```bash
cd /Users/keonta/Documents/MyChannel

# Clear all caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
rm -rf .build

# Quit Xcode completely
killall Xcode

# Re-resolve packages
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel

# Reopen Xcode
open MyChannel.xcodeproj
```

**2. Complete Xcode Reset:**
```bash
# WARNING: This removes ALL Xcode derived data for ALL projects
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ~/Library/Developer/Xcode/UserData
```

**3. Restart Mac:**
Sometimes you just gotta turn it off and on again 🤷‍♂️

---

## 📋 Quick Command Reference

```bash
# Clear DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*

# Clear SPM caches
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm

# Resolve packages
cd /Users/keonta/Documents/MyChannel
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel

# Fix Firebase packages (all-in-one)
./Scripts/fix-firebase-packages.sh

# Run SwiftLint
swiftlint --fix

# Kill all Xcode processes
killall Xcode

# Reset simulator
killall Simulator
xcrun simctl erase all
```

---

## 🆘 Still Stuck?

If none of these work:

1. **Check the auto-fix log:**
   ```bash
   tail -50 /Users/keonta/Documents/MyChannel/auto-fix.log
   ```

2. **Ask me for help!** Copy the exact error message

3. **Google the error** - add "Swift" or "Xcode" to your search

4. **Check Xcode version:**
   - Xcode → About Xcode
   - Make sure you're on latest stable version

5. **Check macOS version:**
   - Some Xcode features require newer macOS

---

## 🎯 Prevention Tips

1. **Always use the auto-fix agent** while coding
2. **Commit changes frequently** to git
3. **Clean build before major changes:** Cmd+Shift+K
4. **Clear DerivedData weekly** (or after big changes)
5. **Keep Xcode and macOS updated**
6. **Don't force quit Xcode** during builds
7. **Let packages resolve completely** before building

---

## 📚 Additional Resources

- **Auto-Fix Guide:** `AUTO_FIX_GUIDE.md`
- **Scripts Documentation:** `Scripts/README.md`
- **Firebase Fix Script:** `./Scripts/fix-firebase-packages.sh`
- **Auto-Fix Log:** `auto-fix.log`

---

**Remember:** Most issues are cache-related. When in doubt, clear DerivedData! 🧹


