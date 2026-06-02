import { query } from '../lib/db.js'
import { currentBalanceCents } from '../lib/earnings.js'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET || 'sk_test_123')

/**
 * Publisher payments — AdSense "Payments": payment profile, tax forms,
 * payment threshold/hold, and monthly payout issuance once balance >= $100.
 * Uses Stripe Connect for actual money transfers.
 */
export default async function registerPubPaymentRoutes(app) {
  // Create Stripe Connect account for publisher
  app.post('/pub/payments/connect', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    
    if (pub.stripe_account_id) {
      return { ok: true, accountId: pub.stripe_account_id, status: 'existing' }
    }

    if (!process.env.STRIPE_SECRET) {
      return reply.code(503).send({ error: 'stripe_not_configured' })
    }

    try {
      // Create Stripe Connect Express account
      const account = await stripe.accounts.create({
        type: 'express',
        country: req.body.country || 'US',
        email: req.body.email,
        capabilities: {
          transfers: { requested: true }
        },
        business_type: req.body.businessType || 'individual',
        metadata: {
          publisher_id: pub.id.toString(),
          publisher_code: pub.publisher_code
        }
      })

      // Create account link for onboarding
      const accountLink = await stripe.accountLinks.create({
        account: account.id,
        refresh_url: req.body.refreshUrl || 'https://mychannel.live/publisher/payments/connect',
        return_url: req.body.returnUrl || 'https://mychannel.live/publisher/payments',
        type: 'account_onboarding'
      })

      // Save Stripe account ID
      await query(
        'update publishers set stripe_account_id=$2 where id=$1',
        [pub.id, account.id]
      )

      return { 
        ok: true, 
        accountId: account.id, 
        onboardingUrl: accountLink.url,
        status: 'created'
      }
    } catch (err) {
      console.error('Stripe Connect account creation failed:', err)
      return reply.code(500).send({ error: 'stripe_connect_failed', message: err.message })
    }
  })

  // Get Stripe Connect account status
  app.get('/pub/payments/connect/status', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    
    if (!pub.stripe_account_id) {
      return { connected: false, status: 'not_started' }
    }

    if (!process.env.STRIPE_SECRET) {
      return { connected: false, status: 'stripe_not_configured' }
    }

    try {
      const account = await stripe.accounts.retrieve(pub.stripe_account_id)
      return {
        connected: true,
        accountId: account.id,
        chargesEnabled: account.charges_enabled,
        payoutsEnabled: account.payouts_enabled,
        detailsSubmitted: account.details_submitted,
        requirements: account.requirements
      }
    } catch (err) {
      console.error('Failed to retrieve Stripe account:', err)
      return reply.code(500).send({ error: 'stripe_retrieval_failed', message: err.message })
    }
  })

  // Set / update payment profile.
  app.put('/pub/payments/profile', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const b = req.body || {}
    await query(
      `insert into pub_payment_profiles(publisher_id, method, account_name, account_details, tax_form_status, verified, updated_at)
       values($1,$2,$3,$4,$5,$6,now())
       on conflict (publisher_id) do update set
         method=excluded.method, account_name=excluded.account_name,
         account_details=excluded.account_details, updated_at=now()`,
      [pub.id, b.method || 'bank', b.accountName || null, b.accountDetails || {}, b.taxFormStatus || 'missing', !!b.verified]
    )
    return { ok: true }
  })

  app.get('/pub/payments', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const balance = await currentBalanceCents(pub.id)
    const { rows: profile } = await query('select method, account_name, tax_form_status, verified from pub_payment_profiles where publisher_id=$1', [pub.id])
    const { rows: payouts } = await query('select * from pub_payouts where publisher_id=$1 order by created_at desc limit 24', [pub.id])
    const { rows: p } = await query('select payment_threshold_cents, hold_payments from publishers where id=$1', [pub.id])
    const threshold = p[0]?.payment_threshold_cents || 10000
    return {
      balanceCents: balance,
      thresholdCents: threshold,
      onHold: p[0]?.hold_payments || false,
      eligible: balance >= threshold && !p[0]?.hold_payments,
      profile: profile[0] || null,
      payouts,
    }
  })

  // Update threshold or hold (publisher self-serve like AdSense).
  app.put('/pub/payments/settings', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const b = req.body || {}
    await query(
      `update publishers set payment_threshold_cents=coalesce($2,payment_threshold_cents),
         hold_payments=coalesce($3,hold_payments) where id=$1`,
      [pub.id, b.thresholdCents ?? null, typeof b.holdPayments === 'boolean' ? b.holdPayments : null]
    )
    return { ok: true }
  })

  // Issue a manual payout (also called by the monthly job).
  app.post('/pub/payments/issue', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const period = req.body?.period || new Date().toISOString().slice(0, 7)
    const result = await issuePayout(pub.id, period)
    if (!result.ok) return reply.code(400).send(result)
    return result
  })
}

/**
 * Core payout logic, shared with the monthly cron.
 * AdSense rules enforced here: must meet threshold, valid profile, no hold,
 * tax form approved. Debits the ledger so the next cycle starts fresh.
 * Uses Stripe Connect for actual money transfers.
 */
export async function issuePayout(publisherId, period) {
  const balance = await currentBalanceCents(publisherId)
  const { rows: p } = await query('select payment_threshold_cents, hold_payments, currency, stripe_account_id from publishers where id=$1', [publisherId])
  const threshold = p[0]?.payment_threshold_cents || 10000
  if (p[0]?.hold_payments) return { ok: false, reason: 'payments_on_hold' }
  if (balance < threshold) return { ok: false, reason: 'below_threshold', balanceCents: balance, thresholdCents: threshold }

  const { rows: prof } = await query('select * from pub_payment_profiles where publisher_id=$1', [publisherId])
  if (!prof.length || !prof[0].verified) return { ok: false, reason: 'payment_profile_unverified' }
  if (prof[0].tax_form_status !== 'approved') return { ok: false, reason: 'tax_form_required' }

  // Avoid double-paying the same period.
  const { rows: existing } = await query('select id from pub_payouts where publisher_id=$1 and period=$2 and status <> \'failed\'', [publisherId, period])
  if (existing.length) return { ok: false, reason: 'already_paid_for_period' }

  const reference = `PAYOUT-${period}-${publisherId}-${Date.now()}`
  let stripeTransferId = null
  let payoutStatus = 'pending'

  // Execute Stripe payout if configured
  if (process.env.STRIPE_SECRET && p[0]?.stripe_account_id) {
    try {
      // Create Stripe Transfer to publisher's connected account
      const transfer = await stripe.transfers.create({
        amount: balance,
        currency: p[0].currency || 'usd',
        destination: p[0].stripe_account_id,
        description: `MyChannel Publisher Payout - ${period}`,
        metadata: {
          publisher_id: publisherId.toString(),
          period,
          reference
        }
      })
      stripeTransferId = transfer.id
      payoutStatus = 'paid'
    } catch (err) {
      // Log error but record the payout attempt
      console.error('Stripe transfer failed:', err)
      payoutStatus = 'failed'
      await query(
        `insert into pub_payouts(publisher_id, period, amount_cents, status, method, reference, stripe_transfer_id, error_message, created_at)
         values($1,$2,$3,$4,$5,$6,$7,$8, now())`,
        [publisherId, period, balance, payoutStatus, prof[0].method, reference, stripeTransferId, err.message]
      )
      return { ok: false, reason: 'stripe_transfer_failed', error: err.message }
    }
  } else {
    // No Stripe configured or no connected account - mark as pending manual processing
    payoutStatus = 'pending_manual'
  }

  await query(
    `insert into pub_payouts(publisher_id, period, amount_cents, status, method, reference, stripe_transfer_id, paid_at)
     values($1,$2,$3,$4,$5,$6,$7, now())`,
    [publisherId, period, balance, payoutStatus, prof[0].method, reference, stripeTransferId]
  )
  
  // Debit ledger to zero out paid balance (only if successful)
  if (payoutStatus === 'paid') {
    await query(
      `insert into pub_ledger(publisher_id, entry_type, amount_cents, balance_after_cents, ref, meta)
       values($1,'payout',$2,$3,$4,$5)`,
      [publisherId, -balance, 0, reference, JSON.stringify({ period, stripe_transfer_id: stripeTransferId })]
    )
  }
  
  return { ok: true, amountCents: balance, reference, period, stripeTransferId, status: payoutStatus }
}

async function resolvePublisher(req) {
  const code = req.headers['x-mca-client'] || req.query.client || req.body?.client
  const apiKey = req.headers['x-mca-key'] || req.query.apiKey
  if (apiKey) {
    const { rows } = await query('select * from publishers where api_key=$1', [apiKey])
    if (rows.length) return rows[0]
  }
  if (code) {
    const { rows } = await query('select * from publishers where publisher_code=$1', [code])
    if (rows.length) return rows[0]
  }
  return null
}
