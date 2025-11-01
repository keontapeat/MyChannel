import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import pkg from 'pg'
const { Pool } = pkg

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 300, timeWindow: '1 minute' })
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

app.get('/health', async () => ({ status: 'ok' }))

app.post('/rewards/earn', async (req) => {
  const { userId, reason, amount = 1 } = req.body || {}
  await pool.query('insert into reward_ledger(user_id, delta_points, reason) values($1,$2,$3)', [userId, amount, reason])
  await pool.query('insert into reward_balances(user_id, points, updated_at) values($1,$2, now()) on conflict (user_id) do update set points=reward_balances.points+$2, updated_at=now()', [userId, amount])
  return { ok: true }
})

const port = process.env.PORT || 9094
app.listen({ port, host: '0.0.0.0' })



