import { query } from '../lib/db.js'

// Recomputes dynamic floors by geo/device/placement using last 3 days eCPM
export async function recomputeFloors({ lookbackDays = 3 } = {}) {
  const { rows } = await query(`
    with agg as (
      select coalesce(ar.locale,'en-US') as locale,
             coalesce(ar.device,'ios') as device,
             coalesce(ar.placement,'preroll') as placement,
             percentile_disc(0.4) within group (order by coalesce(ai.price_cpm_cents,0)) as p40
      from ad_requests ar
      left join ad_impressions ai on ai.request_id = ar.id
      where ar.ts > now() - interval '${lookbackDays} days'
      group by 1,2,3
    )
    select split_part(locale,'-',2) as country, device, placement, p40 as floor
    from agg
  `)
  for (const r of rows) {
    await query(
      `insert into floors(country, device, placement, floor_cpm_cents, updated_at)
       values($1,$2,$3,$4, now())
       on conflict (country, device, placement) do update set floor_cpm_cents=excluded.floor_cpm_cents, updated_at=now()`,
      [r.country||null, r.device, r.placement, Number(r.floor)||0]
    )
  }
  return { updated: rows.length }
}


