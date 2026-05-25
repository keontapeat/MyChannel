import { buildServer } from './index.js'

async function main() {
  const app = buildServer()
  const port = Number(process.env.PORT || 9097)
  try {
    await app.listen({ port, host: '0.0.0.0' })
    await app.ready()
    app.log.info(`Ingest API listening on ${port}`)
    app.log.info('\n' + (app as any).printRoutes?.() )
  } catch (err) {
    app.log.error(err)
    process.exit(1)
  }
}

main()


