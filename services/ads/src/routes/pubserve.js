import { query } from '../lib/db.js'
import { runDisplayAuction } from '../lib/auction.js'
import { bookRevenue, reverseRevenue } from '../lib/earnings.js'
import { scoreClick, scoreRequest } from '../lib/ivt.js'
import { hashIp, hashUa } from '../lib/ids.js'

/**
 * Publisher-side ad serving — the endpoints the embeddable mca.js tag calls.
 * Mirrors how AdSense fills a slot: request -> auction -> render -> track imp/click.
 */
export default async function registerPubServeRoutes(app) {
  // Ad fill request from the JS tag.
  app.get('/pub/ad', async (req, reply) => handleServe(req, reply, req.query))
  app.post('/pub/ad', async (req, reply) => handleServe(req, reply, req.body || {}))

  async function handleServe(req, reply, params) {
    const { client, slot, url, w, h } = params
    if (!client || !slot) return reply.code(400).send({ error: 'missing_client_or_slot' })

    // Resolve publisher + ad unit, ensure serving is allowed.
    const { rows: unitRows } = await query(
      `select u.*, p.id pub_id, p.status pub_status, p.ad_serving_enabled, p.hold_payments
         from ad_units u join publishers p on p.id=u.publisher_id
        where u.slot_id=$1 and p.publisher_code=$2`,
      [slot, client]
    )
    if (!unitRows.length) return emptyFill(reply, 'unknown_slot')
    const unit = unitRows[0]
    if (unit.status !== 'active') return emptyFill(reply, 'unit_paused')
    if (unit.pub_status !== 'approved' || !unit.ad_serving_enabled) return emptyFill(reply, 'serving_disabled')

    const ipHash = hashIp(req.ip)
    const uaHash = hashUa(req.headers['user-agent'])
    const country = (req.headers['x-country'] || req.headers['cf-ipcountry'] || 'US').toString().slice(0, 2).toUpperCase()
    const device = guessDevice(req.headers['user-agent'])

    // IVT pre-filter on the request itself.
    const reqScore = await scoreRequest({ ua: req.headers['user-agent'] || '', ipHash, publisherId: unit.pub_id })

    const { rows: reqIns } = await query(
      `insert into pub_ad_requests(publisher_id,site_id,ad_unit_id,slot_id,page_url,referrer,country,device,ip_hash,ua_hash)
       values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) returning id`,
      [unit.pub_id, unit.site_id, unit.id, slot, url || req.headers['referer'] || '', req.headers['referer'] || '', country, device, ipHash, uaHash]
    )
    const requestId = reqIns[0].id
    if (reqScore.invalid) return emptyFill(reply, 'invalid_traffic')

    // Candidate demand: active display/CPC line items with approved creatives,
    // respecting this publisher's blocking controls.
    const sizeStr = w && h ? `${w}x${h}` : null
    const { rows: bc } = await query('select * from pub_blocking_controls where publisher_id=$1', [unit.pub_id])
    const blockedIds = bc[0]?.blocked_advertiser_ids || []

    const { rows: candidates } = await query(
      `select li.*, c.id creative_id, c.uri, c.click_url, c.headline, c.body, c.image_url, c.html,
              c.width cw, c.height ch, c.format cformat, c.advertiser_name, cm.advertiser_id,
              coalesce(stat.imps,0) hist_impressions, coalesce(stat.clicks,0) hist_clicks
         from line_items li
         join creatives c on c.line_item_id=li.id
         join campaigns cm on cm.id=li.campaign_id
         left join (
            select line_item_id, count(*) imps,
                   sum(case when exists(select 1 from pub_clicks pc where pc.impression_id=pi.id) then 1 else 0 end) clicks
              from pub_impressions pi group by line_item_id
         ) stat on stat.line_item_id=li.id
        where li.status='active' and c.review_status='approved'
          and cm.status='active'
          and (li.formats = '{}' or $1 = any(li.formats))
          and (li.sizes = '{}' or $2 is null or $2 = any(li.sizes))
          and ($3::int[] = '{}' or cm.advertiser_id <> all($3::int[]))`,
      [unit.format, sizeStr, blockedIds]
    )

    // Marketplace floor for this geo/device/placement.
    const { rows: floorRows } = await query(
      `select floor_cpm_cents from floors
         where (country=$1 or country is null) and (device=$2 or device is null) and (placement='display' or placement is null)
         order by country nulls last, device nulls last limit 1`,
      [country, device]
    )
    const floor = floorRows[0]?.floor_cpm_cents || 0

    const result = runDisplayAuction(candidates, floor)
    if (!result) return emptyFill(reply, 'no_demand', requestId)

    const { winner, predictedCtr, clearingEcpmCents, clearingPriceCents, diagnostics } = result

    // For CPM we book revenue now; for CPC we book on the click.
    let gross = 0, pubCents = 0, platformCents = 0
    if (winner.pricing_model !== 'cpc') {
      gross = clearingEcpmCents / 1000 // one impression's worth
      const booked = await bookRevenue({ publisherId: unit.pub_id, grossCents: gross, source: 'earning', ref: `imp:${requestId}`, meta: { slot, model: 'cpm' } })
      pubCents = booked.pubCents; platformCents = booked.platformCents
    }

    const { rows: impIns } = await query(
      `insert into pub_impressions(request_id,publisher_id,ad_unit_id,campaign_id,line_item_id,creative_id,pricing_model,gross_cents,pub_cents,platform_cents,predicted_ctr,ecpm_cents)
       values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning id`,
      [requestId, unit.pub_id, unit.id, winner.campaign_id, winner.id, winner.creative_id,
       winner.pricing_model, gross, pubCents, platformCents, predictedCtr, Math.round(clearingEcpmCents)]
    )
    const impressionId = impIns[0].id
    await query('update pub_ad_requests set filled=true where id=$1', [requestId])

    const base = `${process.env.ADS_BASE_URL || ''}/pub`
    return reply.send({
      fill: true,
      format: winner.cformat || unit.format,
      creative: {
        headline: winner.headline || null,
        body: winner.body || null,
        imageUrl: winner.image_url || winner.uri || null,
        html: winner.html || null,
        advertiser: winner.advertiser_name || 'Sponsored',
        width: winner.cw || unit.width || 0,
        height: winner.ch || unit.height || 0,
      },
      click: `${base}/click?imp=${impressionId}`,
      impPing: `${base}/imp?imp=${impressionId}`,
      viewPing: `${base}/view?imp=${impressionId}`,
      auction: { clearingEcpmCents: Math.round(clearingEcpmCents), pricingModel: winner.pricing_model, ...diagnostics },
    })
  }

  // Viewability ping (MRC: 50% pixels for 1s). Marks impression viewable.
  app.get('/pub/view', async (req) => {
    await query('update pub_impressions set viewable=true where id=$1', [req.query.imp])
    return { ok: true }
  })

  // Impression confirmation (rendered).
  app.get('/pub/imp', async (req, reply) => {
    reply.header('Content-Type', 'image/gif')
    return reply.send(TRANSPARENT_GIF)
  })

  // Click handler — books CPC revenue, runs IVT, then redirects to advertiser.
  app.get('/pub/click', async (req, reply) => {
    const impId = req.query.imp
    const { rows } = await query(
      `select pi.*, c.click_url, p.id pub_id
         from pub_impressions pi
         join creatives c on c.id=pi.creative_id
         join publishers p on p.id=pi.publisher_id
        where pi.id=$1`, [impId]
    )
    if (!rows.length) return reply.code(404).send('not found')
    const imp = rows[0]
    const ipHash = hashIp(req.ip)

    const ivt = await scoreClick({
      publisherId: imp.pub_id, adUnitId: imp.ad_unit_id, ipHash,
      ua: req.headers['user-agent'] || '', impressionId: impId,
    })

    let gross = 0, pubCents = 0, platformCents = 0
    if (imp.pricing_model === 'cpc') {
      const { rows: liRows } = await query('select bid_cpc_cents from line_items where id=$1', [imp.line_item_id])
      gross = Number(liRows[0]?.bid_cpc_cents || 0)
      if (!ivt.invalid) {
        const booked = await bookRevenue({ publisherId: imp.pub_id, grossCents: gross, source: 'earning', ref: `click:${impId}`, meta: { model: 'cpc' } })
        pubCents = booked.pubCents; platformCents = booked.platformCents
      }
    }

    await query(
      `insert into pub_clicks(impression_id,publisher_id,ad_unit_id,campaign_id,line_item_id,creative_id,gross_cents,pub_cents,platform_cents,invalid,ip_hash)
       values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [impId, imp.pub_id, imp.ad_unit_id, imp.campaign_id, imp.line_item_id, imp.creative_id, gross, pubCents, platformCents, ivt.invalid, ipHash]
    )

    if (ivt.invalid) {
      await query(
        `insert into fraud_events(impression_id,type,score,meta,ts) values($1,'invalid_click',$2,$3,now())`,
        [impId, ivt.score, JSON.stringify({ reasons: ivt.reasons })]
      )
    }

    const dest = imp.click_url || '/'
    return reply.redirect(dest)
  })
}

function emptyFill(reply, reason, requestId = null) {
  return reply.send({ fill: false, reason, requestId })
}

function guessDevice(ua = '') {
  if (/mobile|android|iphone/i.test(ua)) return 'mobile'
  if (/ipad|tablet/i.test(ua)) return 'tablet'
  if (/smart-?tv|appletv|roku/i.test(ua)) return 'tv'
  return 'desktop'
}

const TRANSPARENT_GIF = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64')

export { reverseRevenue }
