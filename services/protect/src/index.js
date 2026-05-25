import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import pkg from 'pg'
const { Pool } = pkg

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 100, timeWindow: '1 minute' })
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

app.get('/health', async () => ({ status: 'ok' }))

app.post('/protect/fingerprint', async (req, reply) => {
  const { videoId, type } = req.body || {}
  // stub: accept and return deterministic hash
  const hash = `hash_${type||'video'}_${videoId}`
  await pool.query('insert into reference_fingerprint(hash, type) values($1,$2) on conflict do nothing', [hash, type||'video'])
  return { hash }
})

const port = process.env.PORT || 9091
app.listen({ port, host: '0.0.0.0' })



