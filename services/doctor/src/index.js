import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import { fetch } from 'undici'
import pkg from 'pg'
const { Pool } = pkg

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 200, timeWindow: '1 minute' })
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

app.get('/health', async () => ({ status: 'ok' }))

app.get('/doctor/synthetics', async () => {
  // ping a few critical endpoints via gateway
  const base = process.env.GATEWAY_URL || 'http://gateway:8088'
  const checks = ['/health','/boost/health','/pay/health','/mind/health','/ads/health'].map(async p => {
    try {
      const res = await fetch(base + p, { method: 'GET' })
      return { path: p, ok: res.ok, status: res.status }
    } catch (e) { return { path: p, ok: false, error: String(e) } }
  })
  return { results: await Promise.all(checks) }
})

const port = process.env.PORT || 9099
app.listen({ port, host: '0.0.0.0' })


