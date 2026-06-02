# Pay API — Complete Endpoint Reference

Base URL: `https://your-domain.com` (or `http://localhost:8888` for local dev)

---

## 🏥 Health & Admin

### `GET /health`
Health check endpoint.

**Response:**
```json
{ "status": "ok" }
```

### `POST /migrate`
Run database migrations (creates tables, indexes).

**Response:**
```json
{ "ok": true }
```

---

## 💳 Stripe Connect (Creator Onboarding)

### `POST /pay/connect/link`
Generate Stripe Express onboarding URL for a creator.

**Request:**
```json
{
  "userId": "creator123"
}
```

**Response:**
```json
{
  "url": "https://connect.stripe.com/express/oauth/authorize?..."
}
```

**Errors:**
- `400` — Missing `userId`
- `500` — Stripe API error

---

### `GET /pay/connect/status/:userId`
Check Stripe Connect account status and sync to database.

**Response:**
```json
{
  "connected": true,
  "payoutsEnabled": true,
  "chargesEnabled": true,
  "status": "active",
  "detailsSubmitted": true
}
```

---

## 💰 Payouts & Withdrawals

### `POST /pay/withdraw`
Execute a payout (withdrawal) for a creator.

**Request:**
```json
{
  "creatorId": "creator123",
  "amount": 50.00
}
```

**Response (success):**
```json
{
  "ok": true,
  "payoutId": "payout_1234567890_abc123",
  "amountCents": 5000,
  "stripeTransferId": "tr_1234567890",
  "balance": {
    "accountId": 42,
    "credits": 10000,
    "debits": 5000,
    "availableBalance": 5000
  }
}
```

**Response (error):**
```json
{
  "error": "Insufficient balance",
  "availableBalance": 2500
}
```

**Errors:**
- `400` — Missing `creatorId` or `amount`, or amount below minimum ($1.00)
- `422` — Insufficient balance, Stripe account not connected, or onboarding incomplete
- `502` — Stripe API error

---

### `GET /pay/creator/:userId/payouts`
Get payout history for a creator.

**Response:**
```json
{
  "userId": "creator123",
  "payouts": [
    {
      "id": 1,
      "amount": "5000",
      "currency": "usd",
      "direction": "debit",
      "reference_type": "payout",
      "reference_id": "payout_1234567890_abc123",
      "metadata": {
        "stripeTransferId": "tr_1234567890",
        "stripeAccountId": "acct_1234567890"
      },
      "created_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

---

### `GET /pay/creator/:userId/summary`
Get creator's balance summary and recent transactions.

**Response:**
```json
{
  "userId": "creator123",
  "balance": {
    "accountId": 42,
    "credits": 15000,
    "debits": 5000,
    "availableBalance": 10000
  },
  "recentEntries": [
    {
      "amount": "5000",
      "currency": "usd",
      "direction": "debit",
      "reference_type": "payout",
      "metadata": { "stripeTransferId": "tr_1234567890" },
      "created_at": "2024-01-15T10:30:00Z"
    },
    {
      "amount": "2500",
      "currency": "usd",
      "direction": "credit",
      "reference_type": "ads",
      "metadata": { "campaignId": "camp_123" },
      "created_at": "2024-01-14T15:20:00Z"
    }
  ]
}
```

---

## 💸 Tipping

### `POST /pay/tip/intent`
Create a Stripe PaymentIntent for a tip (web/non-IAP tipping).

**Request:**
```json
{
  "toUserId": "creator123",
  "amount": 500,
  "currency": "usd"
}
```

**Response:**
```json
{
  "clientSecret": "pi_1234567890_secret_abc123",
  "paymentIntentId": "pi_1234567890",
  "mode": "stripe",
  "currency": "usd",
  "amount": 500
}
```

---

### `POST /pay/tip`
Confirm a tip after Stripe PaymentIntent succeeds.

**Request:**
```json
{
  "toUserId": "creator123",
  "amount": 500,
  "currency": "usd",
  "message": "Great video!",
  "paymentIntentId": "pi_1234567890"
}
```

**Response:**
```json
{
  "ok": true,
  "tipId": "tip_1234567890",
  "transactionId": "pi_1234567890",
  "balance": {
    "accountId": 42,
    "credits": 15500,
    "debits": 5000,
    "availableBalance": 10500
  }
}
```

---

### `POST /pay/tip/iap`
Record a tip from Apple In-App Purchase.

**Request:**
```json
{
  "fromUserId": "viewer456",
  "toUserId": "creator123",
  "amount": 630,
  "currency": "usd",
  "message": "Love your content!",
  "transactionId": "1000000123456789",
  "productId": "com.mychannel.tip.10",
  "credits": 10
}
```

**Response:**
```json
{
  "ok": true,
  "tipId": "iap_tip_1234567890_abc123",
  "balance": {
    "accountId": 42,
    "credits": 16130,
    "debits": 5000,
    "availableBalance": 11130
  }
}
```

**Notes:**
- `amount` is in cents (630 = $6.30, which is 63% of $10 after Apple's 30% + MyChannel's 7%)
- Add server-side Apple receipt validation in production

---

### `GET /pay/tip/balance/:userId`
Get tip credit balance for a user (for credit-based tipping systems).

**Response:**
```json
{
  "credits": 0
}
```

**Note:** Currently returns 0 — implement credit ledger if using a credit-based system.

---

## 💵 Ad Revenue Settlement

### `POST /pay/settlement`
Credit a creator's ledger with ad revenue (called by ads service).

**Request:**
```json
{
  "creatorId": "creator123",
  "amountCents": 2500,
  "currency": "usd",
  "campaignId": "camp_123",
  "lineItemId": "line_456",
  "settlementDate": "2024-01-15"
}
```

**Response:**
```json
{
  "ok": true,
  "balance": {
    "accountId": 42,
    "credits": 18630,
    "debits": 5000,
    "availableBalance": 13630
  }
}
```

---

## ⚙️ Settings

### `GET /pay/settings/:userId`
Get monetization settings for a creator.

**Response:**
```json
{
  "tipsEnabled": true,
  "membershipsEnabled": false,
  "payoutsEnabled": true
}
```

---

### `POST /pay/settings`
Update monetization settings (placeholder — currently no-op).

**Request:**
```json
{
  "userId": "creator123",
  "tipsEnabled": true
}
```

**Response:**
```json
{
  "ok": true
}
```

---

### `POST /pay/settings/auto-payout`
Enable/disable auto-payout for a creator.

**Request:**
```json
{
  "userId": "creator123",
  "enabled": true,
  "thresholdCents": 10000
}
```

**Response:**
```json
{
  "ok": true,
  "userId": "creator123",
  "autoPayoutEnabled": true,
  "thresholdCents": 10000
}
```

**Notes:**
- `thresholdCents` is the minimum balance required to trigger auto-payout (default: 10000 = $100)
- Auto-payouts run via `/pay/scheduled-payouts/run` cron endpoint

---

## 🤖 Scheduled Payouts (Cron)

### `POST /pay/scheduled-payouts/run`
Run auto-payouts for all eligible creators (requires auth).

**Headers:**
```
Authorization: Bearer YOUR_CRON_SECRET
```

**Response:**
```json
{
  "ok": true,
  "processed": 42,
  "failed": 3,
  "threshold": 10000
}
```

**Notes:**
- Only creators with `auto_payout_enabled = true` and balance >= threshold are processed
- Requires `CRON_SECRET` env var for authentication
- Run daily via Cloud Scheduler, GitHub Actions, or similar

---

## 🔔 Webhooks

### `POST /pay/webhooks/stripe`
Stripe webhook endpoint (handles transfer status updates).

**Headers:**
```
stripe-signature: t=1234567890,v1=abc123...
```

**Supported Events:**
- `transfer.paid` — marks payout as successful, updates `last_payout_at`
- `transfer.failed` — marks ledger entry as failed, logs failure reason
- `transfer.reversed` — credits the ledger back (reversal)
- `account.updated` — syncs Stripe Connect account status

**Response:**
```json
{
  "received": true
}
```

**Errors:**
- `400` — Webhook signature verification failed
- `500` — `STRIPE_WEBHOOK_SECRET` not configured

**Setup:**
1. Go to Stripe Dashboard → Webhooks
2. Add endpoint: `https://your-domain.com/pay/webhooks/stripe`
3. Select events: `transfer.paid`, `transfer.failed`, `transfer.reversed`, `account.updated`
4. Copy signing secret and set as `STRIPE_WEBHOOK_SECRET` env var

---

## 📊 Tax Reporting

### `GET /pay/tax/1099/:userId/:year`
Generate 1099 tax data for a US creator.

**Example:** `GET /pay/tax/1099/creator123/2024`

**Response:**
```json
{
  "userId": "creator123",
  "year": 2024,
  "totalEarnings": 15250.50,
  "requires1099": true,
  "taxInfo": {
    "businessName": "John Doe",
    "taxId": "***-**-1234",
    "address": {
      "line1": "123 Main St",
      "city": "San Francisco",
      "state": "CA",
      "postal_code": "94102",
      "country": "US"
    }
  },
  "generatedAt": "2025-01-15T10:30:00Z"
}
```

**Notes:**
- IRS requires 1099 for creators earning $600+ per year
- `totalEarnings` includes ads, tips, memberships, courses, brand deals
- `taxInfo` is fetched from Stripe Connect account (W-9/W-8BEN data)

**Errors:**
- `400` — Invalid year

---

## 💱 Currency Conversion

### `POST /pay/currency/convert`
Convert between currencies using Stripe exchange rates.

**Request:**
```json
{
  "amount": 10000,
  "fromCurrency": "usd",
  "toCurrency": "eur"
}
```

**Response:**
```json
{
  "amount": 10000,
  "fromCurrency": "USD",
  "toCurrency": "EUR",
  "convertedAmount": 9200,
  "rate": 0.92,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Notes:**
- `amount` is in cents (10000 = $100.00)
- `convertedAmount` is also in cents (9200 = €92.00)
- Rates are fetched from Stripe's live exchange rates

**Errors:**
- `400` — Invalid amount or unsupported currency
- `500` — Stripe API error

---

## 🔐 Authentication

**Current:** No authentication required (add in production!)

**Recommended:**
- Use Firebase Auth tokens for user-facing endpoints
- Use API keys or JWT for service-to-service calls
- Use `Authorization: Bearer` header for cron endpoints

**Example (Firebase Auth):**
```javascript
const token = req.headers.authorization?.replace('Bearer ', '')
const decodedToken = await admin.auth().verifyIdToken(token)
const userId = decodedToken.uid
```

---

## 📈 Rate Limits

**Current:** 100 requests per minute per IP (via `@fastify/rate-limit`)

**Recommended for production:**
- User-facing endpoints: 60 req/min per user
- Webhook endpoints: 1000 req/min (Stripe can send bursts)
- Cron endpoints: No limit (authenticated)

---

## 🐛 Error Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `400` | Bad request (missing/invalid parameters) |
| `401` | Unauthorized (invalid auth token) |
| `422` | Unprocessable entity (business logic error, e.g., insufficient balance) |
| `500` | Internal server error |
| `502` | Bad gateway (upstream service error, e.g., Stripe API down) |

---

## 🧪 Testing

### Local Development

```bash
# Start the service
cd services/pay-api
npm install
npm start

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
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to local server
stripe listen --forward-to localhost:8888/pay/webhooks/stripe

# Trigger test events
stripe trigger transfer.paid
stripe trigger transfer.failed
```

---

## 📚 Additional Resources

- [Stripe Connect Docs](https://stripe.com/docs/connect)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)
- [Apple IAP Guidelines](https://developer.apple.com/app-store/review/guidelines/#payments)
- [StoreKit 2 Docs](https://developer.apple.com/documentation/storekit)

---

**Questions?** Check the main deployment guide: `CREATOR_MONETIZATION_DEPLOYMENT.md`
