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
      paymentIntentId: `pi_mock_${Date.now()}`
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
      paymentIntentId: paymentIntent.id
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
    const { rows: acct } = await pool.query('insert into ledger_accounts(user_id, type) values($1,$2) on conflict do nothing returning id', [toUserId, 'creator'])
    const accountId = acct[0]?.id || (await pool.query('select id from ledger_accounts where user_id=$1 limit 1', [toUserId])).rows[0].id
    await pool.query('insert into ledger_entries(account_id, amount, currency, direction, reference_type, metadata) values($1,$2,$3,$4,$5,$6)', [
      accountId, 
      amount, 
      currency, 
      'credit', 
      'tip',
      JSON.stringify({ message: message || null, paymentIntentId: paymentIntentId || null })
    ])
    return { ok: true, tipId: `tip_${Date.now()}`, transactionId: paymentIntentId || 'mock' }
  }
  
  try {
    // Verify payment intent was successful
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId)
    
    if (paymentIntent.status !== 'succeeded') {
      reply.code(400)
      return { error: 'Payment not completed' }
    }
    
    // Record ledger entry
    const { rows: acct } = await pool.query('insert into ledger_accounts(user_id, type) values($1,$2) on conflict do nothing returning id', [toUserId, 'creator'])
    const accountId = acct[0]?.id || (await pool.query('select id from ledger_accounts where user_id=$1 limit 1', [toUserId])).rows[0].id
    
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
    
    return { 
      ok: true, 
      tipId: tipId, 
      transactionId: paymentIntentId 
    }
  } catch (error) {
    reply.code(500)
    return { error: error.message }
  }
})

// Accept settlements from Ads service and credit creator ledger (stub)
app.post('/pay/settlement', async (req) => {
  const { creatorId, amountCents = 0, currency = 'usd' } = req.body || {}
  const { rows: acct } = await pool.query('insert into ledger_accounts(user_id, type) values($1,$2) on conflict do nothing returning id', [creatorId, 'creator'])
  const accountId = acct[0]?.id || (await pool.query('select id from ledger_accounts where user_id=$1 limit 1', [creatorId])).rows[0].id
  await pool.query('insert into ledger_entries(account_id, amount, currency, direction, reference_type) values($1,$2,$3,$4,$5)', [accountId, amountCents, currency, 'credit', 'ads'])
  return { ok: true }
})

const port = process.env.PORT || 8888
app.listen({ port, host: '0.0.0.0' })


