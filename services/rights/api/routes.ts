import { FastifyReply, FastifyRequest } from 'fastify'
import { attributionHtml, attributionText } from '../../../packages/license-kits/index'

export async function getVideoRights(req: FastifyRequest<{ Params: { videoId: string } }>, rep: FastifyReply) {
  const { videoId } = req.params
  // TODO: fetch from DB; mocked for now
  rep.send({ videoId, license_code: 'CC0', license_url: 'https://creativecommons.org/publicdomain/zero/1.0/', attribution_text: attributionText('CC0', { author: 'Author', source: 'Pexels' }), attribution_html: attributionHtml('CC0', { author: 'Author', source: 'Pexels' }), proof_html_uri: '', proof_screenshot_uri: '', monetizable: true })
}

export async function exportProof(req: FastifyRequest, rep: FastifyReply) {
  // TODO: stream zip bundle; mocked
  rep.header('content-type', 'application/zip').send(Buffer.from(''))
}

export async function attributionPreview(req: FastifyRequest<{ Body: { code: 'CC0'|'PD'|'CC_BY', author?: string, source?: string, licenseUrl?: string, version?: string } }>, rep: FastifyReply) {
  const b = req.body
  rep.send({ text: attributionText(b.code, b), html: attributionHtml(b.code, b) })
}

export async function policySummary(req: FastifyRequest, rep: FastifyReply) {
  rep.send({ allowed: ['CC0','PD','CC_BY'], examples: ['CC BY 4.0 requires attribution'] })
}



