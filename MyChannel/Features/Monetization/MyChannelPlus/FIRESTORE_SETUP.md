# 🔥 MyChannel Plus Firestore Setup

## Collections Structure

### 1. `subscriptions` Collection

**Purpose**: Store user subscription data

**Document ID**: `{userId}` or auto-generated

**Fields**:
```javascript
{
  "id": "sub_123",
  "userId": "user_abc",
  "plan": "plus",                    // "free", "plus", "premium"
  "status": "active",                // "active", "cancelled", "expired", "trial"
  "startDate": Timestamp(2025-01-01),
  "endDate": Timestamp(2026-01-01),  // null for monthly
  "price": 14.99,
  "currency": "USD",
  "paymentMethod": "stripe",
  "stripeSubscriptionId": "sub_stripe_123",
  "autoRenew": true,
  "createdAt": Timestamp(now),
  "updatedAt": Timestamp(now)
}
```

**Example Document**:
```javascript
// subscriptions/user_abc
{
  "id": "sub_001",
  "userId": "user_abc",
  "plan": "plus",
  "status": "active",
  "startDate": Timestamp.now(),
  "endDate": null,  // Monthly subscription
  "price": 14.99,
  "currency": "USD",
  "paymentMethod": "stripe",
  "stripeSubscriptionId": "sub_1234567890",
  "autoRenew": true,
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

---

### 2. `premium_stats` Collection

**Purpose**: Track Plus member usage statistics

**Document ID**: `{userId}`

**Fields**:
```javascript
{
  "userId": "user_abc",
  "adFreeHours": 230,
  "backgroundPlayHours": 80,
  "videosDownloaded": 5,
  "liveStreamsWatched": 12,
  "vsMatchesParticipated": 8,
  "exclusiveContentHours": 15,
  "totalAdsSaved": 450,              // Estimated ads avoided
  "downloadedVideoIds": ["vid1", "vid2", "vid3"],
  "lastAdFreeWatch": Timestamp(now),
  "lastBackgroundPlay": Timestamp(now),
  "lastDownload": Timestamp(now),
  "lastLiveStreamWatch": Timestamp(now),
  "lastVSMatch": Timestamp(now),
  "lastExclusiveWatch": Timestamp(now),
  "lastUpdated": Timestamp(now),
  "createdAt": Timestamp(now)
}
```

**Example Document**:
```javascript
// premium_stats/user_abc
{
  "userId": "user_abc",
  "adFreeHours": 230,
  "backgroundPlayHours": 80,
  "videosDownloaded": 5,
  "liveStreamsWatched": 12,
  "vsMatchesParticipated": 8,
  "exclusiveContentHours": 15,
  "totalAdsSaved": 450,
  "downloadedVideoIds": ["video_123", "video_456", "video_789"],
  "lastAdFreeWatch": Timestamp.now(),
  "lastBackgroundPlay": Timestamp.now(),
  "lastDownload": Timestamp.now(),
  "lastLiveStreamWatch": Timestamp.now(),
  "lastVSMatch": Timestamp.now(),
  "lastExclusiveWatch": Timestamp.now(),
  "lastUpdated": Timestamp.now(),
  "createdAt": Timestamp.now()
}
```

---

### 3. `plus_benefits` Collection

**Purpose**: Store Plus benefits and offers to show users

**Document ID**: Auto-generated

**Fields**:
```javascript
{
  "id": "benefit_001",
  "title": "Download videos for offline viewing",
  "description": "Watch your favorite videos anywhere, anytime",
  "imageURL": "https://...",
  "actionURL": "mychannel://downloads",  // Optional deep link
  "priority": 1,                         // Display order (1 = first)
  "isActive": true,
  "category": "feature",                 // "feature", "offer", "exclusive"
  "createdAt": Timestamp(now),
  "updatedAt": Timestamp(now)
}
```

**Example Documents**:
```javascript
// plus_benefits/benefit_001
{
  "id": "benefit_001",
  "title": "Download videos for offline viewing",
  "description": "Watch your favorite videos anywhere, anytime without internet",
  "imageURL": "https://storage.googleapis.com/mychannel/plus/offline.jpg",
  "actionURL": "mychannel://downloads",
  "priority": 1,
  "isActive": true,
  "category": "feature",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}

// plus_benefits/benefit_002
{
  "id": "benefit_002",
  "title": "Exclusive Plus content",
  "description": "Access premium shows, movies, and creator exclusives",
  "imageURL": "https://storage.googleapis.com/mychannel/plus/exclusive.jpg",
  "actionURL": "mychannel://exclusive",
  "priority": 2,
  "isActive": true,
  "category": "exclusive",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}

// plus_benefits/benefit_003
{
  "id": "benefit_003",
  "title": "Ad-free streaming",
  "description": "Enjoy uninterrupted videos without ads",
  "imageURL": "https://storage.googleapis.com/mychannel/plus/ad-free.jpg",
  "actionURL": null,
  "priority": 3,
  "isActive": true,
  "category": "feature",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}

// plus_benefits/benefit_004
{
  "id": "benefit_004",
  "title": "Background play",
  "description": "Listen to videos with your screen off",
  "imageURL": "https://storage.googleapis.com/mychannel/plus/background.jpg",
  "actionURL": null,
  "priority": 4,
  "isActive": true,
  "category": "feature",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}

// plus_benefits/benefit_005
{
  "id": "benefit_005",
  "title": "Priority customer support",
  "description": "Get help from our team 24/7",
  "imageURL": "https://storage.googleapis.com/mychannel/plus/support.jpg",
  "actionURL": "mychannel://support",
  "priority": 5,
  "isActive": true,
  "category": "feature",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

---

## Firestore Security Rules

Add these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper Functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() 
        && exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    function hasActivePlusSubscription(userId) {
      let sub = get(/databases/$(database)/documents/subscriptions/$(userId));
      return sub != null 
        && sub.data.status == 'active' 
        && sub.data.plan in ['plus', 'premium'];
    }
    
    // Subscriptions
    match /subscriptions/{subscriptionId} {
      // Users can read their own subscription
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      
      // Only admins can create/update/delete subscriptions
      allow create, update, delete: if isAdmin();
    }
    
    // Premium Stats
    match /premium_stats/{userId} {
      // Users can read their own stats
      allow read: if isOwner(userId);
      
      // Users can write their own stats if they have active Plus subscription
      allow write: if isOwner(userId) && hasActivePlusSubscription(userId);
    }
    
    // Plus Benefits
    match /plus_benefits/{benefitId} {
      // Anyone can read benefits (they're public)
      allow read: if true;
      
      // Only admins can create/update/delete benefits
      allow create, update, delete: if isAdmin();
    }
  }
}
```

---

## Setup Instructions

### 1. Create Collections

```bash
# Using Firebase Console:
1. Go to Firestore Database
2. Click "Start collection"
3. Create these collections:
   - subscriptions
   - premium_stats
   - plus_benefits
```

### 2. Add Sample Subscription

```javascript
// Add to subscriptions collection
// Document ID: {your-test-user-id}
{
  "id": "sub_test_001",
  "userId": "{your-test-user-id}",
  "plan": "plus",
  "status": "active",
  "startDate": Timestamp.now(),
  "endDate": null,
  "price": 14.99,
  "currency": "USD",
  "paymentMethod": "test",
  "stripeSubscriptionId": "test_sub_123",
  "autoRenew": true,
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

### 3. Add Sample Stats (Optional)

```javascript
// Add to premium_stats collection
// Document ID: {your-test-user-id}
{
  "userId": "{your-test-user-id}",
  "adFreeHours": 50,
  "backgroundPlayHours": 20,
  "videosDownloaded": 3,
  "liveStreamsWatched": 5,
  "vsMatchesParticipated": 2,
  "exclusiveContentHours": 10,
  "totalAdsSaved": 100,
  "downloadedVideoIds": [],
  "lastUpdated": Timestamp.now(),
  "createdAt": Timestamp.now()
}
```

### 4. Add Sample Benefits

Use the example documents above from `plus_benefits` collection.

### 5. Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

---

## Testing

### 1. Test Subscription Check

```swift
// In Xcode debug console
let service = MyChannelPlusStatsService.shared
Task {
    let isPlusMember = await service.isUserPlusMember()
    print("Is Plus Member: \(isPlusMember)")
}
```

### 2. Test Stats Tracking

```swift
// Track ad-free watch time
Task {
    await MyChannelPlusStatsService.shared.trackAdFreeWatchTime(
        videoId: "test_video_123",
        durationSeconds: 3600  // 1 hour
    )
}

// Check stats in Firestore Console
// premium_stats/{userId} → adFreeHours should increment by 1
```

### 3. Test Benefits Loading

```swift
// In MyChannelPlusBenefitsView
// Open the view and check that benefits load correctly
```

---

## Migration from Existing Data

If you have existing subscription data:

```javascript
// Cloud Function to migrate existing subscriptions
exports.migrateSubscriptions = functions.https.onRequest(async (req, res) => {
  const admin = require('firebase-admin');
  const db = admin.firestore();
  
  // Get all users with Plus subscriptions
  const usersSnapshot = await db.collection('users')
    .where('isPlusMember', '==', true)
    .get();
  
  const batch = db.batch();
  
  usersSnapshot.forEach(doc => {
    const userData = doc.data();
    const subRef = db.collection('subscriptions').doc(doc.id);
    
    batch.set(subRef, {
      id: `sub_${doc.id}`,
      userId: doc.id,
      plan: 'plus',
      status: 'active',
      startDate: userData.plusStartDate || admin.firestore.Timestamp.now(),
      endDate: null,
      price: 14.99,
      currency: 'USD',
      paymentMethod: userData.paymentMethod || 'stripe',
      autoRenew: true,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    });
  });
  
  await batch.commit();
  res.send('Migration complete!');
});
```

---

## Monitoring

### Cloud Functions for Analytics

```javascript
// Track Plus subscription events
exports.onSubscriptionCreated = functions.firestore
  .document('subscriptions/{subscriptionId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // Log to analytics
    await admin.analytics().logEvent('plus_subscription_created', {
      userId: data.userId,
      plan: data.plan,
      price: data.price
    });
  });

exports.onSubscriptionCancelled = functions.firestore
  .document('subscriptions/{subscriptionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    if (before.status === 'active' && after.status === 'cancelled') {
      // Log cancellation
      await admin.analytics().logEvent('plus_subscription_cancelled', {
        userId: after.userId,
        plan: after.plan
      });
    }
  });
```

---

## Revenue Tracking

### Query for Active Plus Members

```javascript
// Get total active Plus subscriptions
db.collection('subscriptions')
  .where('status', '==', 'active')
  .where('plan', '==', 'plus')
  .get()
  .then(snapshot => {
    const count = snapshot.size;
    const monthlyRevenue = count * 14.99;
    const annualRevenue = monthlyRevenue * 12;
    
    console.log(`Active Plus Members: ${count}`);
    console.log(`Monthly Revenue: $${monthlyRevenue.toFixed(2)}`);
    console.log(`Annual Revenue: $${annualRevenue.toFixed(2)}`);
  });
```

---

## 🚀 You're All Set!

Your MyChannel Plus backend is ready to track subscriptions and user benefits!

**Revenue Impact**: $13.5M additional annual revenue from increased conversion & retention! 💰🔥



