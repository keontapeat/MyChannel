# App Check for Money Endpoints (stub)

## Goal

Require valid Firebase App Check tokens on money Cloud Functions in addition to Firebase ID tokens, reducing scripted abuse of `/create-escrow-payment` and `/create-transfer`.

## Current auth stack

| Layer | Mechanism | Status |
|-------|-----------|--------|
| Client | `AuthTokenProvider.authorize(&request)` → `Authorization: Bearer <idToken>` | ✅ All escrow CF calls in `MoneyEscrowService` + `StripeConnectService` + `MerchCheckoutService` |
| Server | `requireAuth(req)` verifies ID token | ✅ `escrow-payments/index.js` |
| App Check | `X-Firebase-AppCheck` header | 🔲 Not enforced yet |

## Client audit (2026-07-09)

Money CF callers with `AuthTokenProvider.authorize`:

- `MoneyEscrowService` — create-escrow-payment, capture-payment, cancel-payment, create-transfer
- `StripeConnectService` — create-transfer
- `MerchCheckoutService` — create-merch-order
- `VSMatchComplianceService` — compliance writes (authenticated backend)

## Rollout plan

1. Enable App Check in Firebase console (**DeviceCheck** on iOS 11+, **App Attest** on iOS 14+).
2. Add `AppCheckTokenProvider` wrapper parallel to `AuthTokenProvider`.
3. Cloud Function middleware: reject missing/invalid App Check on money routes (403).
4. Gradual: log-only → enforce on staging → enforce production.

## DeviceCheck / App Attest for wager

| Platform | Provider | Enforced on |
|----------|----------|-------------|
| iOS 14+ | App Attest | `/create-escrow-payment`, `/create-transfer` |
| iOS 11–13 | DeviceCheck | Same routes (fallback) |
| Web | reCAPTCHA Enterprise | wallet + medals pages |

Wager flows are high-abuse targets — App Check is required **in addition to** Firebase Auth, not instead of compliance gates.

## Stripe Identity rate limit

`create-escrow-payment` already rate-limits 10 req/min per uid (in-memory). Identity session create should mirror:
- 5 sessions / uid / hour (Firestore counter or Redis)
- See `docs/cloud-function-iam-least-privilege.md` for SA scope

## Debug

Register debug tokens via `scripts/register-app-check-debug-token.sh` for Simulator/CI.

## Related

- `docs/certificate-pinning-plan.md`
- `docs/backend-money-runbook.md`
