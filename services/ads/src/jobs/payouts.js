import { query } from '../lib/db.js'

/**
 * Monthly payout run. Iterates eligible publishers (balance >= threshold,
 * not on hold) and issues a payout for the previous month, mirroring the
 * AdSense ~21st-of-month payment cycle.
 */
export async function runMonthlyPayouts(issuePayout, { period } = {}) {
  const now = new Date()
  // default: previous month
  const prev = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1))
  const targetPeriod = period || prev.toISOString().slice(0, 7)

  const { rows } = await query(
    `select p.id, p.publisher_code, p.payment_threshold_cents,
            coalesce((select balance_after_cents from pub_ledger l where l.publisher_id=p.id order by id desc limit 1),0) bal
       from publishers p
      where p.status='approved' and p.hold_payments=false`
  )
  const results = []
  for (const p of rows) {
    if (Number(p.bal) < (p.payment_threshold_cents || 10000)) continue
    const r = await issuePayout(p.id, targetPeriod)
    results.push({ publisher: p.publisher_code, ...r })
  }
  return { period: targetPeriod, count: results.filter(r => r.ok).length, results }
}
