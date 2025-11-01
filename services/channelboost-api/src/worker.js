import { Queue, Worker, QueueScheduler, JobsOptions } from 'bullmq'
import IORedis from 'ioredis'
import pkg from 'pg'
const { Pool } = pkg

const connection = new IORedis(process.env.REDIS_URL || 'redis://127.0.0.1:6379/0')
const queueName = 'channelboost-jobs'
const queue = new Queue(queueName, { connection })
const scheduler = new QueueScheduler(queueName, { connection })

const pool = new Pool({ connectionString: process.env.DATABASE_URL })

async function rotateKeywordsJob(locale = 'en-US') {
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
  await pool.query('insert into keyword_set(locale_code, slot, terms, live_from) values($1,$2,$3, now())', [locale, 'keywords', terms])
}

async function aggregateMetricsJob() {
  // naive rollup example from install_events
  await pool.query(`
    insert into metrics_daily(date, locale_code, installs)
    select date_trunc('day', created_at)::date as date, locale_code, count(*)
    from install_events
    where created_at >= now() - interval '7 days'
    group by 1,2
    on conflict (date) do nothing
  `)
}

new Worker(queueName, async job => {
  switch (job.name) {
    case 'keyword-rotate':
      await rotateKeywordsJob(job.data?.locale || 'en-US')
      return { ok: true }
    case 'aggregate-metrics':
      await aggregateMetricsJob()
      return { ok: true }
    default:
      return { ok: true }
  }
}, { connection })

// Enqueue schedules if not already present
;(async () => {
  // hourly keyword rotation (example)
  await queue.add('keyword-rotate', { locale: 'en-US' }, { repeat: { every: 60 * 60 * 1000 } })
  // nightly metrics aggregation
  await queue.add('aggregate-metrics', {}, { repeat: { cron: '0 3 * * *' } })
  console.log('Worker started with schedules.')
})().catch(e=>{ console.error(e); process.exit(1) })



