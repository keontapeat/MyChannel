import Fastify from 'fastify'
import { getVideoRights, exportProof, attributionPreview, policySummary } from './routes'

export function buildServer() {
  const app = Fastify({ logger: true })
  app.get('/rights/video/:videoId', getVideoRights)
  app.get('/rights/export/proof', exportProof)
  app.post('/rights/attribution/preview', attributionPreview)
  app.get('/rights/policy', policySummary)
  return app
}

if (require.main === module) {
  const app = buildServer()
  const port = Number(process.env.PORT || 9098)
  app.listen({ port, host: '0.0.0.0' }).then(()=>{
    app.log.info(`Rights API listening on ${port}`)
  })
}



