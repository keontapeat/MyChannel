# 🔥 **LOGIN TO FIREBASE CLI AND DEPLOY INDEX**

**Open your terminal and run these commands!**

---

## ⚡ **STEP 1: LOGIN TO FIREBASE**

**Open Terminal and run**:
```bash
cd /Users/keonta/Documents/MyChannel
firebase login
```

**This will**:
1. Open a browser window
2. Ask you to sign in with Google
3. Authorize Firebase CLI
4. Return to terminal with "✅ Success!"

---

## ⚡ **STEP 2: DEPLOY THE INDEX**

**Once logged in, run**:
```bash
firebase deploy --only firestore:indexes --project mychannel-ca26d
```

**This will**:
1. Read `firestore.indexes.json` (I just created it!)
2. Deploy the index to Firebase
3. Start building the index
4. Show "✅ Deploy complete!"

---

## ⚡ **ALTERNATIVE: ONE COMMAND**

**Or just run this all at once**:
```bash
cd /Users/keonta/Documents/MyChannel && firebase login && firebase deploy --only firestore:indexes --project mychannel-ca26d
```

---

## ✅ **VERIFICATION**

After deployment:
```
✅ Deploy complete!
⏳ Index building... (10-30 minutes)
```

Then refresh the Indexes page in Firebase Console - you'll see the new index!

---

## 🎯 **OR MANUAL WAY (IF CLI DOESN'T WORK)**

**In Firebase Console** (where you are now):

1. Click the blue **"Add index"** button (top right)
2. Fill in:
   - Collection: `videos`
   - Field 1: `visibility` (Ascending)
   - Field 2: `trendingScore` (Descending)
   - Field 3: `updatedAt` (Descending)
3. Click "Create"

**Time: 2 minutes** ⏱️

---

**CHOOSE YOUR METHOD AND DO IT NOW!** 🔥💪

