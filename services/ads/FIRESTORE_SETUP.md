# Firestore Setup for Ads Service

## Quick Setup (2 options)

### Option 1: Use Service Account Key (Recommended for Development)

1. **Go to Firebase Console:**
   https://console.firebase.google.com/project/mychannel-ca26d/settings/serviceaccounts/adminsdk

2. **Generate new private key:**
   - Click "Generate new private key"
   - Save the JSON file as `firebase-service-account.json` in the project root:
     `/Users/keonta/Documents/MyChannel/firebase-service-account.json`

3. **Update .env:**
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=/Users/keonta/Documents/MyChannel/firebase-service-account.json
   ```

4. **Run migration:**
   ```bash
   npm run migrate
   ```

### Option 2: Use Firestore Emulator (No Auth Needed)

1. **Start Firestore emulator:**
   ```bash
   cd /Users/keonta/Documents/MyChannel
   firebase emulators:start --only firestore
   ```

2. **Update .env** (uncomment the emulator line):
   ```bash
   FIRESTORE_EMULATOR_HOST=localhost:8080
   ```

3. **Run migration:**
   ```bash
   npm run migrate
   ```

## Current Status

✅ Stripe fully wired with live keys
✅ PostgreSQL removed, Firestore adapter created
✅ Firebase Admin SDK installed
⏳ Waiting for Firebase credentials

Choose one of the options above to complete setup!
