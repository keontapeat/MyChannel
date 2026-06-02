import { query } from '../lib/db.js'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET || 'sk_test_123')

/**
 * Stripe webhook handler for payment events.
 * Handles payment confirmations, failed payments, and Connect account updates.
 */
export default async function registerWebhookRoutes(app) {
  // Stripe webhook endpoint (must be raw body for signature verification)
  app.post('/webhooks/stripe', {
    config: {
      rawBody: true
    }
  }, async (req, reply) => {
    const sig = req.headers['stripe-signature']
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET

    if (!webhookSecret) {
      app.log.warn('STRIPE_WEBHOOK_SECRET not configured')
      return reply.code(400).send({ error: 'webhook_secret_not_configured' })
    }

    let event
    try {
      event = stripe.webhooks.constructEvent(req.rawBody || req.body, sig, webhookSecret)
    } catch (err) {
      app.log.error({ err }, 'Webhook signature verification failed')
      return reply.code(400).send({ error: 'invalid_signature' })
    }

    app.log.info({ type: event.type, id: event.id }, 'Stripe webhook received')

    try {
      switch (event.type) {
        // Advertiser funding events
        case 'payment_intent.succeeded': {
          const intent = event.data.object
          const { advertiser_id, amount_cents } = intent.metadata
          if (advertiser_id) {
            await query(
              'update advertisers set balance_cents = coalesce(balance_cents,0)+$2 where id=$1',
              [advertiser_id, amount_cents]
            )
            app.log.info({ advertiser_id, amount_cents }, 'Advertiser funded via PaymentIntent')
          }
          break
        }

        case 'payment_intent.payment_failed': {
          const intent = event.data.object
          app.log.error({ intent_id: intent.id, error: intent.last_payment_error }, 'Payment failed')
          // Could notify advertiser or mark funding attempt as failed
          break
        }

        // Publisher payout events (Stripe Connect)
        case 'transfer.created': {
          const transfer = event.data.object
          const { publisher_id, period, reference } = transfer.metadata
          if (publisher_id) {
            await query(
              `update pub_payouts set stripe_transfer_id=$2, status='processing' 
               where publisher_id=$1 and period=$3 and reference=$4`,
              [publisher_id, transfer.id, period, reference]
            )
            app.log.info({ publisher_id, transfer_id: transfer.id }, 'Transfer created')
          }
          break
        }

        case 'transfer.paid': {
          const transfer = event.data.object
          const { publisher_id } = transfer.metadata
          if (publisher_id) {
            await query(
              `update pub_payouts set status='paid', paid_at=now() 
               where stripe_transfer_id=$1`,
              [transfer.id]
            )
            app.log.info({ publisher_id, transfer_id: transfer.id }, 'Transfer paid')
          }
          break
        }

        case 'transfer.failed': {
          const transfer = event.data.object
          const { publisher_id } = transfer.metadata
          if (publisher_id) {
            await query(
              `update pub_payouts set status='failed', error_message=$2 
               where stripe_transfer_id=$1`,
              [transfer.id, transfer.failure_message || 'Transfer failed']
            )
            app.log.error({ publisher_id, transfer_id: transfer.id }, 'Transfer failed')
          }
          break
        }

        // Stripe Connect account events
        case 'account.updated': {
          const account = event.data.object
          const { rows } = await query(
            'select id from publishers where stripe_account_id=$1',
            [account.id]
          )
          if (rows.length) {
            const pub = rows[0]
            const canPayout = account.charges_enabled && account.payouts_enabled && account.details_submitted
            app.log.info({ 
              publisher_id: pub.id, 
              account_id: account.id, 
              can_payout: canPayout 
            }, 'Connect account updated')
            
            // Could update publisher status based on account capabilities
            if (canPayout) {
              await query(
                `update publishers set status='approved' where id=$1 and status='pending'`,
                [pub.id]
              )
            }
          }
          break
        }

        default:
          app.log.info({ type: event.type }, 'Unhandled webhook event type')
      }

      return { received: true, event_id: event.id }
    } catch (err) {
      app.log.error({ err, event_type: event.type }, 'Webhook processing error')
      return reply.code(500).send({ error: 'webhook_processing_failed' })
    }
  })

  // Health check for webhook endpoint
  app.get('/webhooks/stripe', async () => ({
    status: 'ok',
    webhook_secret_configured: !!process.env.STRIPE_WEBHOOK_SECRET
  }))
}
