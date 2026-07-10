# Backend Money Runbook

Operational guide for VS Match escrow, wallet credits, Stripe Identity KYC, and related Cloud Functions.

## Services

| Service | Region | Entry |
|---------|--------|-------|
| `escrow-payments` | `us-central1` | `cloud-functions/escrow-payments/index.js` |
| `create_stripe_identity_session` | `us-east1` | Firebase Python (`functions/`) |
| `stripe_identity_webhook` | `us-east1` | Firebase Python (`functions/`) |

Deploy everything:

```bash
export STRIPE_SECRET_KEY=sk_live_...
export STRIPE_WEBHOOK_SECRET=whsec_...
export STRIPE_IDENTITY_WEBHOOK_SECRET=whsec_...
bash scripts/deploy-identity-escrow.sh
```

## Terms version pin

Server, iOS, and web must agree on the active terms version before any wager is held.

| Layer | Location | Constant |
|-------|----------|----------|
| iOS | `WagerPolicy.currentTermsVersion` | `2025.1` |
| Web | `web-v2/lib/wager-policy.ts` → `WAGER_POLICY.currentTermsVersion` | `2025.1` |
| CF | `escrow-payments/index.js` → `WAGER_POLICY.currentTermsVersion` | `2025.1` |

**Redeploy checklist when terms change:**

1. Bump `currentTermsVersion` in all three locations (same string).
2. Redeploy `escrow-payments` so `assertWagerCompliance` rejects stale acceptances.
3. Ship iOS + web so client preflight matches server.
4. Communicate re-accept flow in-app (compliance sheet / web banner).

## Escrow redeploy (money-critical)

```bash
cd cloud-functions/escrow-payments
gcloud functions deploy escrow-payments \
  --gen2 --runtime=nodejs20 --region=us-central1 --project=mychannel-ca26d \
  --source=. --entry-point=escrowPayments --trigger-http --allow-unauthenticated \
  --memory=256MB --timeout=60s \
  --set-env-vars "STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY,STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET"
```

Post-deploy smoke:

```bash
curl -s "https://us-central1-mychannel-ca26d.cloudfunctions.net/escrow-payments/health"
```

## Webhook idempotency

Stripe retries webhooks. The handler deduplicates on `event.id`:

- Collection: `stripe_webhook_events`
- Document ID: Stripe event id (e.g. `evt_...`)
- Duplicate events return `200 { received: true, duplicate: true }` without re-processing

Wallet credits use a second idempotency layer in `creditWallet()`:

- Collection: `vs_match_wallet_credits`
- Document ID: `paymentIntent.id` or transfer id
- Transaction guard prevents double-crediting balances

**Payout idempotency:** `create-transfer` uses Stripe idempotency key `vs_match_payout_{matchId}` and sets `match.payoutTransferId` before returning.

## Rate limits

`POST /create-escrow-payment` enforces an in-memory per-uid limit:

- Window: 60 seconds
- Max: 10 requests per uid per window
- Response: `429 Rate limit exceeded`

> Cold starts reset counters. For multi-instance production, move buckets to Redis or Firestore.

## Money safety invariants (verify after each deploy)

1. **create-escrow-payment** — `customerId` resolved server-side from `users/{uid}.stripeCustomerId`; never from request body.
2. **create-escrow-payment** — `assertWagerCompliance` runs before PaymentIntent creation (except `wallet_deposit`).
3. **create-transfer** — Client may only send `matchId`. Winner, amount, and destination are derived from Firestore + captured escrow rows.
4. **Wallet deposits** — `matchId === 'wallet_deposit'`; balance credited only in webhook via `creditWallet()`.
5. **CORS** — Allowlist only; never reflect arbitrary `Origin` on money endpoints.

## Stripe Dashboard webhooks

Configure two endpoints:

1. **Payments** → `https://us-central1-mychannel-ca26d.cloudfunctions.net/escrow-payments/webhook`
   - Events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `transfer.created`, `payout.paid`, `account.updated`
   - Secret → `STRIPE_WEBHOOK_SECRET`

2. **Identity** → `https://us-east1-mychannel-ca26d.cloudfunctions.net/stripe_identity_webhook`
   - Events: `identity.verification_session.*`
   - Secret → `STRIPE_IDENTITY_WEBHOOK_SECRET`

## Incident response

| Symptom | Check | Action |
|---------|-------|--------|
| 403 on wager | `vs_match_compliance/{uid}` + `users/{uid}.region` | User must pass age/KYC/terms/region/daily limit |
| 409 no customer | `users/{uid}.stripeCustomerId` | Onboard payment profile first |
| Double wallet credit | `vs_match_wallet_credits/{pi_id}` | Should be empty for new intents; investigate webhook retries |
| Payout twice | `versus_matches/{id}.payoutTransferId` | Must be set after first successful transfer |

## Related docs

- Web contract: `web-v2/lib/money-contract.ts`
- iOS protocols: `MoneyEscrowing.swift`, `ComplianceChecking.swift`
- Deploy script: `scripts/deploy-identity-escrow.sh`
- App Check plan: `docs/app-check-money.md`
- Auth audit: `docs/app-check-money.md` (AuthTokenProvider on all money CF clients)

## Staging vs production Stripe keys

| Environment | Key prefix | Where set |
|-------------|------------|-----------|
| Staging / dev | `sk_test_`, `pk_test_` | `functions/.env`, Cloud Function env vars, local Xcode scheme env |
| Production | `sk_live_`, `pk_live_` | GCP Secret Manager / deploy script only — never in repo |

**Rules:**

1. iOS client ships **publishable** key only (`AppSecrets.stripePublishableKey`, Keychain-first).
2. Secret keys (`STRIPE_SECRET_KEY`, webhook secrets) live in Cloud Function env — see `scripts/deploy-identity-escrow.sh`.
3. Staging deploys must use test-mode keys so Simulator and web-v2 `/wallet/deposit` never hit live rails.
4. Rotate keys per `docs/secrets-rotation-checklist.md` after any leak scan failure.

## Daily limits Firestore index

`assertWagerCompliance` queries:

```
vs_match_transactions
  .where('userId', '==', uid)
  .where('type', '==', 'wager')
  .where('createdAt', '>', startOfDayUTC)
```

**Required composite index** (deploy via Firebase console link in CF error or `firestore.indexes.json`):

| Collection | Fields |
|------------|--------|
| `vs_match_transactions` | `userId` ASC, `type` ASC, `createdAt` ASC |

Without this index, wager creation fails at compliance check with `FAILED_PRECONDITION`.

## Daily wager limit reset (`reset_daily_wager_limits`)

Daily limits are enforced by **UTC midnight window** in `assertWagerCompliance` (queries `vs_match_transactions` where `createdAt > startOfDay`). No rollover collection is required for correctness.

**Optional scheduled job (stub — not deployed):**

```javascript
// Cloud Scheduler → Pub/Sub → Cloud Function (future)
// exports.resetDailyWagerLimits = async () => {
//   // Archive yesterday's wager totals for analytics; limits auto-reset at UTC 00:00.
//   console.log('[reset_daily_wager_limits] noop — limits are windowed, not stored counters');
// };
```

If per-user **persistent counters** are added later, deploy a scheduled function at `0 0 * * *` UTC to zero `vs_match_compliance.dailyWageredUSD` (or equivalent).

## Identity webhook KYC

`stripe_identity_webhook` in `functions/main.py` writes:

- `kycStatus: "approved"` on `identity.verification_session.verified`
- `kycStatus: "rejected"` on canceled sessions
- `kycVerifiedAt` timestamp when approved

Verified 2026-07-09 — no code change required.

