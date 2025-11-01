import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import registerServe from './routes/serve.js'
import registerAdvertiser from './routes/advertiser.js'
import registerOpenRTB from './routes/openrtb.js'
import { recomputeFloors } from './jobs/floors.js'
import { runNightlySettlement } from './jobs/settlements.js'

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 300, timeWindow: '1 minute' })

app.get('/health', async () => ({ status: 'ok' }))

await registerServe(app)
await registerAdvertiser(app)
await registerOpenRTB(app)

const port = process.env.PORT || 9093
app.listen({ port, host: '0.0.0.0' })

// Nightly cron-like timers (simple in-process for dev)
const dayMs = 24 * 60 * 60 * 1000
setInterval(async () => {
  try { await recomputeFloors(); app.log.info('floors recomputed') } catch (e) { app.log.error(e) }
  try { await runNightlySettlement() } catch (e) { app.log.error(e) }
}, dayMs)


