import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import pkg from 'pg'
const { Pool } = pkg

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 200, timeWindow: '1 minute' })
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

app.get('/health', async () => ({ status: 'ok' }))
app.get('/iq/creator/summary', async (req) => {
  const { userId } = req.query
  const { rows } = await pool.query('select * from creator_metrics_daily where user_id=$1 order by date desc limit 30', [userId])
  return { data: rows }
})

const port = process.env.PORT || 9092
app.listen({ port, host: '0.0.0.0' })



