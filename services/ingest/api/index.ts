import Fastify from 'fastify'
import { pullSourceHandler, ingestAssetHandler, statusHandler, reviewMonetizableHandler, snapshotProofHandler, metricsDailyHandler } from './routes.js'

export function buildServer() {
  const app = Fastify({ logger: true })
  app.post('/ingest/source/pull', pullSourceHandler)
  app.post('/ingest/asset/:id/ingest', ingestAssetHandler)
  app.get('/ingest/status', statusHandler)
  app.post('/ingest/review/:videoId/monetizable', reviewMonetizableHandler)
  app.post('/ingest/proof/snapshot', snapshotProofHandler)
  app.get('/ingest/metrics/daily', metricsDailyHandler)
  return app
}
 

