import { query } from '../lib/db.js'
import { currentBalanceCents } from '../lib/earnings.js'

/**
 * Publisher reporting — the AdSense "Reports" + "Home" cards.
 * Metrics: estimated earnings, page views, impressions, clicks, CTR, CPC, RPM.
 */
export default async function registerPubReportRoutes(app) {
  // Headline cards: today, yesterday, last 7 days, this month, balance.
  app.get('/pub/reports/overview', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })

    const ranges = {
      today: "ts::date = current_date",
      yesterday: "ts::date = current_date - 1",
      last7: "ts > now() - interval '7 days'",
      thisMonth: "date_trunc('month', ts) = date_trunc('month', now())",
    }
    const out = {}
    for (const [k, where] of Object.entries(ranges)) out[k] = await metricsFor(pub.id, where)

    const balanceCents = await currentBalanceCents(pub.id)
    const { rows: pr } = await query('select payment_threshold_cents from publishers where id=$1', [pub.id])
    const threshold = pr[0]?.payment_threshold_cents || 10000
    return {
      ...out,
      balance: {
        currentCents: balanceCents,
        thresholdCents: threshold,
        eligibleForPayout: balanceCents >= threshold,
        amountToThresholdCents: Math.max(0, threshold - balanceCents),
      },
    }
  })

  // Time series for charting (group by day).
  app.get('/pub/reports/timeseries', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const days = Math.min(365, Number(req.query.days) || 30)
    const { rows } = await query(
      `select d::date as day,
              coalesce(i.imps,0) impressions,
              coalesce(i.clicks,0) clicks,
              coalesce(i.earnings_cents,0) earnings_cents,
              coalesce(r.reqs,0) ad_requests
         from generate_series(current_date - ($1::int - 1), current_date, interval '1 day') d
         left join (
            select ts::date day, count(*) imps,
                   sum(pub_cents) earnings_cents,
                   (select count(*) from pub_clicks c where c.publisher_id=$2 and c.ts::date=pi.ts::date and not c.invalid) clicks
              from pub_impressions pi where publisher_id=$2 group by ts::date
         ) i on i.day = d::date
         left join (
            select ts::date day, count(*) reqs from pub_ad_requests where publisher_id=$2 group by ts::date
         ) r on r.day = d::date
        order by day`,
      [days, pub.id]
    )
    return { series: rows.map(row => ({
      day: row.day,
      impressions: Number(row.impressions),
      clicks: Number(row.clicks),
      adRequests: Number(row.ad_requests),
      earningsCents: Number(row.earnings_cents),
      ctr: row.impressions > 0 ? Number(row.clicks) / Number(row.impressions) : 0,
      impRpmCents: row.impressions > 0 ? (Number(row.earnings_cents) / Number(row.impressions)) * 1000 : 0,
    })) }
  })

  // Breakdown by dimension: 'ad_unit' | 'site' | 'country'.
  app.get('/pub/reports/breakdown', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const dim = req.query.dim || 'ad_unit'
    const col = { ad_unit: 'pi.ad_unit_id', site: 'r.site_id', country: 'r.country' }[dim] || 'pi.ad_unit_id'
    const { rows } = await query(
      `select ${col} as key,
              count(pi.id) impressions,
              sum(pi.pub_cents) earnings_cents,
              (select count(*) from pub_clicks c where c.publisher_id=$1 and not c.invalid) as clicks
         from pub_impressions pi
         join pub_ad_requests r on r.id = pi.request_id
        where pi.publisher_id=$1 and pi.ts > now() - interval '30 days'
        group by ${col} order by earnings_cents desc nulls last limit 100`,
      [pub.id]
    )
    return { dimension: dim, rows }
  })

  async function metricsFor(publisherId, where) {
    const { rows: imp } = await query(
      `select count(*)::int impressions, coalesce(sum(pub_cents),0) earnings_cents
         from pub_impressions where publisher_id=$1 and ${where}`, [publisherId]
    )
    const { rows: req } = await query(
      `select count(*)::int reqs, sum(case when filled then 1 else 0 end)::int matched
         from pub_ad_requests where publisher_id=$1 and ${where}`, [publisherId]
    )
    const { rows: clk } = await query(
      `select count(*)::int clicks from pub_clicks where publisher_id=$1 and not invalid and ${where}`, [publisherId]
    )
    const impressions = imp[0].impressions
    const clicks = clk[0].clicks
    const earnings = Number(imp[0].earnings_cents)
    const reqs = req[0].reqs
    return {
      adRequests: reqs,
      matchedRequests: req[0].matched,
      coverage: reqs ? req[0].matched / reqs : 0,
      impressions,
      clicks,
      earningsCents: earnings,
      ctr: impressions ? clicks / impressions : 0,
      cpcCents: clicks ? earnings / clicks : 0,
      impRpmCents: impressions ? (earnings / impressions) * 1000 : 0,
      pageRpmCents: reqs ? (earnings / reqs) * 1000 : 0,
    }
  }
}

async function resolvePublisher(req) {
  const code = req.headers['x-mca-client'] || req.query.client
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
