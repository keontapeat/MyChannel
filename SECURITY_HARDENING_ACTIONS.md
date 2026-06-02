# 🔐 Security Hardening — What changed + what you must do

This documents the senior-level security pass. Code changes are done. A few
actions can only be done by you in dashboards/CLI — they are marked **ACTION**.

---

## ✅ Fixed in code (this pass)

### Payment / payout Cloud Functions — now authenticated
- `cloud-functions/music-payouts/index.js`: every money route
  (`requestPayout`, `payoutArtist`, `getAvailableBalance`, `claimOwedEarnings`,
  `createConnectOnboardingLink`) now requires a verified **Firebase ID token**
  (`Authorization: Bearer <token>`) and enforces `uid === artistId` (or admin).
  CORS locked to an allowlist (no more `*`).
- `cloud-functions/escrow-payments/index.js`:
  - All endpoints require a verified ID token.
  - `/create-transfer` no longer trusts client `amount`/`destination`. It derives
    the winner, payout amount, and destination **server-side** from the verified
    match outcome + captured escrow rows. Idempotency key prevents double-payout.
  - `/create-escrow-payment` resolves the Stripe customer **server-side** from the
    authenticated uid (ignores any client-supplied `customerId`). Validates
    integer cents.
  - Wallet deposits are credited **server-side via the Stripe webhook only**
    (`creditWallet`, idempotent) — never by the client.

### iOS client
- New `MyChannel/Core/Services/AuthTokenProvider.swift` attaches a fresh Firebase
  ID token to all money requests.
- `MoneyEscrowService`, `ArtistEarningsView` (payout + onboarding) now send the
  token.
- `StripeConnectService` **no longer uses the Stripe secret key on-device.**
  Account creation / onboarding / payment intents / balances now throw
  `mustUseBackend`; `transferToWinner` routes through the authenticated
  `/create-transfer`. (The secret key must never ship in the app.)
- VS-match wallet self-crediting removed (deposits + match winnings are credited
  server-side). Withdrawals are recorded as `pending` and processed server-side.
- Music `streamCount` is incremented **server-side** (new trigger
  `incrementStreamCountOnPlay` in `firebase/functions/src/index.ts`) from
  validated `music_plays` events — closes the "mint streams → cash out" exploit.

### Firestore rules (`firestore.rules`)
- Financial ledgers are now **read-own / write-server-only**: `transactions`,
  `creator_earnings`, `creator_payouts`, `earnings`, `tips`, `payments`,
  `ad_transactions`, `vs_match_wallets`, `premium_stats`, `referral_conversions`,
  `revenue_sharing`.
- `music_tracks.streamCount` is no longer client-writable (engagement counters
  like `likeCount` still are).
- Public unauthenticated writes removed from `doctor_reports`, `dr_drill_results`
  (admin-only) and `health_check` (auth required).
- `isAdmin()` now prefers a custom claim (`token.admin == true`) and requires a
  verified email for the email fallback.

### Storage rules (`storage.rules`)
- Per-type **size + content-type caps** on every upload path (image/video/audio/
  doc/caption) — stops storage-cost bombs and arbitrary-file hosting.
- Legacy flat paths (`user-avatars`, `user-banners`, `user-banner-videos`) now
  bind the filename to the caller's uid (no overwriting other users' files).
- `tournaments/**` is now admin-write; `isAdmin()` upgraded to custom-claim aware.

### Secrets hygiene
- Untracked `functions/.env.mychannel-ca26d` and `.ai_api_key` from git.
- `.gitignore` tightened (`**/.env*`, `functions/.env*`, `web-v2/.env.local`,
  `.ai_api_key`).

---

## ⚠️ ACTIONS you must do (cannot be done from code)

1. **Rotate leaked AI keys NOW.** A live OpenAI key and Anthropic key were found
   in `MyChannel/MyChannel/Config/Secrets.local.xcconfig` (gitignored, not in
   history — but treat as compromised). Rotate both in the OpenAI and Anthropic
   dashboards. Never ship model keys in the app; proxy AI calls through the
   backend.

2. **Set the Stripe secret key ONLY in the backend.** Set `STRIPE_SECRET_KEY` and
   `STRIPE_WEBHOOK_SECRET` as Cloud Function secrets (Secret Manager). Do **not**
   put `STRIPE_SECRET_KEY` in the iOS Keychain/plist/xcconfig anymore.

3. **Enable Firebase App Check enforcement** (console → App Check) for Firestore,
   Storage, and Cloud Functions. The iOS app already initializes App Attest;
   enforcement is what actually blocks curl/script abuse.

4. **Set an admin custom claim** for your admin uid(s) via the Admin SDK:
   `admin.auth().setCustomUserClaims(uid, { admin: true })`. Rules now honor it
   (the verified-email fallback still works in the meantime).

5. **Configure the Stripe webhook** to point at the escrow + music-payouts
   `/webhook` / `/stripeWebhook` routes so deposits/payouts settle server-side.

6. **Deploy (high-risk — review first):**
   - `firebase deploy --only firestore:rules,storage:rules`
   - `firebase deploy --only functions:story-functions` (stream-count trigger)
   - Redeploy `music-payouts` and `escrow-payments`.
   Test in Stripe **test mode** before going live.

---

## 🔭 Recommended next (not yet done)
- Move video/flick view & like counters to server-side increments + App Check
  (currently constrained client increments — fine for engagement, not money).
- Split world-readable `users/{uid}` PII (email, stripe ids, fcm tokens) into a
  private owner-only subcollection; keep only public profile fields readable.
- Build the server-side withdrawal payout worker that consumes `pending`
  `vs_match_withdrawals` and performs the Stripe transfer.
