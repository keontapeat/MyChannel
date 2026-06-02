# 🚀 Creator Monetization — Deployment Checklist

Use this checklist to deploy MyChannel's creator monetization system to production.

---

## ✅ Pre-Deployment

### Backend Preparation
- [ ] PostgreSQL database provisioned and accessible
- [ ] Database connection string obtained (`DATABASE_URL`)
- [ ] Stripe account created (or existing account ready)
- [ ] Stripe live secret key obtained (`STRIPE_SECRET`)
- [ ] Production domain configured (`APP_BASE_URL`)
- [ ] Secure random string generated for cron auth (`CRON_SECRET`)

### iOS Preparation
- [ ] Apple Developer account active
- [ ] App Store Connect access confirmed
- [ ] IAP products planned (6 tip tiers)
- [ ] StoreKit testing account created

### Documentation Review
- [ ] Read `CREATOR_MONETIZATION_DEPLOYMENT.md` (full guide)
- [ ] Review `API_REFERENCE.md` (endpoint documentation)
- [ ] Understand `MONETIZATION_COMPLETE.md` (executive summary)

---

## 🔧 Backend Deployment

### 1. Environment Setup
```bash
export DATABASE_URL="postgresql://user:pass@host:5432/mychannel"
export STRIPE_SECRET="sk_live_..."
export APP_BASE_URL="https://mychannel.live"
export STRIPE_WEBHOOK_SECRET="whsec_..."  # Get after webhook setup
export CRON_SECRET="$(openssl rand -hex 32)"
export AUTO_PAYOUT_THRESHOLD_CENTS="10000"  # $100 default
export PORT="8888"
```

**Checklist:**
- [ ] All environment variables set
- [ ] `DATABASE_URL` tested (can connect)
- [ ] `STRIPE_SECRET` starts with `sk_live_` (production) or `sk_test_` (testing)
- [ ] `APP_BASE_URL` is your production domain (no trailing slash)
- [ ] `CRON_SECRET` is secure (32+ characters)

### 2. Database Migration
```bash
cd services/pay-api
npm install
node src/migrate.js
```

**Checklist:**
- [ ] Dependencies installed (`node_modules/` exists)
- [ ] Migration completed successfully
- [ ] Tables created: `pay_accounts`, `ledger_accounts`, `ledger_entries`, `entitlements`, `subscriptions`
- [ ] Indexes created on `ledger_entries`

**Verify:**
```sql
\dt  -- List tables
SELECT COUNT(*) FROM pay_accounts;  -- Should return 0 (empty)
```

### 3. Start Service
```bash
npm start
# Or use the convenience script:
./start.sh
```

**Checklist:**
- [ ] Service starts without errors
- [ ] Logs show "Server listening at http://..."
- [ ] No database connection errors

### 4. Health Check
```bash
curl http://localhost:8888/health
# Expected: {"status":"ok"}
```

**Checklist:**
- [ ] Health endpoint returns `{"status":"ok"}`
- [ ] Response time < 100ms

### 5. Deploy to Production
Deploy using your platform (Cloud Run, Heroku, AWS, etc.):

**Google Cloud Run:**
```bash
gcloud run deploy pay-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DATABASE_URL="...",STRIPE_SECRET="...",APP_BASE_URL="..."
```

**Heroku:**
```bash
heroku create mychannel-pay-api
heroku addons:create heroku-postgresql:standard-0
heroku config:set STRIPE_SECRET="..." APP_BASE_URL="..."
git push heroku main
```

**Checklist:**
- [ ] Service deployed to production
- [ ] Production URL accessible (e.g., `https://pay-api.mychannel.live`)
- [ ] Health check passes: `curl https://pay-api.mychannel.live/health`

---

## 💳 Stripe Configuration

### 1. Enable Stripe Connect
1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Navigate to **Settings → Connect**
3. Click **Get started** (if not already enabled)
4. Select **Express** as the account type
5. Set platform name: **"MyChannel"**
6. Save settings

**Checklist:**
- [ ] Stripe Connect enabled
- [ ] Express accounts selected
- [ ] Platform name set to "MyChannel"

### 2. Configure Webhooks
1. Go to **Developers → Webhooks**
2. Click **Add endpoint**
3. Set **Endpoint URL**: `https://your-domain.com/pay/webhooks/stripe`
4. Click **Select events** and choose:
   - `transfer.paid`
   - `transfer.failed`
   - `transfer.reversed`
   - `account.updated`
5. Click **Add endpoint**
6. Copy the **Signing secret** (starts with `whsec_`)
7. Set as environment variable: `export STRIPE_WEBHOOK_SECRET="whsec_..."`
8. Restart the service

**Checklist:**
- [ ] Webhook endpoint added
- [ ] All 4 events selected
- [ ] Signing secret copied
- [ ] `STRIPE_WEBHOOK_SECRET` env var set
- [ ] Service restarted

### 3. Test Webhook Delivery
```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to production
stripe listen --forward-to https://your-domain.com/pay/webhooks/stripe

# Trigger test event
stripe trigger transfer.paid
```

**Checklist:**
- [ ] Stripe CLI installed
- [ ] Webhook forwarding works
- [ ] Test event received (check logs)
- [ ] Response: `{"received":true}`

---

## 📱 iOS App Configuration

### 1. Configure IAP Products in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Navigate to **Features → In-App Purchases**
4. Click **+** to create new products

**Create 6 consumable products:**

| Product ID | Reference Name | Price | Description |
|------------|----------------|-------|-------------|
| `com.mychannel.tip.1` | Tip 1 Credit | $0.99 | Send a tip to your favorite creator |
| `com.mychannel.tip.5` | Tip 5 Credits | $4.99 | Send a tip to your favorite creator |
| `com.mychannel.tip.10` | Tip 10 Credits | $9.99 | Send a tip to your favorite creator |
| `com.mychannel.tip.20` | Tip 20 Credits | $19.99 | Send a tip to your favorite creator |
| `com.mychannel.tip.50` | Tip 50 Credits | $49.99 | Send a tip to your favorite creator |
| `com.mychannel.tip.100` | Tip 100 Credits | $99.99 | Send a tip to your favorite creator |

**For each product:**
- Type: **Consumable**
- Display Name: **Tip Credits**
- Description: **Send a tip to your favorite creator**
- Screenshot: Upload a screenshot of the tipping UI
- Review Notes: "This is a tipping system where viewers purchase credits to send to creators. Compliant with Guideline 3.1.1."

**Checklist:**
- [ ] All 6 products created
- [ ] Product IDs match exactly (case-sensitive)
- [ ] Prices set correctly
- [ ] Screenshots uploaded
- [ ] Products submitted for review
- [ ] Products approved (wait 24-48 hours)

### 2. Add StoreKit Configuration File (for testing)

1. In Xcode: **File → New → File**
2. Search for **StoreKit Configuration File**
3. Name it `TipProducts.storekit`
4. Add the 6 products with their prices
5. Edit scheme: **Product → Scheme → Edit Scheme**
6. Select **Run** → **Options** tab
7. Set **StoreKit Configuration** to `TipProducts.storekit`

**Checklist:**
- [ ] StoreKit configuration file created
- [ ] All 6 products added
- [ ] Scheme configured to use StoreKit file
- [ ] Local testing works (can "purchase" tips)

### 3. Build & Deploy iOS App

```bash
cd MyChannel

# Clean build
xcodebuild clean -project MyChannel.xcodeproj -scheme MyChannel

# Build for release
xcodebuild -project MyChannel.xcodeproj \
  -scheme MyChannel \
  -configuration Release \
  -destination 'generic/platform=iOS'

# Or use Xcode GUI:
# Product → Archive → Distribute App → App Store Connect
```

**Checklist:**
- [ ] Build succeeds without errors
- [ ] No SwiftLint warnings
- [ ] Archive created
- [ ] App uploaded to App Store Connect
- [ ] App submitted for review (if first release)

---

## 🤖 Scheduled Auto-Payouts (Optional)

### Using Google Cloud Scheduler

```bash
gcloud scheduler jobs create http auto-payouts \
  --schedule="0 2 * * *" \
  --uri="https://your-domain.com/pay/scheduled-payouts/run" \
  --http-method=POST \
  --headers="Authorization=Bearer YOUR_CRON_SECRET" \
  --time-zone="America/Los_Angeles"
```

**Checklist:**
- [ ] Cloud Scheduler job created
- [ ] Schedule set to daily at 2 AM
- [ ] Authorization header includes `CRON_SECRET`
- [ ] Test run succeeds: `gcloud scheduler jobs run auto-payouts`

### Using GitHub Actions

Create `.github/workflows/auto-payouts.yml`:

```yaml
name: Auto Payouts
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:  # Allow manual trigger
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger auto-payouts
        run: |
          curl -X POST https://your-domain.com/pay/scheduled-payouts/run \
            -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}" \
            -f  # Fail on HTTP error
```

**Checklist:**
- [ ] Workflow file created
- [ ] `CRON_SECRET` added to GitHub Secrets
- [ ] Manual trigger works (Actions tab → Run workflow)
- [ ] Scheduled run succeeds (check next day)

---

## 🧪 End-to-End Testing

### Backend Tests

```bash
# Health check
curl https://your-domain.com/health

# Connect link generation
curl -X POST https://your-domain.com/pay/connect/link \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-user-123"}'

# Check status
curl https://your-domain.com/pay/connect/status/test-user-123

# Currency conversion
curl -X POST https://your-domain.com/pay/currency/convert \
  -H "Content-Type: application/json" \
  -d '{"amount":10000,"fromCurrency":"usd","toCurrency":"eur"}'
```

**Checklist:**
- [ ] Health check returns `{"status":"ok"}`
- [ ] Connect link returns Stripe URL
- [ ] Status check returns account data
- [ ] Currency conversion works

### iOS Tests

**Test 1: Stripe Connect Onboarding**
1. Open app → Creator Studio → Payout Settings
2. Tap "Connect Bank Account"
3. Complete Stripe Express onboarding (use test mode)
4. Return to app
5. Verify status shows "Payouts enabled"

**Checklist:**
- [ ] Onboarding flow opens
- [ ] Stripe form loads correctly
- [ ] Can complete onboarding
- [ ] Status updates after completion

**Test 2: Withdrawal**
1. Seed creator balance: `POST /pay/settlement` with test data
2. Open Earnings tab
3. Tap "Withdraw"
4. Enter amount (e.g., $10)
5. Confirm withdrawal
6. Check Stripe Dashboard → Transfers

**Checklist:**
- [ ] Withdrawal sheet opens
- [ ] Balance displays correctly
- [ ] Can enter amount
- [ ] Withdrawal succeeds
- [ ] Stripe transfer created
- [ ] Balance updates

**Test 3: Tipping**
1. Open any video
2. Tap tip button (heart icon)
3. Select tip amount (e.g., $9.99 for 10 credits)
4. Complete IAP purchase (use sandbox tester account)
5. Verify creator receives tip notification

**Checklist:**
- [ ] Tip sheet opens
- [ ] Products load correctly
- [ ] Can select amount
- [ ] IAP purchase flow works
- [ ] Purchase completes
- [ ] Creator receives tip
- [ ] Balance updates

---

## 📊 Monitoring Setup

### 1. Database Monitoring

Add these queries to your monitoring dashboard:

```sql
-- Total payouts (last 24 hours)
SELECT COUNT(*), SUM(amount) / 100.0 AS total
FROM ledger_entries
WHERE reference_type = 'payout'
  AND created_at >= NOW() - INTERVAL '24 hours';

-- Failed payouts
SELECT COUNT(*)
FROM ledger_entries
WHERE reference_type = 'payout'
  AND metadata->>'status' = 'failed'
  AND created_at >= NOW() - INTERVAL '24 hours';

-- Top earners (last 7 days)
SELECT la.user_id, SUM(le.amount) / 100.0 AS earnings
FROM ledger_entries le
JOIN ledger_accounts la ON la.id = le.account_id
WHERE le.direction = 'credit'
  AND le.created_at >= NOW() - INTERVAL '7 days'
GROUP BY la.user_id
ORDER BY earnings DESC
LIMIT 10;
```

**Checklist:**
- [ ] Monitoring dashboard created (Grafana, Datadog, etc.)
- [ ] Key metrics tracked (payouts, earnings, tips)
- [ ] Alerts configured for failures

### 2. Error Tracking

Set up error tracking (Sentry, Rollbar, etc.):

```javascript
// Add to src/index.js
import * as Sentry from '@sentry/node'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'production'
})

app.setErrorHandler((error, request, reply) => {
  Sentry.captureException(error)
  reply.code(500).send({ error: 'Internal server error' })
})
```

**Checklist:**
- [ ] Error tracking service configured
- [ ] Errors captured and reported
- [ ] Alerts set up for critical errors

### 3. Uptime Monitoring

Set up uptime monitoring (Pingdom, UptimeRobot, etc.):

- Monitor: `https://your-domain.com/health`
- Interval: 1 minute
- Alert: Email/SMS on failure

**Checklist:**
- [ ] Uptime monitor configured
- [ ] Health check endpoint monitored
- [ ] Alerts configured

---

## 🔒 Security Review

### Pre-Launch Security Checklist

- [ ] All secrets stored in environment variables (not in code)
- [ ] `STRIPE_WEBHOOK_SECRET` configured (webhook verification enabled)
- [ ] `CRON_SECRET` is secure (32+ characters)
- [ ] Database uses SSL/TLS connection
- [ ] API endpoints use HTTPS (not HTTP)
- [ ] Rate limiting enabled (100 req/min default)
- [ ] No sensitive data logged (PII, secrets, card numbers)
- [ ] Error messages don't expose internal details
- [ ] Stripe Connect uses Express accounts (not Custom)
- [ ] IAP receipt validation planned (add in Phase 2)

---

## 📋 Final Pre-Launch Checklist

### Backend
- [ ] Service deployed to production
- [ ] Health check passes
- [ ] Database migration completed
- [ ] All environment variables set
- [ ] Stripe Connect enabled
- [ ] Webhooks configured and tested
- [ ] Auto-payouts scheduled (optional)
- [ ] Monitoring dashboards created
- [ ] Error tracking configured
- [ ] Uptime monitoring active

### iOS
- [ ] IAP products created and approved
- [ ] StoreKit configuration file added
- [ ] App built and deployed
- [ ] Feature flags enabled (`enableCreatorMonetization`, `enableTipping`)
- [ ] End-to-end tests passed

### Documentation
- [ ] Privacy policy updated (payment data disclosure)
- [ ] Terms of service updated (revenue share, fees)
- [ ] Creator help docs published
- [ ] Support team trained

### Compliance
- [ ] Apple Guideline 3.1.1 reviewed (IAP for digital goods)
- [ ] Stripe Connect terms accepted
- [ ] Tax reporting plan confirmed (1099 generation)
- [ ] PCI compliance verified (Stripe handles sensitive data)

---

## 🚀 Launch Day

### 1. Final Verification (1 hour before launch)

```bash
# Backend health
curl https://your-domain.com/health

# Stripe webhook delivery
stripe trigger transfer.paid

# Database connection
psql $DATABASE_URL -c "SELECT COUNT(*) FROM pay_accounts;"

# iOS app version
# Verify latest build is live in App Store Connect
```

**Checklist:**
- [ ] All systems operational
- [ ] No errors in logs
- [ ] Monitoring dashboards green

### 2. Enable Feature Flags

If using remote config (Firebase, LaunchDarkly, etc.):
- [ ] Enable `enableCreatorMonetization` globally
- [ ] Enable `enableTipping` globally

If using hardcoded flags (already done):
- [ ] Flags already enabled in `AppConfig.swift`

### 3. Announce Launch

- [ ] Send email to creators (see `MONETIZATION_COMPLETE.md` for draft)
- [ ] Post on social media
- [ ] Update website/blog
- [ ] Notify support team

### 4. Monitor Closely (first 24 hours)

- [ ] Watch error logs every hour
- [ ] Check Stripe Dashboard for transfers
- [ ] Monitor database for unusual activity
- [ ] Track key metrics (payouts, tips, errors)
- [ ] Respond to creator feedback

---

## 📞 Support Contacts

### For Issues During Deployment

- **Backend errors:** Check service logs, verify env vars
- **Stripe issues:** [Stripe Support](https://support.stripe.com)
- **Database issues:** Check connection string, verify migration
- **iOS build issues:** Check Xcode logs, verify certificates

### Post-Launch Support

- **Creator questions:** Direct to help docs
- **Payout issues:** Check Stripe Dashboard → Transfers
- **IAP issues:** Check App Store Connect → Sales and Trends

---

## ✅ Deployment Complete!

Once all items are checked:

1. Mark deployment as complete
2. Monitor for 24 hours
3. Gather creator feedback
4. Iterate on UI/UX
5. Plan Phase 2 enhancements

**Congratulations! You've launched the most creator-friendly monetization system in the industry. 🎉**

---

**Questions?** Review the documentation:
- [Deployment Guide](./CREATOR_MONETIZATION_DEPLOYMENT.md)
- [API Reference](./services/pay-api/API_REFERENCE.md)
- [Executive Summary](./MONETIZATION_COMPLETE.md)
