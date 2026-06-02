/**
 * MyChannel Ads — Invalid Traffic (IVT) detection
 *
 * AdSense protects advertisers by filtering invalid clicks/impressions
 * (bots, click spam, self-clicks). This is a lightweight rules + velocity engine.
 * It returns a score 0..1 (higher = more likely invalid) and a reason.
 */
import { query } from './db.js'

const BOT_UA = /(bot|crawl|spider|slurp|headless|phantom|puppeteer|selenium|curl|wget|python-requests)/i

export async function scoreClick({ publisherId, adUnitId, ipHash, ua = '', impressionId }) {
  let score = 0
  const reasons = []

  if (BOT_UA.test(ua)) { score += 0.6; reasons.push('bot_user_agent') }
  if (!ua) { score += 0.2; reasons.push('empty_user_agent') }

  // Click velocity from same IP on this publisher in the last hour.
  const { rows: v } = await query(
    `select count(*)::int c from pub_clicks
       where publisher_id=$1 and ip_hash=$2 and ts > now() - interval '1 hour'`,
    [publisherId, ipHash]
  )
  const recent = v[0]?.c || 0
  if (recent >= 3) { score += 0.3; reasons.push('ip_click_velocity') }
  if (recent >= 8) { score += 0.4; reasons.push('ip_click_flood') }

  // Double-click guard: same impression clicked more than once.
  if (impressionId) {
    const { rows: d } = await query(
      `select count(*)::int c from pub_clicks where impression_id=$1`, [impressionId]
    )
    if ((d[0]?.c || 0) >= 1) { score += 0.5; reasons.push('duplicate_click') }
  }

  score = Math.min(1, score)
  return { score, invalid: score >= 0.5, reasons }
}

export async function scoreRequest({ ua = '', ipHash, publisherId }) {
  let score = 0
  const reasons = []
  if (BOT_UA.test(ua)) { score += 0.7; reasons.push('bot_user_agent') }

  const { rows: v } = await query(
    `select count(*)::int c from pub_ad_requests
       where publisher_id=$1 and ip_hash=$2 and ts > now() - interval '1 minute'`,
    [publisherId, ipHash]
  )
  if ((v[0]?.c || 0) > 60) { score += 0.5; reasons.push('request_flood') }

  score = Math.min(1, score)
  return { score, invalid: score >= 0.5, reasons }
}
