import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 200, timeWindow: '1 minute' })

app.get('/health', async () => ({ status: 'ok' }))

app.post('/labs/scriptwriter', async (req) => {
  const { topic, duration, tone } = req.body || {}
  return { outline: ["Intro", "Key points", "Outro"], script: `Topic: ${topic}` }
})

const port = process.env.PORT || 9096
app.listen({ port, host: '0.0.0.0' })



