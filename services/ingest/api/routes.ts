import { FastifyRequest, FastifyReply } from 'fastify'
import { getAdapter, SourceCode } from '../lib/adapters.js'
import admin from 'firebase-admin'
import jwt from 'jsonwebtoken'
import { Storage } from '@google-cloud/storage'

if (!admin.apps.length) {
  admin.initializeApp()
}

const db = admin.firestore()
const JWT_SECRET = process.env.JWT_SECRET || ''
const storage = new Storage()
const PROOF_BUCKET = process.env.PROOF_BUCKET || 'mychannel-proofs'

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

export async function pullSourceHandler(req: FastifyRequest<{ Body: { source: 'PEXELS'|'PIXABAY'|'ARCHIVE'|'WIKI', query?: string, perPage?: number, pages?: number } }>, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const body = req.body
    const adapter = getAdapter(body.source as SourceCode)
    const page = 1
    const results = await adapter.search({ query: body.query, perPage: body.perPage ?? 5, page })

    const jobRef = db.collection('ingest_jobs').doc()
    const now = admin.firestore.Timestamp.now()

    await jobRef.set({
      id: jobRef.id,
      userId: user.userId,
      source: body.source,
      query: body.query || '',
      status: 'pending',
      totalResults: results.length,
      createdAt: now,
      updatedAt: now
    })

    const assets = results.slice(0, 5).map((r: any, i: number) => ({
      assetId: `${jobRef.id}_${i}`,
      ...r
    }))

    rep.send({ ok: true, jobId: jobRef.id, count: results.length, assets })
  } catch (error) {
    console.error('Pull source error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function ingestAssetHandler(req: FastifyRequest<{ Params: { id: string } }>, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const { id } = req.params

    const jobRef = db.collection('ingest_jobs').doc(id)
    const jobSnap = await jobRef.get()

    if (!jobSnap.exists) {
      return rep.code(404).send({ error: 'Job not found' })
    }

    const jobData = jobSnap.data()!
    if (String(jobData.userId || '') !== user.userId) {
      return rep.code(403).send({ error: 'Forbidden' })
    }

    await jobRef.update({
      status: 'processing',
      updatedAt: admin.firestore.Timestamp.now()
    })

    rep.send({ ok: true, assetId: id, status: 'processing' })
  } catch (error) {
    console.error('Ingest asset error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function statusHandler(req: FastifyRequest, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const limit = 10
    const snap = await db.collection('ingest_jobs')
      .where('userId', '==', user.userId)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get()

    const jobs = snap.docs.map(doc => {
      const data = doc.data()
      return {
        id: doc.id,
        source: data.source,
        query: data.query,
        status: data.status,
        totalResults: data.totalResults || 0,
        createdAt: data.createdAt ? data.createdAt.toDate().toISOString() : null,
        updatedAt: data.updatedAt ? data.updatedAt.toDate().toISOString() : null
      }
    })

    rep.send({ jobs })
  } catch (error) {
    console.error('Status error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function reviewMonetizableHandler(req: FastifyRequest<{ Params: { videoId: string }, Body: { value: boolean, reason?: string } }>, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const { videoId } = req.params
    const { value, reason } = req.body || {}

    const videoRef = db.collection('videos').doc(videoId)
    const videoSnap = await videoRef.get()

    if (!videoSnap.exists) {
      return rep.code(404).send({ error: 'Video not found' })
    }

    const videoData = videoSnap.data()!
    if (String(videoData.ownerId || '') !== user.userId) {
      return rep.code(403).send({ error: 'Forbidden' })
    }

    const now = admin.firestore.Timestamp.now()

    await db.runTransaction(async tx => {
      tx.set(db.collection('rights_audit').doc(videoId), {
        videoId,
        userId: user.userId,
        monetizable: !!value,
        reason: reason || null,
        reviewedAt: now
      }, { merge: true })

      tx.update(videoRef, {
        monetizable: !!value,
        rightsReviewedAt: now,
        updatedAt: now
      })
    })

    rep.send({ ok: true, videoId, monetizable: !!value })
  } catch (error) {
    console.error('Review monetizable error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function snapshotProofHandler(req: FastifyRequest<{ Body: { sourceAssetId: string, html?: string, screenshot?: string } }>, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const { sourceAssetId, html, screenshot } = req.body || {}

    if (!sourceAssetId) {
      return rep.code(400).send({ error: 'sourceAssetId is required' })
    }

    const proofId = `proof_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`
    const now = admin.firestore.Timestamp.now()

    const proofData: any = {
      id: proofId,
      userId: user.userId,
      sourceAssetId,
      createdAt: now
    }

    if (html) {
      const htmlFileName = `proofs/${proofId}.html`
      const htmlFile = storage.bucket(PROOF_BUCKET).file(htmlFileName)
      await htmlFile.save(html, { contentType: 'text/html' })
      const [htmlUrl] = await htmlFile.getSignedUrl({
        action: 'read',
        version: 'v4',
        expires: Date.now() + 365 * 24 * 60 * 60 * 1000
      })
      proofData.htmlUrl = htmlUrl
    }

    if (screenshot) {
      const screenshotFileName = `proofs/${proofId}.png`
      const screenshotFile = storage.bucket(PROOF_BUCKET).file(screenshotFileName)
      await screenshotFile.save(Buffer.from(screenshot, 'base64'), { contentType: 'image/png' })
      const [screenshotUrl] = await screenshotFile.getSignedUrl({
        action: 'read',
        version: 'v4',
        expires: Date.now() + 365 * 24 * 60 * 60 * 1000
      })
      proofData.screenshotUrl = screenshotUrl
    }

    await db.collection('proofs').doc(proofId).set(proofData)

    rep.send({ ok: true, proofId, htmlUrl: proofData.htmlUrl || null, screenshotUrl: proofData.screenshotUrl || null })
  } catch (error) {
    console.error('Snapshot proof error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}

export async function metricsDailyHandler(req: FastifyRequest, rep: FastifyReply) {
  try {
    const user = await requireUser(req, rep)
    if (!user) return

    const days = 7
    const now = admin.firestore.Timestamp.now()
    const rows = []

    for (let i = 0; i < days; i++) {
      const date = new Date()
      date.setDate(date.getDate() - i)
      const dateStr = date.toISOString().split('T')[0]

      const jobsSnap = await db.collection('ingest_jobs')
        .where('userId', '==', user.userId)
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(new Date(date)))
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(new Date(date.getTime() + 24 * 60 * 60 * 1000)))
        .get()

      rows.push({
        date: dateStr,
        jobs: jobsSnap.size,
        completed: jobsSnap.docs.filter(d => d.data().status === 'completed').length,
        failed: jobsSnap.docs.filter(d => d.data().status === 'failed').length
      })
    }

    rep.send({ rows })
  } catch (error) {
    console.error('Metrics daily error:', error)
    rep.code(500).send({ error: 'Internal server error' })
  }
}


