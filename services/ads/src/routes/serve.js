import { query } from '../lib/db.js'
import crypto from 'crypto'
import { recomputeFloors } from '../jobs/floors.js'

function buildAuctionDiagnostics(eligible, floor) {
  return {
    eligibleCount: eligible.length,
    floorCpmCents: floor,
    topBids: eligible.slice(0, 3).map(li => ({ lineItemId: li.id, bidCpmCents: li.bid_cpm_cents || 0 }))
  }
}

function matchTargeting(li, body) {
  const t = li.targeting_json || {}
  if (t.geo && t.geo.length && !t.geo.includes((body.locale||'').split('-').pop())) return false
  if (t.languages && t.languages.length && !t.languages.includes((body.locale||'').split('-')[0])) return false
  if (t.devices && t.devices.length && !t.devices.includes(body.device||'other')) return false
  if (t.topics && t.topics.length) {
    const topics = new Set([...(body.videoContext?.tags||[]), body.videoContext?.topic].filter(Boolean))
    if (![...topics].some(x => t.topics.includes(x))) return false
  }
  return true
}

export default async function registerServeRoute(app) {
  app.post('/ads/serve', {
    schema: { body: { type: 'object', required: ['key','placement'], properties: { key: {type:'string'}, placement:{type:'string'}, user:{type:'object'}, locale:{type:'string'}, device:{type:'string'}, videoContext:{type:'object'} } } }
  }, async (req, reply) => {
    const body = req.body
    // validate serving key & optional HMAC
    const { rows: keys } = await query('select id,app,placement,key,hmac_secret,status from serving_keys where key=$1 and status=\'active\'', [body.key])
    if (!keys.length) return reply.code(401).send({ error: 'invalid_key' })
    const secret = keys[0].hmac_secret
    if (secret) {
      const sig = req.headers['x-ads-signature']
      const payload = JSON.stringify(body)
      const digest = crypto.createHmac('sha256', secret).update(payload).digest('hex')
      if (sig !== digest) return reply.code(401).send({ error: 'bad_signature' })
    }

    // eligible line items
    const { rows: lis } = await query("select li.*, c.uri as creative_uri, c.click_url, c.duration_sec from line_items li join creatives c on c.line_item_id=li.id where li.status='active' and c.review_status='approved'", [])
    // apply dynamic floors
    const { rows: floorRows } = await query("select * from floors where (country=$1 or country is null) and (device=$2 or device is null) and (placement=$3 or placement is null)",[ (body.locale||'').split('-').pop(), body.device||'ios', body.placement||'preroll'])
    const floor = floorRows[0]?.floor_cpm_cents||0
    const eligible = lis.filter(li => matchTargeting(li, body) && (li.bid_cpm_cents||0) >= floor)
    // auction by bid cpm
    eligible.sort((a,b)=> (b.bid_cpm_cents||0)-(a.bid_cpm_cents||0))
    if (!eligible.length) return { fill: 'none', reason: 'no_eligible_line_items', auction: buildAuctionDiagnostics([], floor) }
    const winner = eligible[0]
    const runnerUp = eligible[1] || null
    const clearingCpmCents = Math.max(floor, Math.min(winner.bid_cpm_cents || floor, (runnerUp?.bid_cpm_cents || floor) + 1))
    // simple frequency cap by ip hash per placement in last hour
    const ipHash = crypto.createHash('md5').update(req.ip).digest('hex')
    const { rows: freq } = await query("select count(*)::int as c from ad_requests where ip_hash=$1 and placement=$2 and ts > now() - interval '1 hour'",[ipHash, body.placement])
    if ((freq[0]?.c||0) > 120) return { fill: 'none', reason: 'frequency_cap', auction: buildAuctionDiagnostics(eligible, floor) }

    const { rows: reqIns } = await query('insert into ad_requests(key_id, placement, locale, device, ip_hash, ua_hash, ts) values($1,$2,$3,$4,$5,md5($6),now()) returning id',[keys[0].id, body.placement, body.locale||'', body.device||'', ipHash, req.headers['user-agent']||''])
    const requestId = reqIns[0].id
    const trackingBase = `${process.env.ADS_BASE_URL||''}/ads/track`
    return {
      fill: 'direct',
      creative: { uri: winner.creative_uri, clickUrl: winner.click_url, duration: winner.duration_sec||0 },
      auction: {
        requestId,
        lineItemId: winner.id,
        clearingCpmCents,
        winningBidCpmCents: winner.bid_cpm_cents || 0,
        runnerUpBidCpmCents: runnerUp?.bid_cpm_cents || null,
        ...buildAuctionDiagnostics(eligible, floor)
      },
      tracking: {
        impUrl: `${trackingBase}/imp?rid=${requestId}&li=${winner.id}&q=0`,
        q25Url: `${trackingBase}/imp?rid=${requestId}&li=${winner.id}&q=25`,
        q50Url: `${trackingBase}/imp?rid=${requestId}&li=${winner.id}&q=50`,
        q75Url: `${trackingBase}/imp?rid=${requestId}&li=${winner.id}&q=75`,
        q100Url: `${trackingBase}/imp?rid=${requestId}&li=${winner.id}&q=100`,
        clickUrl: `${trackingBase}/click?rid=${requestId}&li=${winner.id}`
      }
    }
  })

  app.post('/ads/track/imp', async (req) => {
    const { rid, li, q } = req.query
    await query('insert into ad_impressions(request_id,line_item_id,ts,quartile) values($1,$2,now(),$3) on conflict do nothing',[rid, li, String(q)])
    return { ok: true }
  })

  app.post('/ads/track/click', async (req) => {
    const { rid, li } = req.query
    const { rows } = await query('select id from ad_impressions where request_id=$1 and line_item_id=$2 order by id desc limit 1',[rid, li])
    const impId = rows[0]?.id
    if (impId) await query('insert into ad_clicks(impression_id, ts) values($1, now())',[impId])
    return { ok: true }
  })

  // Simple VMAP response for client players that expect schedule
  app.post('/ads/vmap', async (req, reply) => {
    const body = req.body || {}
    const serve = await app.inject({ method: 'POST', url: '/ads/serve', payload: body })
    const res = serve.json()
    if (!res || res.fill === 'none') return reply.code(204).send()
    const vmap = `<?xml version="1.0" encoding="UTF-8"?>
<vmap:VMAP xmlns:vmap="http://www.iab.net/videosuite/vmap" version="1.0">
  <vmap:AdBreak breakType="linear" breakId="preroll" timeOffset="start">
    <vmap:AdSource id="direct" allowMultipleAds="false" followRedirects="true">
      <vmap:VASTAdData>
        <VAST version="3.0">
          <Ad id="direct1">
            <InLine>
              <Creatives>
                <Creative>
                  <Linear>
                    <TrackingEvents>
                      <Tracking event="start">${res.tracking.impUrl}</Tracking>
                      <Tracking event="firstQuartile">${res.tracking.q25Url}</Tracking>
                      <Tracking event="midpoint">${res.tracking.q50Url}</Tracking>
                      <Tracking event="thirdQuartile">${res.tracking.q75Url}</Tracking>
                      <Tracking event="complete">${res.tracking.q100Url}</Tracking>
                    </TrackingEvents>
                    <MediaFiles>
                      <MediaFile delivery="progressive" type="video/mp4" width="1280" height="720" bitrate="1000">${res.creative.uri}</MediaFile>
                    </MediaFiles>
                  </Linear>
                </Creative>
              </Creatives>
            </InLine>
          </Ad>
        </VAST>
      </vmap:VASTAdData>
    </vmap:AdSource>
  </vmap:AdBreak>
</vmap:VMAP>`
    reply.header('Content-Type', 'application/xml')
    return reply.send(vmap)
  })
}


