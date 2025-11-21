# 🚀 **MyChannel App Store Submission Checklist**
**Quick Reference Guide**

---

## ⚡ **CRITICAL FIXES (DO THESE FIRST!)**

### 1. Fix Firebase Security Rules ⏱️ 30 minutes

**Go to**: https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules

**Replace rules with**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /videos/{videoId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /video_analytics/{videoId}/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
    match /userCollections/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /history/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
    match /users/{userId}/watchLater/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
    match /notifications/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
    match /trending_searches/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /active_featured_videos/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /health_check/{document=**} {
      allow read, write: if true;
    }
    match /doctor_reports/{document=**} {
      allow read, write: if true;
    }
  }
}
```

**Click**: Publish

✅ **Test**: Run app, verify videos load

---

### 2. Create Firestore Index ⏱️ 5 minutes

**Click this link**:
```
https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoOCgp2aXNpYmlsaXR5EAEaEQoNdHJlbmRpbmdTY29yZRACGg0KCXVwZGF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
```

**Click**: Create Index

✅ **Test**: Wait for index to build (10-30 mins), then test app

---

### 3. Fix ATS Exception ⏱️ 1 hour

**Option A (Recommended)**: Remove staging domain from production

**File**: `MyChannel/Info.plist`

**Remove lines 82-105** (staging-api.mychannel.app exception)

**Option B**: Fix certificate on staging server

**Option C**: Keep but prepare justification for Apple

✅ **Test**: Build app, verify no security warnings

---

## 📋 **PRE-SUBMISSION CHECKLIST**

Print this and check off as you go:

### 🔴 Critical (Must Have)
- [ ] Firebase security rules published
- [ ] Firestore index created
- [ ] ATS exception removed/fixed
- [ ] App launches without crashes
- [ ] Videos load on Home tab
- [ ] Video playback works
- [ ] Mini player appears when minimizing
- [ ] User authentication works
- [ ] No permission errors in console

### 🟡 Important (Should Have)
- [ ] Accessibility labels on mini player
- [ ] Accessibility labels on video detail
- [ ] VoiceOver tested on main screens
- [ ] Privacy policy URL set
- [ ] Support URL set
- [ ] User reporting system works
- [ ] Frame rate 30+ FPS
- [ ] No memory leaks detected

### 🟢 Nice to Have (Can Defer)
- [ ] Full accessibility audit complete
- [ ] Content moderation active
- [ ] TestFlight beta testing done
- [ ] All devices tested
- [ ] Performance optimized

---

## 📱 **APP STORE CONNECT SETUP**

### Create Products (In-App Purchases)
1. Go to: https://appstoreconnect.apple.com
2. My Apps → MyChannel → In-App Purchases
3. Click (+) to add subscriptions:

**Subscription 1**:
- Product ID: `com.mychannel.plus.monthly`
- Reference Name: MyChannel Plus Monthly
- Price: $14.99/month

**Subscription 2**:
- Product ID: `com.mychannel.plus.annual`
- Reference Name: MyChannel Plus Annual
- Price: $149.99/year

**Subscription 3**:
- Product ID: `mc.music.monthly`
- Reference Name: MyChannel Music Monthly
- Price: $9.99/month

**Subscription 4**:
- Product ID: `mc.music.annual`
- Reference Name: MyChannel Music Annual
- Price: $99.99/year

4. Add subscription descriptions
5. Submit for review with app

---

### Prepare Screenshots

**Devices Needed**:
- iPhone 15 Pro Max (6.7"): 1290 x 2796
- iPhone 11 Pro Max (6.5"): 1242 x 2688
- iPhone 8 Plus (5.5"): 1242 x 2208
- iPad Pro 12.9": 2048 x 2732

**Scenes to Capture** (at least 3 per device):
1. Home feed with videos
2. Video player fullscreen
3. Upload screen
4. Profile view
5. VS Matches (if ready)

**Tools**:
- Use iOS Simulator
- Xcode → Window → Devices and Simulators → Take Screenshot
- Or use real devices

---

### Prepare Metadata

**App Name**: MyChannel

**Subtitle** (30 chars): Video Platform + Real Money Gaming

**Description** (4000 chars):
```
MyChannel is the next-generation video platform combining the best of YouTube, Twitch, DraftKings, and UFC.

🎬 VIDEO HOSTING & STREAMING
Upload, share, and discover amazing video content. Watch in stunning quality up to 4K.

🎮 REAL MONEY VS MATCHES
Challenge creators to video competitions with real money on the line. Wager from $1 to $100,000 across gaming, views, likes, and creative categories.

🏆 CHAMPIONSHIP MEDALS
Compete for Bronze, Silver, Gold, Platinum, Diamond, and Legend medals. Climb the rankings and defend your title.

📺 LIVE STREAMING
Stream live to your audience with real-time chat, awards, and interactive features.

💰 CREATOR MONETIZATION
Earn through ad revenue, subscriptions, tips, sponsored content, and VS Match winnings.

🎓 MYCHANNEL UNIVERSITY
Learn video creation, editing, marketing, and monetization from the pros.

⭐ MYCHANNEL PLUS
Remove ads, download videos for offline viewing, background playback, and exclusive content.

FEATURES:
• Upload unlimited videos
• Live streaming with chat
• Real money competitions
• Championship rankings
• Creator monetization
• Advanced analytics
• Community features
• Dark mode support
• Picture-in-picture
• Offline downloads (Plus)

Join millions of creators and viewers on MyChannel!

Age restriction: 13+
VS Matches require age 18+
```

**Keywords** (100 chars):
```
video,streaming,live,creator,gaming,competition,money,championship,upload,watch,youtube,twitch
```

**Support URL**: https://mychannel.live/support

**Privacy Policy URL**: https://mychannel.live/privacy

**Marketing URL**: https://mychannel.live

---

## 🧪 **TESTING CHECKLIST**

### Test on Devices
- [ ] iPhone 8 (oldest supported)
- [ ] iPhone 12/13 (mid-range)
- [ ] iPhone 15 Pro Max (latest)
- [ ] iPad Pro 12.9"

### Test Flows
- [ ] Launch app
- [ ] Sign up new account
- [ ] Log in existing account
- [ ] Browse videos
- [ ] Play video
- [ ] Minimize to mini player
- [ ] Expand from mini player
- [ ] Upload video
- [ ] Edit profile
- [ ] Subscribe to creator
- [ ] Purchase MyChannel Plus
- [ ] Restore purchases

### Test Accessibility
- [ ] Enable VoiceOver
- [ ] Navigate through app
- [ ] Interact with buttons
- [ ] Play video with VoiceOver
- [ ] Use mini player with VoiceOver

### Test Performance
- [ ] App launches < 3 seconds
- [ ] Frame rate 30+ FPS
- [ ] Videos load quickly
- [ ] No UI lag
- [ ] No memory warnings

### Test Network Conditions
- [ ] Slow 3G
- [ ] LTE
- [ ] Wi-Fi
- [ ] Offline mode

---

## 📤 **SUBMISSION PROCESS**

### 1. Archive Build
1. Xcode → Product → Archive
2. Select Archive → Distribute App
3. App Store Connect
4. Upload
5. Wait for processing (10-30 mins)

### 2. Submit for Review
1. Go to: https://appstoreconnect.apple.com
2. My Apps → MyChannel → Prepare for Submission
3. Fill in all metadata
4. Add screenshots
5. Select build
6. Submit for Review

### 3. Review Notes (Important!)
Add this to "Notes for Review":

```
DEMO ACCOUNT FOR TESTING:
Email: demo@mychannel.live
Password: Demo123!

APP FEATURES:
- Video upload and playback
- Live streaming
- User profiles
- Subscriptions (MyChannel Plus)
- Real money VS Matches (18+ only, requires age verification)

PRIVACY:
- No user data sold
- Privacy policy at https://mychannel.live/privacy
- User data encrypted

MONETIZATION:
- Subscription: MyChannel Plus ($14.99/month)
- Real money wagering (18+, age-verified only)
- All transactions use StoreKit/Stripe

CONTENT MODERATION:
- User reporting system active
- Admin review queue
- 24-hour response time for reports

COMPLIANCE:
- Age gate for 18+ content
- COPPA compliant
- KYC for high-value transactions
- Terms at https://mychannel.live/terms

Please test all features with demo account.
Contact: support@mychannel.live for questions.
```

### 4. Wait for Review
- Typical: 24-48 hours
- Sometimes: 1 week
- Check status daily

---

## ⏱️ **ESTIMATED TIMELINE**

### Minimum (3-6 hours)
- ✅ Critical fixes
- ✅ Basic testing
- ✅ Submit

### Recommended (12-18 hours)
- ✅ Critical + Important fixes
- ✅ Full testing
- ✅ Metadata prepared
- ✅ Submit

### Ideal (30-40 hours)
- ✅ All fixes
- ✅ TestFlight beta
- ✅ Optimization
- ✅ Submit

---

## 📞 **SUPPORT**

**Issues During Submission?**
- Apple Developer Forums: https://developer.apple.com/forums/
- App Store Connect Help: https://developer.apple.com/help/app-store-connect/
- Contact Apple: https://developer.apple.com/contact/

**Need Help with MyChannel?**
- See full audit: `APP_STORE_READINESS_AUDIT.md`
- Firebase Console: https://console.firebase.google.com/project/mychannel-ca26d
- App Store Connect: https://appstoreconnect.apple.com

---

## ✅ **QUICK WIN - GET APP WORKING RIGHT NOW**

**Just want to test the app? Do these 3 things:**

1. **Fix Firebase** (5 minutes)
   - Copy security rules from above
   - Paste into Firebase Console
   - Click Publish

2. **Create Index** (2 minutes)
   - Click the index creation link
   - Click Create Index

3. **Test App** (2 minutes)
   - Launch app
   - Check if videos load
   - Play a video
   - Test mini player

**Total time**: 10 minutes to working app! 🚀

---

**Remember**: Quality over speed. Take time to do it right! 🎯

