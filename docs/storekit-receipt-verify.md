# StoreKit Receipt Verification — MyChannel Plus+

## Overview

Plus+ ad-free (`StoreKitService.shared.isPremium`) should be backed by **server-verified** subscription state, not client-only StoreKit 2 entitlements alone.

## Recommended flow

1. **Client:** `Transaction.currentEntitlements` or RevenueCat (`RevenueCatService`) after purchase.
2. **Client → Server:** POST signed transaction JWS / original transaction ID to Cloud Function.
3. **Server:** Verify with Apple App Store Server API (StoreKit 2) or RevenueCat webhook.
4. **Firestore:** `users/{uid}.subscriptionTier = plus` + `subscriptionExpiresAt`.
5. **Ads gate:** `AdsService.requestPreRoll` checks `StoreKitService.shared.isPremium` (client) **and** server should reject ad impressions for plus users in ad server config.

## Apple endpoints

- Production: `https://api.storekit.itunes.apple.com`
- Sandbox: `https://api.storekit-sandbox.itunes.apple.com`

Use **App Store Connect API key** (.p8) — store in Secret Manager, not repo.

## RevenueCat path (already registered)

`LazyServiceManager` loads RevenueCat at `.medium` priority when `AppSecrets.revenueCatAPIKey` is set. Prefer RevenueCat webhooks → Firestore over rolling custom receipt parsing.

## Fields to persist

```
users/{uid}
  subscriptionProductId: "mychannel_plus_monthly"
  subscriptionStatus: active | expired | grace
  subscriptionExpiresAt: Timestamp
  originalTransactionId: string
```

## Testing

- Sandbox Apple ID purchase → verify webhook updates Firestore within 60s.
- Confirm `AdsService` logs `Premium subscriber — no ads served`.
- Expire subscription → ads resume after cache TTL.
