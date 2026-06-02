# 🔥 Firebase Configuration - Immediate Action Plan

## 📋 PRIORITY CHECKLIST

Complete these tasks in order. Each should take 2-5 minutes.

---

## 🎯 STEP 1: Create Firestore Composite Indexes (5 minutes)

**Why:** Your app queries are failing because Firestore needs indexes for complex queries.

**Action:** Click each link below and click "Create Index" in Firebase Console:

### Index 1: Videos Public Feed
**Click here:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoMCghpc1B1YmxpYxABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI

Fields: `isPublic` (Asc) + `createdAt` (Desc)

---

### Index 2: Videos Discovery Feed
**Click here:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoOCgp2aXNpYmlsaXR5EAEaFgoSY3JlYXRvclN1YnNjcmliZXJzEAIaEgoOZW5nYWdlbWVudFJhdGUQAhoNCgl2aWV3Q291bnQQAhoMCghfX25hbWVfXxAC

Fields: `visibility` (Asc) + `creatorSubscribers` (Desc) + `engagementRate` (Desc) + `viewCount` (Desc)

---

### Index 3: Payments Query
**Click here:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=ClBwcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3BheW1lbnRzL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAE

Fields: `status` (Asc) + `timestamp` (Asc)

---

**Note:** Indexes take 5-10 minutes to build. You'll see "Building..." status in Firebase Console.

---

## 🔒 STEP 2: Update Firestore Security Rules (3 minutes)

**Why:** Users can't save watch progress, view stories, or receive notifications due to permission errors.

**Action:**
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules
2. Replace the rules with the code below
3. Click "Publish"

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
    
    // Add your existing rules for other collections below
    // ...
  }
}
```

---

## 🛡️ STEP 3: Configure Firebase App Check (2 minutes)

**Why:** App Check is failing with 403 errors, blocking some Firebase services.

**Action - Choose ONE option:**

### Option A: Debug Token (Quick - For Development)
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/appcheck
2. Click "Apps" tab
3. Find your iOS app
4. Click "Manage debug tokens"
5. Add this token: `2EF757CC-8F04-4302-BB44-06146D27ECFF`
6. Save

### Option B: App Attest (Recommended - For Production)
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/appcheck
2. Click "Apps" tab
3. Find your iOS app: `com.keontapeat.MyChannelApp`
4. Enable "App Attest"
5. Save

---

## 💳 STEP 4: Fix RevenueCat Bundle ID (2 minutes)

**Why:** RevenueCat is configured for wrong Bundle ID, causing subscription errors.

**Current State:**
- App Bundle ID: `com.keontapeat.MyChannelApp`
- RevenueCat Config: `live.mychannel.app` ❌

**Action:**
1. Go to: https://app.revenuecat.com/projects/00019812/apps/app483872531e
2. Update Bundle ID to: `com.keontapeat.MyChannelApp`
3. Save changes

---

## ⚠️ STEP 5: Fix Thumbnail URLs (Code Fix Required)

**Why:** Thumbnail URLs have invalid `:443` port causing loading failures.

**Problem:** URLs look like:
```
https://firebasestorage.googleapis.com:443/v0/b/...
```

**Should be:**
```
https://firebasestorage.googleapis.com/v0/b/...
```

**Action:** Find where thumbnail URLs are generated and remove the `:443` port specification.

**Search for:**
```bash
grep -r "firebasestorage.googleapis.com:443" MyChannel/
```

---

## 📊 STEP 6: Storage Cleanup (Optional - Not Urgent)

**Current Usage:** 91.18% full

**Action (when convenient):**
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/storage
2. Review and delete old/unused files
3. Or upgrade storage quota

---

## 🎬 STEP 7: Investigate Video Processing (Optional)

**Issue:** 102 videos marked as "completed" but app skips them as "not ready"

**Action:** Check video processing logic to understand what makes a video "ready" beyond `processingStatus=completed`.

---

## ✅ TESTING CHECKLIST

After completing Steps 1-4, test your app:

1. **Clean Build:**
   - Xcode → Product → Clean Build Folder (Cmd+Shift+K)
   - Delete app from simulator/device
   - Rebuild and install

2. **Verify Fixes:**
   - [ ] App launches without Firebase errors
   - [ ] Videos load in feed (no index errors)
   - [ ] Watch progress saves successfully
   - [ ] Stories load and mark as seen
   - [ ] Notifications appear
   - [ ] App Check passes (no 403 errors)
   - [ ] RevenueCat initializes correctly

3. **Check Logs:**
   - Look for ✅ success messages
   - No more "requires an index" errors
   - No more "insufficient permissions" errors
   - No more App Check 403 errors

---

## 📞 QUICK LINKS

- **Firebase Console:** https://console.firebase.google.com/project/mychannel-ca26d
- **Firestore Indexes:** https://console.firebase.google.com/project/mychannel-ca26d/firestore/indexes
- **Firestore Rules:** https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules
- **App Check:** https://console.firebase.google.com/project/mychannel-ca26d/appcheck
- **Storage:** https://console.firebase.google.com/project/mychannel-ca26d/storage
- **RevenueCat:** https://app.revenuecat.com/projects/00019812/apps/app483872531e

---

## 🎯 SUMMARY

**Critical (Do Now):**
1. ✅ Create 3 Firestore indexes (click links)
2. ✅ Update Firestore Security Rules (copy/paste)
3. ✅ Configure App Check (add debug token OR enable App Attest)
4. ✅ Fix RevenueCat Bundle ID

**Important (Do Soon):**
5. Fix thumbnail URL generation (remove :443 port)

**Optional (Do Later):**
6. Clean up storage (91% full)
7. Investigate video "ready" status logic

**Estimated Time:** 15-20 minutes for critical fixes

---

## 💡 NEED HELP?

If you encounter issues:
1. Check Firebase Console for error messages
2. Review Xcode console logs after clean build
3. Verify indexes show "Enabled" status (not "Building")
4. Confirm security rules published successfully
