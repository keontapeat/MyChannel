import { FastifyRequest, FastifyReply } from 'fastify'
import { getAdapter, SourceCode } from '../lib/adapters'

export async function pullSourceHandler(req: FastifyRequest<{ Body: { source: 'PEXELS'|'PIXABAY'|'ARCHIVE'|'WIKI', query?: string, perPage?: number, pages?: number } }>, rep: FastifyReply) {
  const body = req.body
  const adapter = getAdapter(body.source as SourceCode)
  const page = 1
  const results = await adapter.search({ query: body.query, perPage: body.perPage ?? 5, page })
  // TODO: enqueue each result for download/transform; return asset ids (mock)
  rep.send({ ok: true, count: results.length, assets: results.slice(0,5) })
}

export async function ingestAssetHandler(req: FastifyRequest<{ Params: { id: string } }>, rep: FastifyReply) {
  const { id } = req.params
  // TODO: enqueue single asset pipeline
  rep.send({ ok: true, assetId: id })
}

export async function statusHandler(req: FastifyRequest, rep: FastifyReply) {
  // TODO: return recent job summaries (mock)
  rep.send({ jobs: [] })
}

export async function reviewMonetizableHandler(req: FastifyRequest<{ Params: { videoId: string }, Body: { value: boolean, reason?: string } }>, rep: FastifyReply) {
  // TODO: write rights_audit + flip videos.monetizable
  rep.send({ ok: true })
}

export async function snapshotProofHandler(req: FastifyRequest<{ Body: { sourceAssetId: string, html?: string, screenshot?: string } }>, rep: FastifyReply) {
  // TODO: store proof to GCS; mocked
  rep.send({ ok: true })
}

export async function metricsDailyHandler(req: FastifyRequest, rep: FastifyReply) {
  rep.send({ rows: [] })
}


