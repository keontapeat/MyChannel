import { query } from '../lib/db.js'

/**
 * Policy Center — AdSense "Policy center": list violations, appeal, and
 * (admin) raise a violation. Affects ad serving when must-fix issues are open.
 */
export default async function registerPubPolicyRoutes(app) {
  app.get('/pub/policy', async (req, reply) => {
    const pub = await resolvePublisher(req)
    if (!pub) return reply.code(404).send({ error: 'publisher_not_found' })
    const { rows } = await query(
      'select * from pub_policy_violations where publisher_id=$1 order by detected_at desc',
      [pub.id]
    )
    const open = rows.filter(r => r.status === 'open')
    return {
      violations: rows,
      summary: {
        total: rows.length,
        open: open.length,
        mustFix: open.filter(r => r.severity === 'must-fix').length,
        warnings: open.filter(r => r.severity === 'warning').length,
      },
    }
  })

  // Admin raises a violation against a publisher/site/page.
  app.post('/pub/policy', async (req) => {
    const b = req.body || {}
    const { rows: pub } = await query('select id from publishers where publisher_code=$1', [b.client])
    if (!pub.length) return { ok: false, reason: 'publisher_not_found' }
    const { rows } = await query(
      `insert into pub_policy_violations(publisher_id, site_id, page_url, policy, severity, detail)
       values($1,$2,$3,$4,$5,$6) returning *`,
      [pub[0].id, b.siteId || null, b.pageUrl || null, b.policy, b.severity || 'must-fix', b.detail || null]
    )
    // Auto-hold serving on must-fix account-level violations.
    if ((b.severity || 'must-fix') === 'must-fix' && !b.pageUrl) {
      await query('update publishers set ad_serving_enabled=false where id=$1', [pub[0].id])
    }
    return { ok: true, violation: rows[0] }
  })

  app.post('/pub/policy/:id/appeal', async (req) => {
    await query("update pub_policy_violations set status='appealed' where id=$1", [req.params.id])
    return { ok: true }
  })

  // Admin resolves (and may re-enable serving if nothing else is open).
  app.post('/pub/policy/:id/resolve', async (req) => {
    const { rows } = await query(
      "update pub_policy_violations set status='resolved', resolved_at=now() where id=$1 returning publisher_id",
      [req.params.id]
    )
    if (rows.length) {
      const pubId = rows[0].publisher_id
      const { rows: open } = await query(
        "select count(*)::int c from pub_policy_violations where publisher_id=$1 and status='open' and severity='must-fix'",
        [pubId]
      )
      if ((open[0]?.c || 0) === 0) await query('update publishers set ad_serving_enabled=true where id=$1', [pubId])
    }
    return { ok: true }
  })
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
