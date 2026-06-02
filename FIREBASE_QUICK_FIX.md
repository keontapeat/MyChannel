# 🔥 Firebase Quick Fix Guide

## ⚡ 15-Minute Fix Checklist

### ✅ Already Done
- Firebase initialization in app ✓

### 🎯 Do These Now (15 min total)

#### 1️⃣ Create 3 Firestore Indexes (5 min)
Just click each link and click "Create Index":

**Index 1:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoMCghpc1B1YmxpYxABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI

**Index 2:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoOCgp2aXNpYmlsaXR5EAEaFgoSY3JlYXRvclN1YnNjcmliZXJzEAIaEgoOZW5nYWdlbWVudFJhdGUQAhoNCgl2aWV3Q291bnQQAhoMCghfX25hbWVfXxAC

**Index 3:** https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=ClBwcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3BheW1lbnRzL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAE

---

#### 2️⃣ Update Security Rules (3 min)
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules
2. Add these rules (don't delete existing ones)
3. Click "Publish"

```javascript
match /watch_progress/{progressId} {
  allow read, write: if request.auth != null && 
    progressId.matches('^' + request.auth.uid + '_.*');
}

match /story_seen/{seenId} {
  allow read, write: if request.auth != null && 
    resource.data.userId == request.auth.uid;
}

match /notifications/{notificationId} {
  allow read: if request.auth != null && 
    resource.data.userId == request.auth.uid;
  allow write: if request.auth != null;
}
```

---

#### 3️⃣ Fix App Check (2 min - Pick ONE)

**Option A (Quick):**
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/appcheck
2. Add debug token: `2EF757CC-8F04-4302-BB44-06146D27ECFF`

**Option B (Better):**
1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/appcheck
2. Enable "App Attest" for iOS

---

#### 4️⃣ Fix RevenueCat (2 min)
1. Go to: https://app.revenuecat.com/projects/00019812/apps/app483872531e
2. Change Bundle ID to: `com.keontapeat.MyChannelApp`
3. Save

---

### 🧪 Test (3 min)
```bash
# Clean build in Xcode
Cmd+Shift+K

# Delete app from simulator
# Rebuild and run
```

**Check logs for:**
- ✅ No "requires an index" errors
- ✅ No "insufficient permissions" errors
- ✅ No App Check 403 errors
- ✅ RevenueCat initializes

---

### 🔧 Fix Thumbnail URLs (Later - 10 min)

```bash
# Download service account key from:
# https://console.firebase.google.com/project/mychannel-ca26d/settings/serviceaccounts/adminsdk
# Save as firebase-service-account.json

npm install firebase-admin
node scripts/fix-thumbnail-urls.js --dry-run  # Preview
node scripts/fix-thumbnail-urls.js            # Apply
```

---

## 📄 Full Documentation

- **FIREBASE_SETUP_COMPLETE.md** - Complete guide with explanations
- **FIREBASE_ACTION_PLAN.md** - Detailed step-by-step instructions
- **FIREBASE_FIXES_REQUIRED.md** - Technical details of all issues

---

## ✅ Done!

After completing steps 1-4, your app should work without Firebase errors.

**Total time:** ~15 minutes
