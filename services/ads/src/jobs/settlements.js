import { query } from '../lib/db.js'

export async function runNightlySettlement({ from, to, payApiBase = process.env.PAY_API_BASE_URL || 'http://pay-api:8888' } = {}) {
  // Aggregate revenue by creator from ad_impressions joined with videos (assumed mapping via video_id->creator_id stored in an external map or passed)
  // For now, treat revenue_cents column as already computed per impression; group by video_id as proxy for creator
  const { rows } = await query("select coalesce(video_id,'unknown') as creator_id, sum(coalesce(revenue_cents,0)) as revenue_cents from ad_impressions where ts between coalesce($1,'epoch'::timestamptz) and coalesce($2, now()) group by 1", [from, to])
  for (const r of rows) {
    const body = { creatorId: r.creator_id, amountCents: Number(r.revenue_cents)||0, currency: 'usd', reference: 'ads_settlement' }
    try {
      await fetch(`${payApiBase}/pay/settlement`, { method:'POST', headers: { 'content-type':'application/json' }, body: JSON.stringify(body) })
      await query('insert into settlements(date, creator_id, revenue_cents, details_json, status) values(current_date, $1, $2, $3, \"posted\")',[r.creator_id, body.amountCents, body])
    } catch (e) {
      await query('insert into settlements(date, creator_id, revenue_cents, details_json, status) values(current_date, $1, $2, $3, \"error\")',[r.creator_id, body.amountCents, { error: String(e) }])
    }
  }
}



