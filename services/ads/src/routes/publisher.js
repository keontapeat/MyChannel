import { query } from '../lib/db.js'
import { newPublisherCode, newSlotId, newApiKey, newToken } from '../lib/ids.js'

/**
 * Publisher account + site + ad-unit management.
 * This is the AdSense "account" surface: sign up, add a site, verify it,
 * create ad units, and copy the ad code.
 */
export default async function registerPublisherRoutes(app) {
  // ---- Account ---------------------------------------------------------
  app.post('/pub/signup', {
    schema: { body: { type: 'object', required: ['email'], properties: {
      email: { type: 'string' }, name: { type: 'string' },
      country: { type: 'string' }, userId: { type: 'string' }, url: { type: 'string' },
    } } }
  }, async (req) => {
    const b = req.body
    const existing = await query('select * from publishers where email=$1', [b.email])
    if (existing.rows.length) return { publisher: existing.rows[0], existing: true }

    const code = newPublisherCode()
    const apiKey = newApiKey()
    const { rows } = await query(
      `insert into publishers(user_id,publisher_code,email,name,country,api_key,status)
       values($1,$2,$3,$4,$5,$6,'pending') returning *`,
      [b.userId || null, code, b.email, b.name || null, b.country || 'US', apiKey]
    )
    const publisher = rows[0]

    // default blocking controls row
    await query('insert into pub_blocking_controls(publisher_id) values($1) on conflict do nothing', [publisher.id])

    // optional first site
    if (b.url) await addSite(publisher.id, b.url)

    return { publisher, existing: false }
  })

  app.get('/pub/account', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const sites = (await query('select * from pub_sites where publisher_id=$1 order by created_at', [pub.id])).rows
    const units = (await query('select * from ad_units where publisher_id=$1 order by created_at', [pub.id])).rows
    return { account: scrub(pub), sites, adUnits: units }
  })

  // Admin/review: approve or reject an account (AdSense "Getting ready" -> approved)
  app.post('/pub/:code/review', async (req, reply) => {
    const { decision, reason } = req.body || {}
    const status = decision === 'approve' ? 'approved' : 'rejected'
    const { rows } = await query(
      `update publishers set status=$2, rejection_reason=$3,
         approved_at = case when $2='approved' then now() else approved_at end
       where publisher_code=$1 returning *`,
      [req.params.code, status, status === 'rejected' ? (reason || 'Policy non-compliance') : null]
    )
    if (!rows.length) return reply.code(404).send({ error: 'publisher_not_found' })
    return { publisher: scrub(rows[0]) }
  })

  // ---- Sites -----------------------------------------------------------
  app.post('/pub/sites', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const site = await addSite(pub.id, req.body.url)
    return { site, adsTxtLine: adsTxtLine(pub.publisher_code) }
  })

  // Verify a site by crawling its ads.txt for our publisher line.
  app.post('/pub/sites/:id/verify', async (req, reply) => {
    const { rows } = await query('select s.*, p.publisher_code from pub_sites s join publishers p on p.id=s.publisher_id where s.id=$1', [req.params.id])
    if (!rows.length) return reply.code(404).send({ error: 'site_not_found' })
    const site = rows[0]
    const verified = await verifyAdsTxt(site.domain, site.publisher_code)
    const status = verified ? 'ready' : 'needs_attention'
    await query('update pub_sites set ads_txt_verified=$2, status=$3, last_crawled_at=now() where id=$1', [site.id, verified, status])
    return { verified, status, expectedLine: adsTxtLine(site.publisher_code) }
  })

  // ---- Ad units --------------------------------------------------------
  app.post('/pub/adunits', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const b = req.body || {}
    const slot = newSlotId()
    const { rows } = await query(
      `insert into ad_units(publisher_id,site_id,slot_id,name,format,sizing,width,height,full_width_responsive)
       values($1,$2,$3,$4,$5,$6,$7,$8,$9) returning *`,
      [pub.id, b.siteId || null, slot, b.name || 'Ad unit', b.format || 'display',
       b.sizing || 'auto', b.width || 0, b.height || 0, b.fullWidthResponsive !== false]
    )
    const unit = rows[0]
    return { adUnit: unit, code: adCode(pub.publisher_code, unit) }
  })

  app.get('/pub/adunits/:slot/code', async (req, reply) => {
    const { rows } = await query(
      'select u.*, p.publisher_code from ad_units u join publishers p on p.id=u.publisher_id where u.slot_id=$1',
      [req.params.slot]
    )
    if (!rows.length) return reply.code(404).send({ error: 'ad_unit_not_found' })
    return { code: adCode(rows[0].publisher_code, rows[0]) }
  })

  app.post('/pub/adunits/:slot/status', async (req) => {
    await query('update ad_units set status=$2 where slot_id=$1', [req.params.slot, req.body.status])
    return { ok: true }
  })

  // ---- Blocking controls (advertiser/category blocking) ----------------
  app.put('/pub/blocking-controls', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const b = req.body || {}
    await query(
      `insert into pub_blocking_controls(publisher_id, blocked_categories, blocked_advertiser_domains, blocked_advertiser_ids, allow_sensitive, updated_at)
       values($1,$2,$3,$4,$5,now())
       on conflict (publisher_id) do update set
         blocked_categories=excluded.blocked_categories,
         blocked_advertiser_domains=excluded.blocked_advertiser_domains,
         blocked_advertiser_ids=excluded.blocked_advertiser_ids,
         allow_sensitive=excluded.allow_sensitive, updated_at=now()`,
      [pub.id, b.blockedCategories || [], b.blockedAdvertiserDomains || [], b.blockedAdvertiserIds || [], !!b.allowSensitive]
    )
    return { ok: true }
  })
}

// ----- helpers ----------------------------------------------------------
async function addSite(publisherId, url) {
  const domain = normalizeDomain(url)
  const token = newToken('site')
  const { rows } = await query(
    `insert into pub_sites(publisher_id, domain, verification_token, status)
     values($1,$2,$3,'pending_verification')
     on conflict (publisher_id, domain) do update set verification_token=excluded.verification_token
     returning *`,
    [publisherId, domain, token]
  )
  return rows[0]
}

export function normalizeDomain(url = '') {
  try {
    const u = url.includes('://') ? new URL(url) : new URL('https://' + url)
    return u.hostname.replace(/^www\./, '')
  } catch { return String(url).replace(/^www\./, '').replace(/\/.*$/, '') }
}

export function adsTxtLine(publisherCode) {
  const host = process.env.ADS_TXT_HOST || 'mychannel.com'
  return `${host}, ${publisherCode}, DIRECT, ${process.env.ADS_TXT_TAGID || 'f1a2b3c4d5e6f7a8'}`
}

async function verifyAdsTxt(domain, publisherCode) {
  const candidates = [`https://${domain}/ads.txt`, `https://www.${domain}/ads.txt`]
  for (const url of candidates) {
    try {
      const res = await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(4000) })
      if (!res.ok) continue
      const text = await res.text()
      if (text.toLowerCase().includes(publisherCode.toLowerCase())) return true
    } catch { /* try next */ }
  }
  return false
}

// The embeddable ad code — the MyChannel equivalent of the AdSense snippet.
export function adCode(publisherCode, unit) {
  const host = process.env.ADS_TAG_HOST || 'https://cdn.mychannel.com'
  if (unit.sizing === 'auto' || unit.format === 'auto') {
    return `<script async src="${host}/mca.js?client=${publisherCode}" crossorigin="anonymous"></script>
<ins class="adsbymychannel"
     style="display:block"
     data-mca-client="${publisherCode}"
     data-mca-slot="${unit.slot_id}"
     data-mca-format="${unit.format === 'auto' ? 'auto' : unit.format}"
     data-full-width-responsive="${unit.full_width_responsive ? 'true' : 'false'}"></ins>
<script>(adsbymychannel = window.adsbymychannel || []).push({});</script>`
  }
  return `<script async src="${host}/mca.js?client=${publisherCode}" crossorigin="anonymous"></script>
<ins class="adsbymychannel"
     style="display:inline-block;width:${unit.width}px;height:${unit.height}px"
     data-mca-client="${publisherCode}"
     data-mca-slot="${unit.slot_id}"></ins>
<script>(adsbymychannel = window.adsbymychannel || []).push({});</script>`
}

function scrub(p) {
  const { api_key, ...rest } = p
  return { ...rest, apiKeyPreview: api_key ? api_key.slice(0, 12) + '…' : null }
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
