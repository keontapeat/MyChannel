import { query } from '../lib/db.js'
import Stripe from 'stripe'
const stripe = new Stripe(process.env.STRIPE_SECRET || 'sk_test_123')

export default async function registerAdvertiserRoutes(app) {
  app.post('/ads/creative/uploadUrl', async () => ({ signedUrl: 'https://storage.googleapis.com/mock/upload', storagePath: `creatives/${Date.now()}.mp4` }))

  app.post('/ads/campaign', async (req) => {
    const b = req.body
    const { rows: adv } = await query('select id from advertisers where email=$1 limit 1', [b.email])
    const advertiserId = adv[0]?.id || (await query('insert into advertisers(name,email,status) values($1,$2,\'active\') returning id',[b.advertiserName||'Advertiser', b.email])).rows[0].id
    const { rows: camp } = await query('insert into campaigns(advertiser_id,name,objective,status,start_at,end_at,budget_cents,daily_cap_cents,cpm_floor_cents,geo,languages,devices,topics) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) returning id',[advertiserId,b.name,b.objective||'reach',b.status||'active',b.start_at||null,b.end_at||null,b.budget_cents||0,b.daily_cap_cents||0,b.cpm_floor_cents||0,b.geo||[],b.languages||[],b.devices||[],b.topics||[]])
    const campaignId = camp[0].id
    const lineItemIds = []
    for (const li of (b.line_items||[])) {
      const { rows } = await query('insert into line_items(campaign_id,placement,bid_cpm_cents,frequency_cap,max_imps,targeting_json,status) values($1,$2,$3,$4,$5,$6,$7) returning id',[campaignId, li.placement, li.bid_cpm_cents||0, li.frequency_cap||0, li.max_imps||0, li.targeting_json||{}, li.status||'active'])
      lineItemIds.push(rows[0].id)
    }
    return { id: campaignId, line_item_ids: lineItemIds }
  })

  app.post('/ads/creative', async (req) => {
    const b = req.body
    const { rows } = await query('insert into creatives(line_item_id,type,uri,click_url,width,height,duration_sec,review_status) values($1,$2,$3,$4,$5,$6,$7,\'pending\') returning id',[b.line_item_id,b.type||'video',b.uri,b.click_url,b.width||0,b.height||0,b.duration_sec||0])
    return { id: rows[0].id }
  })

  app.post('/ads/campaign/:id/status', async (req) => {
    await query('update campaigns set status=$2 where id=$1',[req.params.id, req.body.status])
    return { ok: true }
  })

  app.get('/ads/campaign/:id/metrics', async (req) => {
    const { rows: imp } = await query('select count(*)::int as imps from ad_impressions where campaign_id=$1 and ts between coalesce($2,\'epoch\'::timestamptz) and coalesce($3, now())',[req.params.id, req.query.from, req.query.to])
    const { rows: clk } = await query('select count(*)::int as clicks from ad_clicks c join ad_impressions i on i.id=c.impression_id where i.campaign_id=$1 and c.ts between coalesce($2,\'epoch\'::timestamptz) and coalesce($3, now())',[req.params.id, req.query.from, req.query.to])
    return { impressions: imp[0].imps, clicks: clk[0].clicks }
  })

  app.get('/ads/campaigns', async (req) => {
    const { email } = req.query
    const { rows: adv } = await query('select id from advertisers where email=$1 limit 1',[email])
    if (!adv.length) return { campaigns: [] }
    const advertiserId = adv[0].id
    const { rows: camps } = await query('select * from campaigns where advertiser_id=$1 order by created_at desc',[advertiserId])
    for (const c of camps) {
      const { rows: lis } = await query('select * from line_items where campaign_id=$1',[c.id])
      for (const li of lis) {
        const { rows: crs } = await query('select * from creatives where line_item_id=$1',[li.id])
        li.creatives = crs
      }
      c.line_items = lis
    }
    return { campaigns: camps }
  })

  app.post('/ads/fund', async (req) => {
    const { email, amount_cents, confirm=true } = req.body
    const { rows: adv } = await query('select id from advertisers where email=$1 limit 1',[email])
    if (!adv.length) throw new Error('advertiser not found')
    // Stripe PaymentIntent (test mode). In local dev, immediately credit.
    const amount = Number(amount_cents)||0
    if (process.env.STRIPE_SECRET) {
      const intent = await stripe.paymentIntents.create({ amount, currency: 'usd', capture_method: 'automatic', confirm })
      await query('update advertisers set balance_cents = coalesce(balance_cents,0)+$2 where id=$1',[adv[0].id, amount])
      return { ok: true, payment_intent: intent.id }
    }
    await query('update advertisers set balance_cents = coalesce(balance_cents,0)+$2 where id=$1',[adv[0].id, amount])
    return { ok: true, payment_intent: 'mock' }
  })

  app.get('/ads/balance', async (req) => {
    const { email } = req.query
    const { rows } = await query('select balance_cents from advertisers where email=$1',[email])
    return { balance_cents: rows[0]?.balance_cents||0 }
  })
}


