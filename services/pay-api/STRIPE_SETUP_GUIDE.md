# Stripe Setup Guide — Quick Start

## 🚀 Option 1: Automated Setup (Recommended)

Run the interactive setup script:

```bash
cd services/pay-api
./setup-stripe.sh
```

This will:
1. ✅ Prompt you for your Stripe secret key (input hidden for security)
2. ✅ Validate the key format
3. ✅ Ask for database URL and app domain
4. ✅ Generate a secure CRON_SECRET
5. ✅ Create `.env` file with all configuration
6. ✅ Add `.env` to `.gitignore` (never commit secrets!)

---

## 🔑 Option 2: Manual Setup

### Step 1: Get Your Stripe Secret Key

1. Go to [Stripe Dashboard → API Keys](https://dashboard.stripe.com/apikeys)
2. Copy your **Secret key** (starts with `sk_test_` or `sk_live_`)

**Test Mode (for development):**
- Key starts with `sk_test_`
- No real money charged
- Use test card: `4242 4242 4242 4242`

**Live Mode (for production):**
- Key starts with `sk_live_`
- Real money charged
- Requires business verification

### Step 2: Create .env File

```bash
cd services/pay-api
nano .env
```

Paste this configuration:

```bash
# Stripe Configuration
STRIPE_SECRET="sk_test_YOUR_KEY_HERE"

# Database Configuration
DATABASE_URL="postgresql://user:password@host:5432/mychannel"

# App Configuration
APP_BASE_URL="https://mychannel.live"

# Scheduled Payouts
CRON_SECRET="$(openssl rand -hex 32)"
AUTO_PAYOUT_THRESHOLD_CENTS="10000"

# Server Configuration
PORT="8888"
NODE_ENV="production"
```

**Replace:**
- `sk_test_YOUR_KEY_HERE` → Your actual Stripe key
- `postgresql://...` → Your database connection string
- `https://mychannel.live` → Your production domain

Save and exit: `Ctrl+X`, then `Y`, then `Enter`

### Step 3: Secure the .env File

```bash
# Make sure .env is in .gitignore
echo ".env" >> .gitignore

# Set restrictive permissions (only you can read)
chmod 600 .env
```

---

## 🧪 Testing Your Configuration

### 1. Verify .env File

```bash
cat .env
# Should show your configuration (Stripe key will be visible)
```

### 2. Test Stripe Key

```bash
# Install Stripe CLI (if not already installed)
brew install stripe/stripe-cli/stripe

# Test your key
stripe --api-key $(grep STRIPE_SECRET .env | cut -d'"' -f2) balance retrieve
```

**Expected output:**
```json
{
  "object": "balance",
  "available": [...],
  "pending": [...]
}
```

### 3. Start the Service

```bash
npm install
node src/migrate.js
npm start
```

**Expected output:**
```
🚀 Starting MyChannel Pay API...
✅ Starting service on port 8888...
Server listening at http://127.0.0.1:8888
```

### 4. Test Health Endpoint

```bash
curl http://localhost:8888/health
```

**Expected output:**
```json
{"status":"ok"}
```

---

## 🔔 Configure Stripe Webhooks

### Step 1: Add Webhook Endpoint

1. Go to [Stripe Dashboard → Webhooks](https://dashboard.stripe.com/webhooks)
2. Click **Add endpoint**
3. Set **Endpoint URL**: `https://your-domain.com/pay/webhooks/stripe`
4. Click **Select events** and choose:
   - ✅ `transfer.paid`
   - ✅ `transfer.failed`
   - ✅ `transfer.reversed`
   - ✅ `account.updated`
5. Click **Add endpoint**

### Step 2: Get Signing Secret

1. Click on your newly created webhook
2. Click **Reveal** next to **Signing secret**
3. Copy the secret (starts with `whsec_`)

### Step 3: Add to .env

```bash
nano .env
```

Add this line:
```bash
STRIPE_WEBHOOK_SECRET="whsec_YOUR_SECRET_HERE"
```

Save and restart the service:
```bash
npm start
```

### Step 4: Test Webhook Delivery

```bash
# Forward webhooks to local server (for testing)
stripe listen --forward-to localhost:8888/pay/webhooks/stripe

# In another terminal, trigger a test event
stripe trigger transfer.paid
```

**Expected output:**
```
✔ Webhook received: transfer.paid
✔ Response: {"received":true}
```

---

## 🔒 Security Best Practices

### ✅ DO:
- ✅ Use test mode (`sk_test_`) for development
- ✅ Use live mode (`sk_live_`) only in production
- ✅ Keep `.env` in `.gitignore`
- ✅ Set restrictive file permissions: `chmod 600 .env`
- ✅ Rotate keys if compromised
- ✅ Use environment variables in production (not `.env` files)

### ❌ DON'T:
- ❌ Commit `.env` to git
- ❌ Share your secret key
- ❌ Hardcode keys in source code
- ❌ Use live keys in development
- ❌ Log secret keys
- ❌ Send keys via email/Slack

---

## 🐛 Troubleshooting

### "Invalid Stripe key format"

**Cause:** Key doesn't start with `sk_test_` or `sk_live_`  
**Fix:** Copy the **Secret key** (not Publishable key) from Stripe Dashboard

### "Webhook signature verification failed"

**Cause:** `STRIPE_WEBHOOK_SECRET` is incorrect or missing  
**Fix:** Copy the signing secret from Stripe Dashboard → Webhooks

### "Database connection failed"

**Cause:** `DATABASE_URL` is incorrect  
**Fix:** Verify connection string format: `postgresql://user:password@host:5432/database`

### "Port 8888 already in use"

**Cause:** Another service is using port 8888  
**Fix:** Change `PORT` in `.env` to a different port (e.g., `8889`)

---

## 📚 Additional Resources

- [Stripe API Keys](https://dashboard.stripe.com/apikeys)
- [Stripe Webhooks](https://dashboard.stripe.com/webhooks)
- [Stripe Connect Docs](https://stripe.com/docs/connect)
- [Stripe CLI](https://stripe.com/docs/stripe-cli)

---

## ✅ Setup Checklist

- [ ] Stripe account created
- [ ] Secret key copied (starts with `sk_test_` or `sk_live_`)
- [ ] `.env` file created with all required variables
- [ ] `.env` added to `.gitignore`
- [ ] Database migration completed (`node src/migrate.js`)
- [ ] Service starts successfully (`npm start`)
- [ ] Health check passes (`curl http://localhost:8888/health`)
- [ ] Webhook endpoint added in Stripe Dashboard
- [ ] Webhook signing secret added to `.env`
- [ ] Webhook delivery tested (`stripe trigger transfer.paid`)

---

**Need help?** Check the [API Reference](./API_REFERENCE.md) or [Deployment Guide](../../CREATOR_MONETIZATION_DEPLOYMENT.md)
