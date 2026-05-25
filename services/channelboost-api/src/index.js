import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import archiver from 'archiver'
import pkg from 'pg'
const { Pool } = pkg

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 100, timeWindow: '1 minute' })

const pool = new Pool({ connectionString: process.env.DATABASE_URL })

function auth(req, reply, done) {
  const token = process.env.CB_API_TOKEN || ''
  const h = req.headers['authorization'] || ''
  if (!token || !h.startsWith('Bearer ') || h.slice(7) !== token) {
    return reply.code(401).send({ error: 'unauthorized' })
  }
  done()
}

app.get('/health', async () => ({ status: 'ok' }))

app.get('/aso/locales', async () => ({ locales: ['en-US','es-ES','pt-BR','fr-FR','de-DE','it-IT','hi-IN','id-ID','ar','ja-JP','ko-KR','zh-CN'] }))

app.get('/aso/metadata', async (req, reply) => {
  const { locale = 'en-US' } = req.query
  const { rows } = await pool.query('select * from metadata_versions where locale_code=$1 and status=$2 order by created_at desc limit 1', [locale, 'live'])
  return rows[0] || {}
})

app.post('/aso/metadata', { preHandler: auth }, async (req, reply) => {
  const { locale, name, subtitle, description, keywords, promo_text } = req.body || {}
  const { rows } = await pool.query('insert into metadata_versions(locale_code,name,subtitle,description,keywords,promo_text,status) values($1,$2,$3,$4,$5,$6,$7) returning *', [locale,name,subtitle,description,keywords,promo_text,'draft'])
  return rows[0]
})

app.post('/aso/publish', { preHandler: auth }, async (req, reply) => {
  const { id } = req.body
  await pool.query('update metadata_versions set status=$1 where id=$2', ['live', id])
  return { ok: true }
})

app.post('/events/install', async (req, reply) => {
  const { platform, locale, source, campaign, referral } = req.body || {}
  await pool.query('insert into install_events(platform, locale_code, source, campaign, referred_by_code) values($1,$2,$3,$4,$5)', [platform, locale, source, campaign, referral||null])
  return { ok: true }
})

app.get('/metrics/summary', async (req, reply) => {
  const { rows } = await pool.query('select * from metrics_daily order by date desc limit 30')
  return { data: rows }
})

// Referral creation
app.get('/referral/create', { preHandler: auth }, async (req, reply) => {
  const { user_id, source = 'app', campaign = '' } = req.query
  const code = Math.random().toString(36).slice(2, 8).toUpperCase()
  await pool.query('insert into referral_code(code, creator_user_id, source, campaign) values($1,$2,$3,$4)', [code, user_id||null, source, campaign||null])
  const base = process.env.REFERRAL_BASE || 'https://mychannel.live/r/'
  return { code, url: base + code }
})

// Referral landing click tracker
app.get('/r/:code', async (req, reply) => {
  const { code } = req.params
  const ua = req.headers['user-agent'] || ''
  const ip = req.headers['x-forwarded-for'] || req.ip
  await pool.query('insert into referral_clicks(code, user_agent, ip) values($1,$2,$3)', [code, ua, typeof ip === 'string' ? ip : (ip||'')])
  // Redirect to store / app site
  const dest = process.env.STORE_URL || 'https://apps.apple.com/app/id0000000000'
  reply.redirect(dest)
})

// Funnel
app.post('/events/funnel', async (req, reply) => {
  const { user_id, step } = req.body || {}
  await pool.query('insert into funnel_events(user_id, step) values($1,$2)', [user_id, step])
  return { ok: true }
})

// Reviews eligibility
app.post('/reviews/eligible', async (req, reply) => {
  const { user_id } = req.body || {}
  // cooldown: 90 days
  const { rows } = await pool.query('select last_prompt_at from review_prompt_log where user_id=$1 order by last_prompt_at desc limit 1', [user_id])
  if (rows[0]) {
    const last = new Date(rows[0].last_prompt_at)
    const diff = Date.now() - last.getTime()
    const days = diff / (1000*60*60*24)
    if (days < 90) return { eligible: false, reason: 'cooldown' }
  }
  // TODO: add positive-signal checks; return true for now
  return { eligible: true }
})

// Reviews log
app.post('/reviews/log', async (req, reply) => {
  const { user_id, device_hash, outcome } = req.body || {}
  await pool.query('insert into review_prompt_log(user_id, device_hash, last_prompt_at, outcome) values($1,$2, now(), $3)', [user_id||null, device_hash||null, outcome||null])
  return { ok: true }
})

// Keywords rotate (simple heuristic)
app.post('/keywords/rotate', { preHandler: auth }, async (req, reply) => {
  const { locale = 'en-US', slot = 'keywords' } = req.query
  const { rows } = await pool.query('select term, difficulty, volume from keyword_bank where locale_code=$1 and status=$2', [locale, 'active'])
  const scored = rows
    .map(r => ({ term: r.term, score: (r.volume||50) - (r.difficulty||50) }))
    .sort((a,b)=>b.score-a.score)
  const terms = []
  let used = 0
  for (const k of scored) {
    if ((used + k.term.length + (terms.length?1:0)) > 100) continue
    terms.push(k.term)
    used += k.term.length + (terms.length?1:0)
  }
  const { rows: ins } = await pool.query('insert into keyword_set(locale_code, slot, terms, live_from) values($1,$2,$3, now()) returning *', [locale, slot, terms])
  return ins[0]
})

// ASO export zip (JSON per locale)
app.post('/aso/export', { preHandler: auth }, async (req, reply) => {
  const { platform = 'ios' } = req.body || {}
  const { rows } = await pool.query("select locale_code,name,subtitle,description,keywords,promo_text from metadata_versions where status='live'")
  reply.header('Content-Type', 'application/zip')
  reply.header('Content-Disposition', 'attachment; filename="aso_export.zip"')
  const archive = archiver('zip', { zlib: { level: 9 } })
  archive.on('error', err => reply.raw.destroy(err))
  archive.pipe(reply.raw)
  for (const r of rows) {
    const obj = {
      platform,
      locale: r.locale_code,
      name: r.name,
      subtitle: r.subtitle,
      description: r.description,
      keywords: r.keywords,
      promo_text: r.promo_text
    }
    archive.append(JSON.stringify(obj, null, 2), { name: `${platform}_${r.locale_code}.json` })
  }
  archive.finalize()
})

const port = process.env.PORT || 8787
app.listen({ port, host: '0.0.0.0' })

