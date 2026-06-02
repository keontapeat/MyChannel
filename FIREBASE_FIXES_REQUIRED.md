# Firebase Configuration Fixes Required

## ✅ ALREADY FIXED

### 1. Firebase Initialization
**Status:** ✅ COMPLETE

Firebase is properly initialized via `FirebaseManager.shared.configureIfPossible()` which is called before any Firebase usage in `MyChannelApp.swift`. The implementation includes:
- Checks for existing Firebase app instance
- Validates GoogleService-Info.plist exists
- Calls `FirebaseApp.configure()`
- Configures additional services (Performance, Remote Config, A/B Testing, Error Reporting)

No action needed for this issue.

---

## 🔴 CRITICAL ISSUES - ACTION REQUIRED

### 2. Missing Firestore Composite Indexes

**Error:** Multiple queries failing with "The query requires an index"

**Required Indexes:**

#### Index 1: Videos - Public Feed Query
- Collection: `videos`
- Fields:
  - `isPublic` (Ascending)
  - `createdAt` (Descending)
  - `__name__` (Descending)

**Create at:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoMCghpc1B1YmxpYxABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI

#### Index 2: Videos - New User Discovery
- Collection: `videos`
- Fields:
  - `visibility` (Ascending)
  - `creatorSubscribers` (Descending)
  - `engagementRate` (Descending)
  - `viewCount` (Descending)
  - `__name__` (Descending)

**Create at:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoOCgp2aXNpYmlsaXR5EAEaFgoSY3JlYXRvclN1YnNjcmliZXJzEAIaEgoOZW5nYWdlbWVudFJhdGUQAhoNCgl2aWV3Q291bnQQAhoMCghfX25hbWVfXxAC

#### Index 3: Payments Query
- Collection: `payments`
- Fields:
  - `status` (Ascending)
  - `timestamp` (Ascending)
  - `__name__` (Ascending)

**Create at:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=ClBwcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3BheW1lbnRzL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAE

---

### 3. Firestore Security Rules - Missing Permissions

**Error:** `Missing or insufficient permissions` for:
- `watch_progress` collection (write operations)
- `story_seen` collection (read operations)
- `notifications` collection (read operations)

**Fix:** Update Firestore Security Rules in Firebase Console

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Watch Progress - Allow users to write their own progress
    match /watch_progress/{progressId} {
      allow read, write: if request.auth != null && 
        progressId.matches('^' + request.auth.uid + '_.*');
    }
    
    // Story Seen - Allow users to read/write their own seen status
    match /story_seen/{seenId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Notifications - Allow users to read their own notifications
    match /notifications/{notificationId} {
      allow read: if request.auth != null && 
        resource.data.userId == request.auth.uid;
      allow write: if request.auth != null;
    }
    
    // Videos - Public read, authenticated write
    match /videos/{videoId} {
      allow read: if resource.data.isPublic == true || 
        resource.data.visibility == 'public';
      allow write: if request.auth != null;
    }
  }
}
```

---

### 4. Firebase App Check Configuration

**Error:** `App attestation failed` (403)

**Fix Options:**

#### Option A: Enable Debug Token (Development Only)
1. Go to Firebase Console → App Check
2. Add debug token: `2EF757CC-8F04-4302-BB44-06146D27ECFF`
3. This is already in your logs - just needs to be registered

#### Option B: Configure App Attest (Production)
1. Go to Firebase Console → App Check
2. Enable App Attest for iOS
3. Add your app's Bundle ID: `com.keontapeat.MyChannelApp`

---

### 5. RevenueCat Bundle ID Mismatch

**Error:** Bundle ID mismatch
- App Bundle ID: `com.keontapeat.MyChannelApp`
- RevenueCat Config: `live.mychannel.app`

**Fix:** Update RevenueCat configuration to match your app's Bundle ID

1. Go to RevenueCat Dashboard: https://app.revenuecat.com/projects/00019812/apps/app483872531e
2. Update the Bundle ID to: `com.keontapeat.MyChannelApp`

OR update your app's Bundle ID in Xcode to match RevenueCat config.

---

## ⚠️ WARNING ISSUES

### 6. Storage Usage Alert
**Current Usage:** 91.18% full

**Action Required:** Clean up storage or increase quota

---

### 7. Invalid Thumbnail URLs
**Error:** Multiple invalid Firebase Storage URLs with `:443` port in URL

**Pattern:** `https://firebasestorage.googleapis.com:443/...`

**Fix:** Remove the `:443` port from URLs. Firebase Storage URLs should be:
```
https://firebasestorage.googleapis.com/v0/b/...
```

Not:
```
https://firebasestorage.googleapis.com:443/v0/b/...
```

Check where these URLs are being generated and remove the port specification.

---

### 8. Videos with processingStatus=completed but Not Ready

**Issue:** 102 videos marked as "completed" but being skipped

**Log Pattern:** `⏭️ Skipping not-ready video (processingStatus=completed)`

**Investigation Needed:**
- Check what additional fields determine "ready" status
- Verify video processing pipeline is completing all steps
- May need to update video status or add missing fields

---

## 📋 QUICK ACTION CHECKLIST

- [ ] Add `FirebaseApp.configure()` to app initialization
- [ ] Create 3 Firestore composite indexes (click links above)
- [ ] Update Firestore Security Rules
- [ ] Register App Check debug token OR configure App Attest
- [ ] Fix RevenueCat Bundle ID mismatch
- [ ] Fix thumbnail URL generation (remove :443 port)
- [ ] Investigate video "ready" status logic
- [ ] Clean up storage (91% full)

---

## 🔧 TESTING AFTER FIXES

1. Clean build folder in Xcode
2. Delete app from simulator/device
3. Rebuild and reinstall
4. Check logs for:
   - ✅ Firebase initialized successfully
   - ✅ No index errors
   - ✅ Watch progress saves successfully
   - ✅ App Check passes
   - ✅ RevenueCat configured correctly

---

## 📞 SUPPORT LINKS

- Firebase Console: https://console.firebase.google.com/project/mychannel-ca26d
- Firestore Indexes: https://console.firebase.google.com/project/mychannel-ca26d/firestore/indexes
- Firestore Rules: https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules
- App Check: https://console.firebase.google.com/project/mychannel-ca26d/appcheck
- RevenueCat: https://app.revenuecat.com/projects/00019812/apps/app483872531e
