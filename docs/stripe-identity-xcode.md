# Stripe Identity — Xcode Setup

VS Match KYC ($500+ wagers) uses **Stripe Identity** via `IdentityVerificationSheet`. The server creates a VerificationSession + ephemeral key; the iOS app never sees `sk_*`.

## 1. Add the SDK (Swift Package Manager)

**Already wired in this repo:** `MyChannel.xcodeproj` links product **`StripeIdentity`** from the existing `stripe-ios` package (`https://github.com/stripe/stripe-ios`). New files under `MyChannel/` are picked up via `PBXFileSystemSynchronizedRootGroup` — no manual file membership needed.

If Xcode still shows `unavailable` from the presenter:

1. Xcode → **File → Packages → Resolve Package Versions**
2. Target **MyChannel** → **Frameworks, Libraries, and Embedded Content** → confirm **StripeIdentity** is present
3. Clean build folder and rebuild

(Optional alternate package: `https://github.com/stripe/stripe-identity-ios` — not required when using monorepo `stripe-ios`.)

## 2. Verify compile flag

`StripeIdentityPresenter.swift` wraps the SDK in `#if canImport(StripeIdentity)`. After resolving packages, build once — the `#else` branch (`unavailable`) should no longer run on device.

## 3. No secret keys in the app

- Publishable key only in `AppSecrets.stripePublishableKey` (if used elsewhere).
- Identity session secrets come from Cloud Function `create_stripe_identity_session` (`functions/main.py`).
- **Never log** `ephemeralKeySecret` — see comments in `VSMatchComplianceService` / `StripeIdentityPresenter`.

## 4. Backend endpoints (already deployed)

| Function | Purpose |
|----------|---------|
| `create_stripe_identity_session` | POST `{ userId }` + Firebase Bearer → `{ sessionId, ephemeralKeySecret }` |
| `stripe_identity_webhook` | Stripe → updates `vs_match_compliance.kycStatus` |

Deploy: `./scripts/deploy-identity-escrow.sh`

## 5. Firestore fields written

```
vs_match_compliance/{userId}
  kycStatus: pending | approved | rejected
  stripeIdentitySessionId
  kycSubmittedAt / kycVerifiedAt
```

## 6. Manual test flow

1. Open **Versus Match Creator** with wager **> $500**.
2. Compliance sheet → **Verify Identity**.
3. Complete Stripe test document flow (test mode).
4. Webhook flips `kycStatus` → sheet polls every 5s while `pending`.
5. **Continue** enables when all gates pass.

## 7. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `unavailable` from presenter | StripeIdentity SPM not linked to target |
| HTTP 503 stripe_not_configured | Set `STRIPE_SECRET_KEY` on Cloud Function |
| Stuck on pending | Check `STRIPE_IDENTITY_WEBHOOK_SECRET` + Stripe dashboard endpoint |
| Build error on Identity | Match `stripe_version` in EphemeralKey.create to SDK docs |

## 8. App Store privacy

Declare **ID verification** usage in App Privacy / NSCameraUsageDescription if not already present for Identity selfie capture.
