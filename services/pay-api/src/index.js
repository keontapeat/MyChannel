import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import Stripe from 'stripe'
import pkg from 'pg'
const { Pool } = pkg

const stripe = new Stripe(process.env.STRIPE_SECRET || 'sk_test_123')
const app = Fastify({ logger: true })

// Raw body for Stripe webhook signature verification
app.addContentTypeParser('application/json', { parseAs: 'buffer' }, (req, body, done) => {
  try {
    req.rawBody = body
    const json = JSON.parse(body.toString())
    done(null, json)
  } catch (err) {
    done(err)
  }
})

await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 100, timeWindow: '1 minute' })

const pool = new Pool({ connectionString: process.env.DATABASE_URL })

// ─── App base URL (used for Stripe redirect URLs) ────────────────────────────
const APP_BASE_URL = process.env.APP_BASE_URL || 'https://mychannel.live'
const PAYOUT_RETURN_URL  = `${APP_BASE_URL}/creator/payout/return`
const PAYOUT_REFRESH_URL = `${APP_BASE_URL}/creator/payout/refresh`

// ─── Minimum payout threshold (cents) ────────────────────────────────────────
const MIN_PAYOUT_CENTS = 100 // $1.00 — no minimum like YouTube's $100

async function ensureLedgerAccount(userId, type = 'creator') {
  const { rows: acct } = await pool.query('insert into ledger_accounts(user_id, type) values($1,$2) on conflict do nothing returning id', [userId, type])
  if (acct[0]?.id) return acct[0].id
  const existing = await pool.query('select id from ledger_accounts where user_id=$1 limit 1', [userId])
  return existing.rows[0]?.id
}

async function getCreatorBalanceSummary(userId) {
  const accountId = await ensureLedgerAccount(userId, 'creator')
  const { rows } = await pool.query(
    `select
      coalesce(sum(case when direction='credit' then amount else 0 end), 0)::bigint as credits,
      coalesce(sum(case when direction='debit' then amount else 0 end), 0)::bigint as debits
     from ledger_entries
     where account_id=$1`,
    [accountId]
  )
  const credits = Number(rows[0]?.credits || 0)
  const debits = Number(rows[0]?.debits || 0)
  return {
    accountId,
    credits,
    debits,
    availableBalance: credits - debits
  }
}

// ─── Get or create a Stripe Express account for a creator ────────────────────
// Idempotent: reuses the existing account if one was already created.
async function getOrCreateStripeAccount(userId) {
  const { rows } = await pool.query(
    'select stripe_account_id, status from pay_accounts where user_id=$1 limit 1',
    [userId]
  )
  if (rows[0]?.stripe_account_id) {
    return { accountId: rows[0].stripe_account_id, isNew: false, status: rows[0].status }
  }
  const acct = await stripe.accounts.create({
    type: 'express',
    metadata: { mychannel_user_id: userId }
  })
  await pool.query(
    'insert into pay_accounts(user_id, stripe_account_id, status) values($1,$2,$3) on conflict(user_id) do update set stripe_account_id=$2',
    [userId, acct.id, 'pending']
  )
  return { accountId: acct.id, isNew: true, status: 'pending' }
}

app.get('/health', async () => ({ status: 'ok' }))

app.post('/migrate', async () => {
  const { default: mod } = await import('./migrate.js')
  return { ok: true }
})

// ─── Stripe Connect onboarding link ──────────────────────────────────────────
app.post('/pay/connect/link', async (req, reply) => {
  const { userId } = req.body || {}
  if (!userId) { reply.code(400); return { error: 'userId required' } }

  try {
    const { accountId } = await getOrCreateStripeAccount(userId)
    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: PAYOUT_REFRESH_URL,
      return_url:  PAYOUT_RETURN_URL,
      type: 'account_onboarding'
    })
    return { url: link.url }
  } catch (err) {
    app.log.error(err)
    reply.code(500)
    return { error: 'Failed to create Connect link' }
  }
})

// ─── Creator payout (withdrawal) ─────────────────────────────────────────────
// Validates balance, checks Stripe account is fully onboarded, then executes
// a Stripe Transfer to the creator's connected account.
// Uses integer cents throughout — no floating-point dollar math.
app.post('/pay/withdraw', async (req, reply) => {
  const { creatorId, amount } = req.body || {}
  if (!creatorId || !amount) { reply.code(400); return { error: 'creatorId and amount required' } }

  // amount arrives as dollars (Double) from the iOS client — convert to cents
  const amountCents = Math.round(Number(amount) * 100)
  if (!Number.isFinite(amountCents) || amountCents < MIN_PAYOUT_CENTS) {
    reply.code(400)
    return { error: `Minimum payout is $${(MIN_PAYOUT_CENTS / 100).toFixed(2)}` }
  }

  // 1. Check ledger balance
  const balance = await getCreatorBalanceSummary(creatorId)
  if (balance.availableBalance < amountCents) {
    reply.code(422)
    return { error: 'Insufficient balance', availableBalance: balance.availableBalance }
  }

  // 2. Verify Stripe account is onboarded
  const { rows: acctRows } = await pool.query(
    'select stripe_account_id, status from pay_accounts where user_id=$1 limit 1',
    [creatorId]
  )
  if (!acctRows[0]?.stripe_account_id) {
    reply.code(422)
    return { error: 'Stripe account not connected. Complete payout setup first.' }
  }
  const stripeAccountId = acctRows[0].stripe_account_id

  // Verify the account is charges_enabled (fully onboarded)
  let stripeAccount
  try {
    stripeAccount = await stripe.accounts.retrieve(stripeAccountId)
  } catch (err) {
    reply.code(502)
    return { error: 'Could not verify Stripe account status' }
  }
  if (!stripeAccount.payouts_enabled) {
    reply.code(422)
    return {
      error: 'Payout account setup is incomplete. Please finish connecting your bank account.',
      onboardingRequired: true
    }
  }

  // 3. Execute Stripe Transfer (platform → creator's connected account)
  // Platform fee is already deducted at earnings-credit time (90/10 split),
  // so we transfer the full requested amount.
  let transfer
  try {
    transfer = await stripe.transfers.create({
      amount: amountCents,
      currency: 'usd',
      destination: stripeAccountId,
      metadata: { mychannel_user_id: creatorId }
    })
  } catch (err) {
    app.log.error(err)
    reply.code(502)
    return { error: `Stripe transfer failed: ${err.message}` }
  }

  // 4. Debit the ledger atomically
  const payoutId = `payout_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  await pool.query(
    `insert into ledger_entries(account_id, amount, currency, direction, reference_type, reference_id, metadata)
     values($1,$2,'usd','debit','payout',$3,$4)`,
    [
      balance.accountId,
      amountCents,
      payoutId,
      JSON.stringify({ stripeTransferId: transfer.id, stripeAccountId })
    ]
  )

  // 5. Update pay_accounts.status so the dashboard reflects the latest payout
  await pool.query(
    'update pay_accounts set status=$1 where user_id=$2',
    ['active', creatorId]
  )

  const updatedBalance = await getCreatorBalanceSummary(creatorId)
  return {
    ok: true,
    payoutId,
    amountCents,
    stripeTransferId: transfer.id,
    balance: updatedBalance
  }
})

// ─── Payout history ───────────────────────────────────────────────────────────
app.get('/pay/creator/:userId/payouts', async (req, reply) => {
  const { userId } = req.params
  const balance = await getCreatorBalanceSummary(userId)
  const { rows } = await pool.query(
    `select id, amount, currency, direction, reference_type, reference_id, metadata, created_at
     from ledger_entries
     where account_id=$1 and reference_type='payout'
     order by created_at desc limit 50`,
    [balance.accountId]
  )
  return { userId, payouts: rows }
})

// ─── Stripe Connect account status ───────────────────────────────────────────
app.get('/pay/connect/status/:userId', async (req, reply) => {
  const { userId } = req.params
  const { rows } = await pool.query(
    'select stripe_account_id, status from pay_accounts where user_id=$1 limit 1',
    [userId]
  )
  if (!rows[0]) return { connected: false, payoutsEnabled: false }

  try {
    const acct = await stripe.accounts.retrieve(rows[0].stripe_account_id)
    // Sync status back to DB
    const newStatus = acct.payouts_enabled ? 'active' : 'pending'
    await pool.query('update pay_accounts set status=$1 where user_id=$2', [newStatus, userId])
    return {
      connected: true,
      payoutsEnabled: acct.payouts_enabled,
      chargesEnabled: acct.charges_enabled,
      status: newStatus,
      detailsSubmitted: acct.details_submitted
    }
  } catch (err) {
    return { connected: true, payoutsEnabled: false, status: rows[0].status }
  }
})

// ─── Pay settings (monetization toggles) ─────────────────────────────────────
app.get('/pay/settings/:userId', async (req) => {
  const { userId } = req.params
  const { rows } = await pool.query(
    'select stripe_account_id, status from pay_accounts where user_id=$1 limit 1',
    [userId]
  )
  return {
    tipsEnabled: false,          // gated by Apple 3.1.1 — viewer→creator IAP required
    membershipsEnabled: false,   // same
    payoutsEnabled: rows[0]?.status === 'active'
  }
})

app.post('/pay/settings', async (req) => {
  // Placeholder — settings are managed via Stripe Connect onboarding
  return { ok: true }
})

// ─── Tip intent (Stripe PaymentIntent for viewer tips) ───────────────────────
app.post('/pay/tip/intent', async (req, reply) => {
  const { toUserId, amount, currency = 'usd' } = req.body || {}
  
  if (!process.env.STRIPE_SECRET || process.env.STRIPE_SECRET === 'sk_test_123') {
    return {
      clientSecret: `pi_mock_${Date.now()}_secret_mock`,
      paymentIntentId: `pi_mock_${Date.now()}`,
      mode: 'mock',
      currency,
      amount
    }
  }
  
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
      metadata: { type: 'tip', toUserId }
    })
    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      mode: 'stripe',
      currency,
      amount
    }
  } catch (error) {
    reply.code(500)
    return { error: error.message }
  }
})

// ─── Tip confirmation ─────────────────────────────────────────────────────────
app.post('/pay/tip', async (req, reply) => {
  const { toUserId, amount, currency = 'usd', message, paymentIntentId } = req.body || {}
  
  if (!process.env.STRIPE_SECRET || process.env.STRIPE_SECRET === 'sk_test_123') {
    const accountId = await ensureLedgerAccount(toUserId, 'creator')
    await pool.query(
      'insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)',
      [accountId, amount, currency, 'credit', 'tip', JSON.stringify({ message: message || null, paymentIntentId: paymentIntentId || null })]
    )
    const balance = await getCreatorBalanceSummary(toUserId)
    return { ok: true, tipId: `tip_${Date.now()}`, transactionId: paymentIntentId || 'mock', balance }
  }
  
  try {
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId)
    if (paymentIntent.status !== 'succeeded') {
      reply.code(400)
      return { error: 'Payment not completed' }
    }
    const accountId = await ensureLedgerAccount(toUserId, 'creator')
    const tipId = `tip_${Date.now()}`
    await pool.query(
      'insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)',
      [accountId, amount, currency, 'credit', 'tip', JSON.stringify({ message: message || null, paymentIntentId, stripeChargeId: paymentIntent.latest_charge || null })]
    )
    const balance = await getCreatorBalanceSummary(toUserId)
    return { ok: true, tipId, transactionId: paymentIntentId, balance }
  } catch (error) {
    reply.code(500)
    return { error: error.message }
  }
})

// ─── IAP Tip (Apple In-App Purchase compliant) ───────────────────────────────
// Viewer purchases tip credits via IAP, then sends them to creator.
// Apple takes 30%, MyChannel takes 10% of remaining = 7% total.
// Creator gets 63% of the original purchase price.
app.post('/pay/tip/iap', async (req, reply) => {
  const { fromUserId, toUserId, amount, currency = 'usd', message, transactionId, productId, credits } = req.body || {}
  
  if (!fromUserId || !toUserId || !amount || !transactionId) {
    reply.code(400)
    return { error: 'Missing required fields' }
  }

  // Verify the Apple transaction (in production, validate with Apple's servers)
  // For now, trust the client — add server-side receipt validation in production
  
  const accountId = await ensureLedgerAccount(toUserId, 'creator')
  const tipId = `iap_tip_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  
  await pool.query(
    `insert into ledger_entries(account_id, amount, currency, direction, reference_type, reference_id, metadata)
     values($1,$2,$3,$4,$5,$6,$7)`,
    [
      accountId,
      amount,
      currency,
      'credit',
      'tip',
      tipId,
      JSON.stringify({
        message: message || null,
        transactionId,
        productId,
        credits,
        fromUserId,
        iapPlatform: 'apple'
      })
    ]
  )

  const balance = await getCreatorBalanceSummary(toUserId)
  
  // Send push notification to creator
  // TODO: integrate with Firebase Cloud Messaging or APNs
  
  return { ok: true, tipId, balance }
})

// ─── Tip credit balance (for IAP system) ──────────────────────────────────────
app.get('/pay/tip/balance/:userId', async (req) => {
  const { userId } = req.params
  // In a credit-based system, track purchased credits separately
  // For now, return 0 — implement credit ledger if needed
  return { credits: 0 }
})

// ─── Ad settlement (from ads service) ────────────────────────────────────────
app.post('/pay/settlement', async (req) => {
  const { creatorId, amountCents = 0, currency = 'usd', campaignId = null, lineItemId = null, settlementDate = null } = req.body || {}
  const accountId = await ensureLedgerAccount(creatorId, 'creator')
  await pool.query(
    'insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)',
    [accountId, amountCents, currency, 'credit', 'ads', JSON.stringify({ campaignId, lineItemId, settlementDate })]
  )
  const balance = await getCreatorBalanceSummary(creatorId)
  return { ok: true, balance }
})

// ─── Creator balance summary ──────────────────────────────────────────────────
app.get('/pay/creator/:userId/summary', async (req) => {
  const { userId } = req.params
  const balance = await getCreatorBalanceSummary(userId)
  const { rows: recentEntries } = await pool.query(
    'select amount, currency, direction, reference_type, metadata, created_at from ledger_entries where account_id=$1 order by created_at desc limit 20',
    [balance.accountId]
  )
  return { userId, balance, recentEntries }
})

// ─── Stripe Webhooks (transfer status tracking) ──────────────────────────────
app.post('/pay/webhooks/stripe', async (req, reply) => {
  const sig = req.headers['stripe-signature']
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET
  
  if (!webhookSecret) {
    app.log.warn('STRIPE_WEBHOOK_SECRET not set — webhook verification disabled')
    reply.code(500)
    return { error: 'Webhook secret not configured' }
  }

  let event
  try {
    event = stripe.webhooks.constructEvent(req.rawBody || req.body, sig, webhookSecret)
  } catch (err) {
    app.log.error(`Webhook signature verification failed: ${err.message}`)
    reply.code(400)
    return { error: `Webhook Error: ${err.message}` }
  }

  // Handle transfer events
  if (event.type === 'transfer.paid') {
    const transfer = event.data.object
    const userId = transfer.metadata?.mychannel_user_id
    if (userId) {
      await pool.query(
        `update pay_accounts set status=$1, last_payout_at=$2 where user_id=$3`,
        ['active', new Date(), userId]
      )
      app.log.info(`✅ Transfer paid: ${transfer.id} → user ${userId}`)
    }
  } else if (event.type === 'transfer.failed') {
    const transfer = event.data.object
    const userId = transfer.metadata?.mychannel_user_id
    if (userId) {
      // Mark the ledger entry as failed
      await pool.query(
        `update ledger_entries set metadata = metadata || '{"status":"failed","failureReason":"${transfer.failure_message || 'Unknown'}"}'::jsonb
         where metadata->>'stripeTransferId' = $1`,
        [transfer.id]
      )
      app.log.error(`❌ Transfer failed: ${transfer.id} → user ${userId}: ${transfer.failure_message}`)
    }
  } else if (event.type === 'transfer.reversed') {
    const transfer = event.data.object
    const userId = transfer.metadata?.mychannel_user_id
    if (userId) {
      // Credit the ledger back (reversal)
      const accountId = await ensureLedgerAccount(userId, 'creator')
      await pool.query(
        `insert into ledger_entries(account_id, amount, currency, direction, reference_type, reference_id, metadata)
         values($1,$2,'usd','credit','payout_reversal',$3,$4)`,
        [accountId, transfer.amount, transfer.id, JSON.stringify({ originalTransferId: transfer.id, reason: 'reversed' })]
      )
      app.log.warn(`⚠️ Transfer reversed: ${transfer.id} → user ${userId}`)
    }
  } else if (event.type === 'account.updated') {
    // Sync Stripe Connect account status
    const account = event.data.object
    const userId = account.metadata?.mychannel_user_id
    if (userId) {
      const newStatus = account.payouts_enabled ? 'active' : 'pending'
      await pool.query('update pay_accounts set status=$1 where user_id=$2', [newStatus, userId])
      app.log.info(`🔄 Account updated: ${account.id} → user ${userId} → status ${newStatus}`)
    }
  }

  return { received: true }
})

// ─── Scheduled Payouts (auto-withdraw when balance hits threshold) ────────────
app.post('/pay/scheduled-payouts/run', async (req, reply) => {
  const authHeader = req.headers.authorization
  const cronSecret = process.env.CRON_SECRET || 'dev-secret-123'
  
  if (authHeader !== `Bearer ${cronSecret}`) {
    reply.code(401)
    return { error: 'Unauthorized' }
  }

  const threshold = Number(process.env.AUTO_PAYOUT_THRESHOLD_CENTS) || 10000 // $100 default
  app.log.info(`🤖 Running scheduled payouts (threshold: $${(threshold / 100).toFixed(2)})`)

  // Find all creators with balance >= threshold and auto_payout enabled
  const { rows: eligibleCreators } = await pool.query(
    `select pa.user_id, pa.stripe_account_id, la.id as account_id
     from pay_accounts pa
     join ledger_accounts la on la.user_id = pa.user_id and la.type = 'creator'
     where pa.status = 'active' and pa.auto_payout_enabled = true`
  )

  let processed = 0
  let failed = 0

  for (const creator of eligibleCreators) {
    const balance = await getCreatorBalanceSummary(creator.user_id)
    if (balance.availableBalance >= threshold) {
      try {
        // Execute auto-payout
        const transfer = await stripe.transfers.create({
          amount: balance.availableBalance,
          currency: 'usd',
          destination: creator.stripe_account_id,
          metadata: { mychannel_user_id: creator.user_id, auto_payout: 'true' }
        })
        const payoutId = `auto_payout_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
        await pool.query(
          `insert into ledger_entries(account_id, amount, currency, direction, reference_type, reference_id, metadata)
           values($1,$2,'usd','debit','payout',$3,$4)`,
          [balance.accountId, balance.availableBalance, payoutId, JSON.stringify({ stripeTransferId: transfer.id, auto: true })]
        )
        processed++
        app.log.info(`✅ Auto-payout: user ${creator.user_id} → $${(balance.availableBalance / 100).toFixed(2)}`)
      } catch (err) {
        failed++
        app.log.error(`❌ Auto-payout failed for user ${creator.user_id}: ${err.message}`)
      }
    }
  }

  return { ok: true, processed, failed, threshold }
})

// ─── Tax Reporting (1099 generation for US creators) ──────────────────────────
app.get('/pay/tax/1099/:userId/:year', async (req, reply) => {
  const { userId, year } = req.params
  const yearInt = parseInt(year, 10)
  if (!yearInt || yearInt < 2020 || yearInt > new Date().getFullYear()) {
    reply.code(400)
    return { error: 'Invalid year' }
  }

  const startDate = new Date(`${yearInt}-01-01`)
  const endDate = new Date(`${yearInt}-12-31T23:59:59`)

  const balance = await getCreatorBalanceSummary(userId)
  const { rows } = await pool.query(
    `select sum(amount) as total_earnings
     from ledger_entries
     where account_id=$1 and direction='credit' and reference_type in ('ads','tip','membership','course','brandDeal')
       and created_at >= $2 and created_at <= $3`,
    [balance.accountId, startDate, endDate]
  )

  const totalEarningsCents = Number(rows[0]?.total_earnings || 0)
  const totalEarnings = totalEarningsCents / 100

  // IRS requires 1099 for $600+ in earnings
  const requires1099 = totalEarnings >= 600

  // Fetch creator details
  const { rows: accountRows } = await pool.query(
    'select stripe_account_id from pay_accounts where user_id=$1 limit 1',
    [userId]
  )

  let taxInfo = null
  if (accountRows[0]?.stripe_account_id) {
    try {
      const account = await stripe.accounts.retrieve(accountRows[0].stripe_account_id)
      taxInfo = {
        businessName: account.business_profile?.name || account.individual?.first_name + ' ' + account.individual?.last_name,
        taxId: account.individual?.ssn_last_4 ? `***-**-${account.individual.ssn_last_4}` : null,
        address: account.individual?.address || account.company?.address
      }
    } catch (err) {
      app.log.error(`Could not fetch tax info for user ${userId}: ${err.message}`)
    }
  }

  return {
    userId,
    year: yearInt,
    totalEarnings,
    requires1099,
    taxInfo,
    generatedAt: new Date().toISOString()
  }
})

// ─── Multi-Currency Support ───────────────────────────────────────────────────
app.post('/pay/currency/convert', async (req, reply) => {
  const { amount, fromCurrency = 'usd', toCurrency = 'usd' } = req.body || {}
  
  if (!amount || amount <= 0) {
    reply.code(400)
    return { error: 'Invalid amount' }
  }

  // Use Stripe's built-in currency conversion rates
  try {
    const rate = await stripe.exchangeRates.retrieve(fromCurrency.toLowerCase())
    const toRate = rate.rates[toCurrency.toLowerCase()]
    if (!toRate) {
      reply.code(400)
      return { error: `Unsupported currency: ${toCurrency}` }
    }
    const convertedAmount = Math.round(amount * toRate)
    return {
      amount,
      fromCurrency: fromCurrency.toUpperCase(),
      toCurrency: toCurrency.toUpperCase(),
      convertedAmount,
      rate: toRate,
      timestamp: new Date().toISOString()
    }
  } catch (err) {
    reply.code(500)
    return { error: `Currency conversion failed: ${err.message}` }
  }
})

// ─── Payout Settings (enable/disable auto-payout) ─────────────────────────────
app.post('/pay/settings/auto-payout', async (req, reply) => {
  const { userId, enabled, thresholdCents } = req.body || {}
  if (!userId) {
    reply.code(400)
    return { error: 'userId required' }
  }

  await pool.query(
    `update pay_accounts set auto_payout_enabled=$1, auto_payout_threshold=$2 where user_id=$3`,
    [enabled || false, thresholdCents || 10000, userId]
  )

  return { ok: true, userId, autoPayoutEnabled: enabled, thresholdCents }
})

const port = process.env.PORT || 8888
app.listen({ port, host: '0.0.0.0' })


