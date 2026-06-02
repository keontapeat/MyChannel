import { query } from './db.js'

/**
 * Books revenue into the publisher ledger + daily rollup, applying the
 * publisher revenue share (default 68%, AdSense content standard).
 */
export async function bookRevenue({ publisherId, grossCents, source = 'earning', ref = null, meta = {} }) {
  const { rows: pubRows } = await query('select revshare_bps from publishers where id=$1', [publisherId])
  const bps = pubRows[0]?.revshare_bps ?? 6800
  const pubCents = Math.round((Number(grossCents) || 0) * bps / 10000)
  const platformCents = (Number(grossCents) || 0) - pubCents

  // Ledger with running balance.
  const { rows: balRows } = await query(
    `select coalesce(balance_after_cents,0) bal from pub_ledger where publisher_id=$1 order by id desc limit 1`,
    [publisherId]
  )
  const prev = Number(balRows[0]?.bal || 0)
  const balanceAfter = prev + pubCents
  await query(
    `insert into pub_ledger(publisher_id, entry_type, amount_cents, balance_after_cents, ref, meta)
     values($1,$2,$3,$4,$5,$6)`,
    [publisherId, source, pubCents, balanceAfter, ref, meta]
  )
  return { pubCents, platformCents, balanceAfter }
}

// Reverse a previously-booked amount (used when a click is flagged as invalid).
export async function reverseRevenue({ publisherId, pubCents, ref = null }) {
  const { rows: balRows } = await query(
    `select coalesce(balance_after_cents,0) bal from pub_ledger where publisher_id=$1 order by id desc limit 1`,
    [publisherId]
  )
  const prev = Number(balRows[0]?.bal || 0)
  const balanceAfter = prev - (Number(pubCents) || 0)
  await query(
    `insert into pub_ledger(publisher_id, entry_type, amount_cents, balance_after_cents, ref, meta)
     values($1,'invalid_reversal',$2,$3,$4,'{}'::jsonb)`,
    [publisherId, -(Number(pubCents) || 0), balanceAfter, ref]
  )
  return { balanceAfter }
}

export async function currentBalanceCents(publisherId) {
  const { rows } = await query(
    `select coalesce(balance_after_cents,0) bal from pub_ledger where publisher_id=$1 order by id desc limit 1`,
    [publisherId]
  )
  return Number(rows[0]?.bal || 0)
}
