import { FastifyReply, FastifyRequest } from 'fastify'
import { attributionHtml, attributionText } from '../../../packages/license-kits/index.js'
import admin from 'firebase-admin'
import jwt from 'jsonwebtoken'

if (!admin.apps.length) {
  admin.initializeApp()
}

const db = admin.firestore()
const JWT_SECRET = process.env.JWT_SECRET || ''

async function verifyUser(authHeader: string | undefined) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null
  const token = authHeader.slice(7).trim()
  if (!token) return null

  try {
    const decoded = await admin.auth().verifyIdToken(token)
    return {
      userId: decoded.uid,
      email: decoded.email || null,
      username: decoded.name || (decoded.email ? decoded.email.split('@')[0] : null)
    }
  } catch {}

  if (!JWT_SECRET) return null

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any
    const userId = String(decoded.userId || decoded.uid || '').trim()
    if (!userId) return null
    return {
      userId,
      email: decoded.email || null,
      username: decoded.username || null
    }
  } catch {
    return null
  }
}

async function requireUser(req: FastifyRequest, rep: FastifyReply) {
  const user = await verifyUser(req.headers.authorization as string)
  if (!user) {
    rep.code(401).send({ error: 'Unauthorized' })
    return null
  }
  return user
}

export async function getVideoRights(req: FastifyRequest<{ Params: { videoId: string } }>, rep: FastifyReply) {
  try {
    const { videoId } = req.params

    const videoSnap = await db.collection('videos').doc(videoId).get()
    if (!videoSnap.exists) {
      return rep.code(404).send({ error: 'Video not found' })
    }

    const videoData = videoSnap.data()!
    const licenseCode = (videoData.licenseCode || 'CC0') as 'CC0' | 'PD' | 'CC_BY'
    const author = videoData.ownerId || 'Unknown'
    const source = videoData.source || 'MyChannel'

    rep.send({
      videoId,
      license_code: licenseCode,
      license_url: getLicenseUrl(licenseCode),
      attribution_text: attributionText(licenseCode, { author, source }),
      attribution_html: attributionHtml(licenseCode, { author, source }),
      proof_html_uri: videoData.proofHtmlUri || '',
      proof_screenshot_uri: videoData.proofScreenshotUri || '',
      monetizable: isMonetizable(licenseCode)
    })
  } catch (error) {
    console.error('Get video rights error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function exportProof(req: FastifyRequest<{ Params: { videoId: string } }>, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const { videoId } = req.params

    const videoSnap = await db.collection('videos').doc(videoId).get()
    if (!videoSnap.exists) {
      return rep.code(404).send({ error: 'Video not found' })
    }

    const videoData = videoSnap.data()!
    if (String(videoData.ownerId || '') !== user.userId) {
      return rep.code(403).send({ error: 'Forbidden' })
    }

    const licenseCode = (videoData.licenseCode || 'CC0') as 'CC0' | 'PD' | 'CC_BY'
    const author = videoData.ownerId || 'Unknown'
    const source = videoData.source || 'MyChannel'

    const attribution = {
      text: attributionText(licenseCode, { author, source }),
      html: attributionHtml(licenseCode, { author, source })
    }

    rep.send({
      videoId,
      license_code: licenseCode,
      license_url: getLicenseUrl(licenseCode),
      attribution,
      exported_at: new Date().toISOString()
    })
  } catch (error) {
    console.error('Export proof error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function attributionPreview(req: FastifyRequest<{ Body: { code: 'CC0'|'PD'|'CC_BY', author?: string, source?: string, licenseUrl?: string, version?: string } }>, rep: FastifyReply) {
  try {
    const b = req.body
    rep.send({ text: attributionText(b.code, b), html: attributionHtml(b.code, b) })
  } catch (error) {
    console.error('Attribution preview error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function policySummary(req: FastifyRequest, rep: FastifyReply) {
  try {
    rep.send({
      allowed: ['CC0', 'PD', 'CC_BY', 'CC_BY_SA', 'CC_BY_ND', 'CC_BY_NC'],
      monetizable: ['CC0', 'PD', 'CC_BY'],
      non_monetizable: ['CC_BY_NC', 'CC_BY_ND', 'CC_BY_SA'],
      examples: [
        { code: 'CC0', description: 'Public domain - no attribution required, fully monetizable' },
        { code: 'CC_BY', description: 'Requires attribution, monetizable' },
        { code: 'CC_BY_NC', description: 'Non-commercial only, not monetizable' }
      ]
    })
  } catch (error) {
    console.error('Policy summary error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function updateVideoRights(req: FastifyRequest<{ Params: { videoId: string }, Body: { licenseCode?: string, source?: string, proofHtmlUri?: string, proofScreenshotUri?: string } }>, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const { videoId } = req.params
    const { licenseCode, source, proofHtmlUri, proofScreenshotUri } = req.body || {}

    const videoRef = db.collection('videos').doc(videoId)
    const videoSnap = await videoRef.get()

    if (!videoSnap.exists) {
      return rep.code(404).send({ error: 'Video not found' })
    }

    if (String(videoSnap.data()!.ownerId || '') !== user.userId) {
      return rep.code(403).send({ error: 'Forbidden' })
    }

    const patch: Record<string, any> = { updatedAt: admin.firestore.Timestamp.now() }
    if (licenseCode) patch.licenseCode = licenseCode
    if (source !== undefined) patch.source = source
    if (proofHtmlUri !== undefined) patch.proofHtmlUri = proofHtmlUri
    if (proofScreenshotUri !== undefined) patch.proofScreenshotUri = proofScreenshotUri

    await videoRef.set(patch, { merge: true })

    const updatedSnap = await videoRef.get()
    const updatedData = updatedSnap.data()!

    rep.send({
      videoId,
      license_code: updatedData.licenseCode || 'CC0',
      license_url: getLicenseUrl(updatedData.licenseCode || 'CC0'),
      source: updatedData.source || null,
      proof_html_uri: updatedData.proofHtmlUri || null,
      proof_screenshot_uri: updatedData.proofScreenshotUri || null,
      monetizable: isMonetizable(updatedData.licenseCode || 'CC0')
    })
  } catch (error) {
    console.error('Update video rights error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

function getLicenseUrl(code: string): string {
  const urls: Record<string, string> = {
    'CC0': 'https://creativecommons.org/publicdomain/zero/1.0/',
    'PD': 'https://creativecommons.org/publicdomain/mark/1.0/',
    'CC_BY': 'https://creativecommons.org/licenses/by/4.0/',
    'CC_BY_SA': 'https://creativecommons.org/licenses/by-sa/4.0/',
    'CC_BY_ND': 'https://creativecommons.org/licenses/by-nd/4.0/',
    'CC_BY_NC': 'https://creativecommons.org/licenses/by-nc/4.0/'
  }
  return urls[code] || 'https://creativecommons.org/'
}

function isMonetizable(code: string): boolean {
  return ['CC0', 'PD', 'CC_BY'].includes(code)
}



