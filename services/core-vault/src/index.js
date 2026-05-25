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

app.post('/vault/graph/link', async (req) => {
  const { src, dst, relation, weight = 1.0 } = req.body || {}
  const { rows } = await pool.query('insert into edges(src_id,dst_id,relation,weight) values($1,$2,$3,$4) returning id', [src, dst, relation, weight])
  return { id: rows[0].id }
})

const port = process.env.PORT || 9097
app.listen({ port, host: '0.0.0.0' })



