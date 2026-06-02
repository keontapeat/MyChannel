import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import registerServe from './routes/serve.js'
import registerAdvertiser from './routes/advertiser.js'
import registerOpenRTB from './routes/openrtb.js'
import registerPublisher from './routes/publisher.js'
import registerPubServe from './routes/pubserve.js'
import registerPubReports from './routes/pubreports.js'
import registerPubPayments, { issuePayout } from './routes/pubpayments.js'
import registerPubPolicy from './routes/pubpolicy.js'
import registerTag from './routes/tag.js'
import registerWebhooks from './routes/webhooks.js'
import { recomputeFloors } from './jobs/floors.js'
import { runNightlySettlement } from './jobs/settlements.js'
import { runMonthlyPayouts } from './jobs/payouts.js'

const app = Fastify({ logger: true, trustProxy: true })
await app.register(cors)
// allow inline ad markup + cross-origin tag embedding
await app.register(helmet, { contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } })
await app.register(rate, { max: 600, timeWindow: '1 minute' })

app.get('/health', async () => ({ status: 'ok', service: 'mychannel-ads', parity: 'adsense' }))

// Demand side (advertisers / programmatic video) — existing
await registerServe(app)
await registerAdvertiser(app)
await registerOpenRTB(app)

// Supply side (publishers / AdSense parity) — new
await registerPublisher(app)
await registerPubServe(app)
await registerPubReports(app)
await registerPubPayments(app)
await registerPubPolicy(app)
await registerTag(app)
await registerWebhooks(app)

const port = process.env.PORT || 9093
app.listen({ port, host: '0.0.0.0' })

// Daily maintenance
const dayMs = 24 * 60 * 60 * 1000
setInterval(async () => {
  try { await recomputeFloors(); app.log.info('floors recomputed') } catch (e) { app.log.error(e) }
  try { await runNightlySettlement() } catch (e) { app.log.error(e) }
  // Issue payouts on the 21st (AdSense pays ~21st of the month).
  if (new Date().getUTCDate() === 21) {
    try { const r = await runMonthlyPayouts(issuePayout); app.log.info({ payouts: r }, 'monthly payouts issued') }
    catch (e) { app.log.error(e) }
  }
}, dayMs)

export { app }
