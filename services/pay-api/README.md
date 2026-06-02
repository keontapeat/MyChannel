# MyChannel Pay API

Production-ready payment infrastructure for creator monetization.

## Features

- ✅ **Stripe Connect** — Creator bank account onboarding
- ✅ **Ledger-based accounting** — Immutable transaction log
- ✅ **Payout processing** — Validates balance, executes Stripe transfers
- ✅ **Webhook handling** — Real-time transfer status updates
- ✅ **Scheduled auto-payouts** — Configurable threshold
- ✅ **Tax reporting** — 1099 generation for US creators
- ✅ **Multi-currency** — 150+ countries via Stripe
- ✅ **IAP tipping** — Apple-compliant viewer→creator tips

## Quick Start

### 1. Set Environment Variables

```bash
export DATABASE_URL="postgresql://user:pass@host:5432/mychannel"
export STRIPE_SECRET="sk_live_..."
export APP_BASE_URL="https://mychannel.live"
export STRIPE_WEBHOOK_SECRET="whsec_..."
export CRON_SECRET="your-secure-random-string"
```

### 2. Run the Service

```bash
./start.sh
```

This will:
1. Install dependencies (`npm install`)
2. Run database migration (`node src/migrate.js`)
3. Start the service on port 8888

### 3. Verify

```bash
curl http://localhost:8888/health
# Expected: {"status":"ok"}
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | ✅ Yes | — | PostgreSQL connection string |
| `STRIPE_SECRET` | ⚠️ Recommended | `sk_test_123` | Stripe secret key (live or test) |
| `APP_BASE_URL` | ⚠️ Recommended | `https://mychannel.live` | Your production domain |
| `STRIPE_WEBHOOK_SECRET` | ⚠️ Recommended | — | Webhook signing secret from Stripe |
| `CRON_SECRET` | Optional | — | Auth token for cron endpoints |
| `AUTO_PAYOUT_THRESHOLD_CENTS` | Optional | `10000` | Auto-payout threshold ($100) |
| `PORT` | Optional | `8888` | Server port |

## API Endpoints

See [API_REFERENCE.md](./API_REFERENCE.md) for complete documentation.

**Core endpoints:**
- `GET /health` — Health check
- `POST /pay/connect/link` — Generate Stripe onboarding URL
- `GET /pay/connect/status/:userId` — Check Stripe account status
- `POST /pay/withdraw` — Execute payout
- `GET /pay/creator/:userId/summary` — Get balance + recent transactions
- `POST /pay/webhooks/stripe` — Stripe webhook handler
- `POST /pay/tip/iap` — Record IAP tip
- `GET /pay/tax/1099/:userId/:year` — Generate 1099 data

## Database Schema

### `pay_accounts`
Stripe Connect account tracking.

| Column | Type | Description |
|--------|------|-------------|
| `id` | serial | Primary key |
| `user_id` | text | Creator user ID (unique) |
| `stripe_account_id` | text | Stripe Connect account ID |
| `status` | text | `pending`, `active` |
| `auto_payout_enabled` | boolean | Auto-payout enabled |
| `auto_payout_threshold` | integer | Threshold in cents |
| `last_payout_at` | timestamptz | Last payout timestamp |

### `ledger_accounts`
Account types (creator, platform, tax).

| Column | Type | Description |
|--------|------|-------------|
| `id` | serial | Primary key |
| `user_id` | text | User ID |
| `type` | text | `creator`, `platform`, `tax` |

### `ledger_entries`
Immutable transaction log.

| Column | Type | Description |
|--------|------|-------------|
| `id` | serial | Primary key |
| `account_id` | integer | References `ledger_accounts(id)` |
| `amount` | numeric(20,0) | Amount in cents |
| `currency` | text | `usd`, `eur`, etc. |
| `direction` | text | `credit` or `debit` |
| `reference_type` | text | `tip`, `ads`, `payout`, etc. |
| `reference_id` | text | External reference ID |
| `metadata` | jsonb | Additional data |
| `created_at` | timestamptz | Transaction timestamp |

## Stripe Setup

### 1. Enable Stripe Connect

1. Log into [Stripe Dashboard](https://dashboard.stripe.com)
2. Go to **Settings → Connect**
3. Enable **Express accounts**
4. Set platform name to **"MyChannel"**

### 2. Configure Webhooks

1. Go to **Developers → Webhooks**
2. Click **Add endpoint**
3. Set URL: `https://your-domain.com/pay/webhooks/stripe`
4. Select events:
   - `transfer.paid`
   - `transfer.failed`
   - `transfer.reversed`
   - `account.updated`
5. Copy the **Signing secret** and set as `STRIPE_WEBHOOK_SECRET`

### 3. Test Webhooks

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to local server
stripe listen --forward-to localhost:8888/pay/webhooks/stripe

# Trigger test events
stripe trigger transfer.paid
stripe trigger transfer.failed
```

## Scheduled Auto-Payouts

Set up a cron job to run auto-payouts daily:

### Using Cloud Scheduler (Google Cloud)

```bash
gcloud scheduler jobs create http auto-payouts \
  --schedule="0 2 * * *" \
  --uri="https://your-domain.com/pay/scheduled-payouts/run" \
  --http-method=POST \
  --headers="Authorization=Bearer YOUR_CRON_SECRET"
```

### Using GitHub Actions

Create `.github/workflows/auto-payouts.yml`:

```yaml
name: Auto Payouts
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger auto-payouts
        run: |
          curl -X POST https://your-domain.com/pay/scheduled-payouts/run \
            -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}"
```

## Testing

### Local Development

```bash
# Start the service
./start.sh

# Test health
curl http://localhost:8888/health

# Test Connect link
curl -X POST http://localhost:8888/pay/connect/link \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-user-123"}'

# Test withdrawal (requires balance)
curl -X POST http://localhost:8888/pay/withdraw \
  -H "Content-Type: application/json" \
  -d '{"creatorId":"test-user-123","amount":10.00}'
```

### Webhook Testing

```bash
stripe listen --forward-to localhost:8888/pay/webhooks/stripe
stripe trigger transfer.paid
```

## Monitoring

### Key Metrics

```sql
-- Total payouts (last 30 days)
SELECT COUNT(*), SUM(amount) / 100.0 AS total
FROM ledger_entries
WHERE reference_type = 'payout'
  AND created_at >= NOW() - INTERVAL '30 days';

-- Payout success rate
SELECT 
  COUNT(*) FILTER (WHERE metadata->>'status' IS NULL) AS successful,
  COUNT(*) FILTER (WHERE metadata->>'status' = 'failed') AS failed
FROM ledger_entries
WHERE reference_type = 'payout'
  AND created_at >= NOW() - INTERVAL '30 days';

-- Top earners
SELECT 
  la.user_id,
  SUM(le.amount) / 100.0 AS total_earnings
FROM ledger_entries le
JOIN ledger_accounts la ON la.id = le.account_id
WHERE le.direction = 'credit'
  AND le.created_at >= NOW() - INTERVAL '30 days'
GROUP BY la.user_id
ORDER BY total_earnings DESC
LIMIT 50;
```

## Security

- ✅ **PCI Compliant** — Stripe handles all sensitive payment data
- ✅ **Webhook verification** — Signature validation prevents spoofing
- ✅ **Idempotent operations** — Safe to retry
- ✅ **Atomic transactions** — Ledger debits happen with Stripe transfers
- ✅ **Audit trail** — Every transaction logged with metadata

## Troubleshooting

### "Payout account setup is incomplete"
**Cause:** Creator hasn't finished Stripe Express onboarding  
**Fix:** Have creator complete onboarding via `/pay/connect/link`

### "Webhook signature verification failed"
**Cause:** `STRIPE_WEBHOOK_SECRET` is incorrect or missing  
**Fix:** Copy signing secret from Stripe Dashboard → Webhooks

### "Transfer failed" webhook received
**Cause:** Stripe couldn't complete the transfer  
**Fix:** Check Stripe Dashboard → Transfers for failure reason

## Documentation

- [API Reference](./API_REFERENCE.md) — Complete endpoint documentation
- [Deployment Guide](../../CREATOR_MONETIZATION_DEPLOYMENT.md) — Full deployment instructions
- [Stripe Connect Docs](https://stripe.com/docs/connect) — Official Stripe documentation

## Support

Questions? Check the [deployment guide](../../CREATOR_MONETIZATION_DEPLOYMENT.md) or review backend logs.

---

**Built with ❤️ for creators**
