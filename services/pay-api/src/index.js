import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import Stripe from 'stripe'
import pkg from 'pg'
const { Pool } = pkg

const stripe = new Stripe(process.env.STRIPE_SECRET || 'sk_test_123')
const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 100, timeWindow: '1 minute' })

const pool = new Pool({ connectionString: process.env.DATABASE_URL })

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

app.get('/health', async () => ({ status: 'ok' }))

app.post('/migrate', async () => {
  const { default: mod } = await import('./migrate.js')
  return { ok: true }
})

app.post('/pay/connect/link', async (req, reply) => {
  const { userId } = req.body || {}
  // Create or find connected account (stubbed local)
  const acct = await stripe.accounts.create({ type: 'express' })
  const link = await stripe.accountLinks.create({
    account: acct.id,
    refresh_url: 'https://example.com/reauth',
    return_url: 'https://example.com/return',
    type: 'account_onboarding'
  })
  await pool.query('insert into pay_accounts(user_id, stripe_account_id, status) values($1,$2,$3) on conflict do nothing', [userId, acct.id, 'pending'])
  return { url: link.url }
})

// Create Payment Intent for tip
app.post('/pay/tip/intent', async (req, reply) => {
  const { toUserId, amount, currency = 'usd' } = req.body || {}
  
  if (!process.env.STRIPE_SECRET || process.env.STRIPE_SECRET === 'sk_test_123') {
    // Development mode - return mock client secret
    return {
      clientSecret: `pi_mock_${Date.now()}_secret_mock`,
      paymentIntentId: `pi_mock_${Date.now()}`,
      mode: 'mock',
      currency,
      amount
    }
  }
  
  try {
    // Create PaymentIntent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount is already in cents
      currency: currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        type: 'tip',
        toUserId: toUserId
      }
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

app.post('/pay/tip', async (req, reply) => {
  const { toUserId, amount, currency = 'usd', message, paymentIntentId } = req.body || {}
  
  if (!process.env.STRIPE_SECRET || process.env.STRIPE_SECRET === 'sk_test_123') {
    // Development mode - just record ledger entry
    const accountId = await ensureLedgerAccount(toUserId, 'creator')
    await pool.query('insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)', [
      accountId, 
      amount, 
      currency, 
      'credit', 
      'tip',
      JSON.stringify({ message: message || null, paymentIntentId: paymentIntentId || null })
    ])
    const balance = await getCreatorBalanceSummary(toUserId)
    return { ok: true, tipId: `tip_${Date.now()}`, transactionId: paymentIntentId || 'mock', balance }
  }
  
  try {
    // Verify payment intent was successful
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId)
    
    if (paymentIntent.status !== 'succeeded') {
      reply.code(400)
      return { error: 'Payment not completed' }
    }
    
    // Record ledger entry
    const accountId = await ensureLedgerAccount(toUserId, 'creator')
    
    const tipId = `tip_${Date.now()}`
    await pool.query('insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)', [
      accountId, 
      amount, 
      currency, 
      'credit', 
      'tip',
      JSON.stringify({ 
        message: message || null, 
        paymentIntentId: paymentIntentId,
        stripeChargeId: paymentIntent.latest_charge || null
      })
    ])
    const balance = await getCreatorBalanceSummary(toUserId)
    
    return { 
      ok: true, 
      tipId: tipId, 
      transactionId: paymentIntentId,
      balance
    }
  } catch (error) {
    reply.code(500)
    return { error: error.message }
  }
})

// Accept settlements from Ads service and credit creator ledger (stub)
app.post('/pay/settlement', async (req) => {
  const { creatorId, amountCents = 0, currency = 'usd', campaignId = null, lineItemId = null, settlementDate = null } = req.body || {}
  const accountId = await ensureLedgerAccount(creatorId, 'creator')
  await pool.query('insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)', [
    accountId,
    amountCents,
    currency,
    'credit',
    'ads',
    JSON.stringify({ campaignId, lineItemId, settlementDate })
  ])
  const balance = await getCreatorBalanceSummary(creatorId)
  return { ok: true, balance }
})

app.get('/pay/creator/:userId/summary', async (req) => {
  const { userId } = req.params
  const balance = await getCreatorBalanceSummary(userId)
  const { rows: recentEntries } = await pool.query(
    'select amount, currency, direction, reference_type, metadata, created_at from ledger_entries where account_id=$1 order by created_at desc limit 20',
    [balance.accountId]
  )
  return {
    userId,
    balance,
    recentEntries
  }
})

const port = process.env.PORT || 8888
app.listen({ port, host: '0.0.0.0' })


