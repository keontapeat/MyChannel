# Escrow Cloud Function Schema

Contract between iOS / web / Android clients and `cloud-functions/escrow-payments`.

## Base URL

```
https://us-central1-mychannel-ca26d.cloudfunctions.net/escrow-payments
```

Mirrors `MONEY_CONTRACT.escrow.apiBase` in `web-v2/lib/money-contract.ts`.

## Authentication

All mutating endpoints require:

```
Authorization: Bearer <Firebase ID token>
```

Server verifies token with Firebase Admin SDK and binds `uid` to the resource.

## Endpoints

### POST `/create-escrow-payment`

Creates a Stripe PaymentIntent and holds funds.

**Request body**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `amount` | integer cents | yes | 100 – 10_000_000 |
| `matchId` | string | yes | `versus_matches` doc id or `wallet_deposit` sentinel |
| `captureMethod` | string | no | `manual` (match) or `automatic` (wallet deposit) |

**Response 200**

```json
{
  "paymentIntentId": "pi_...",
  "clientSecret": "pi_..._secret_..."
}
```

**Errors**: 403 compliance reject, 400 invalid amount, 401 missing/invalid token.

### POST `/capture-payment`

Captures a held PaymentIntent after match resolution.

### POST `/cancel-payment`

Cancels/refunds a held PaymentIntent.

### POST `/create-transfer`

Transfers winner payout via Stripe Connect. Amount derived server-side from match outcome — client sends `matchId` only.

### POST `/webhook`

Stripe webhook — idempotent on `event.id` in `stripe_webhook_events`.

## Firestore collections

| Collection | Purpose |
|------------|---------|
| `versus_matches` | Match draft + outcome |
| `stripe_escrow` | PaymentIntent ↔ match linkage |
| `vs_match_wallets` | User balances (server-written) |
| `vs_match_transactions` | Ledger entries |
| `vs_match_compliance` | Age/KYC/terms profile |
| `stripe_webhook_events` | Webhook idempotency |

## Compliance gate (server)

`assertWagerCompliance(uid, amountCents)` runs before any PaymentIntent:

- Age 18+ (`vs_match_compliance.ageVerified`)
- KYC if amount > $500
- Region in `WAGER_POLICY.allowedRegions` (51 US states + DC)
- Terms version === `2025.1`
- Daily limit by account tier

## Money math

All amounts in integer cents. Fee and payout:

```
fee = round(grossCents * 0.10)
winnerPayout = grossCents - fee
```

Must match `MoneyMath` / `wager-policy.ts` / `WagerPolicy.swift`.

## Contract test

- iOS: `MyChannelTests/TermsVersionSyncTests.swift`, `MoneyEscrowMathTests.swift`
- Web: `web-v2/lib/wager-policy.test.ts`
- Android: `MoneyMathTest.kt` (phase-486)
