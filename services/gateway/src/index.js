import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import jwt from '@fastify/jwt'
import { fetch } from 'undici'

if (!process.env.JWT_SECRET) {
  throw new Error('Missing JWT_SECRET')
}

const app = Fastify({ logger: true })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 200, timeWindow: '1 minute' })
await app.register(jwt, { secret: process.env.JWT_SECRET })

async function auth(req, reply) {
  try {
    await req.jwtVerify()
  } catch (err) {
    return reply.code(401).send({ error: 'Unauthorized' })
  }
}

function buildForwardHeaders(req) {
  const headers = { ...req.headers }
  delete headers.host
  delete headers['content-length']
  if (req.user) {
    headers['x-auth-user-id'] = String(req.user.userId || req.user.uid || '')
    headers['x-auth-email'] = String(req.user.email || '')
  }
  return headers
}

app.get('/health', async () => ({ status: 'ok' }))

// Proxy examples to internal services (env-configurable)
const BOOST = process.env.CHANNELBOOST_URL || 'http://channelboost:8787'
const MIND  = process.env.CHANNELMIND_URL  || 'http://channelmind:8080'
const SEARCH = process.env.SEARCH_URL      || 'http://search:8080'
const MODERATION = process.env.MODERATION_URL || 'http://moderation:8080'
const VIDEO_CONTENT_ID = process.env.VIDEO_CONTENT_ID_URL || 'http://video-content-id:8080'
const PAY   = process.env.PAY_URL          || 'http://pay:8888'
const PROTECT = process.env.PROTECT_URL    || 'http://protect:9091'
const IQ      = process.env.IQ_URL         || 'http://iq:9092'
const ADS     = process.env.ADS_URL        || 'http://ads:9093'
const REWARDS = process.env.REWARDS_URL    || 'http://rewards:9094'
const TRANS   = process.env.TRANSLATE_URL  || 'http://translate:9095'
const LABS    = process.env.LABS_URL       || 'http://labs:9096'
const VAULT   = process.env.VAULT_URL      || 'http://core-vault:9097'
const CONNECT = process.env.CONNECT_URL    || 'http://connect:9098'
const DOCTOR  = process.env.DOCTOR_URL     || 'http://doctor:9099'

app.all('/boost/*', { preHandler: auth }, async (req, reply) => {
  const url = BOOST + req.url.replace('/boost', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

app.all('/mind/*', { preHandler: auth }, async (req, reply) => {
  const url = MIND + req.url.replace('/mind', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

// Search is unauthenticated on purpose: it only reads public videos/channels
// (isPublic == true), matching the public-browsing UX of /app/search on web.
// No user/session data is exposed through this proxy.
app.all('/search/*', async (req, reply) => {
  const url = SEARCH + req.url.replace('/search', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

// Moderation requires auth: it's called by the uploader at publish time
// (pre-flight check before a video goes live), so we need to know who's
// asking to rate-limit abuse. The authoritative enforcement pass still runs
// server-side in Cloud Functions (functions/main.py moderate_video_on_upload)
// regardless of whether the client calls this endpoint.
app.all('/moderation/*', { preHandler: auth }, async (req, reply) => {
  const url = MODERATION + req.url.replace('/moderation', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

// Video Content ID: registering a reference or scanning requires auth (write
// paths); reading existing matches for a video is intentionally left behind
// auth too since match data can reveal a rightsholder's copyright claims.
app.all('/video-content-id/*', { preHandler: auth }, async (req, reply) => {
  const url = VIDEO_CONTENT_ID + req.url.replace('/video-content-id', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

app.all('/pay/*', { preHandler: auth }, async (req, reply) => {
  const url = PAY + req.url.replace('/pay', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

app.all('/protect/*', { preHandler: auth }, async (req, reply) => {
  const url = PROTECT + req.url.replace('/protect', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

app.all('/iq/*', { preHandler: auth }, async (req, reply) => {
  const url = IQ + req.url.replace('/iq', '')
  const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
  reply.status(res.status)
  for (const [k,v] of res.headers) reply.header(k, v)
  reply.send(await res.arrayBuffer())
})

function proxy(prefix, base) {
  app.all(`${prefix}/*`, { preHandler: auth }, async (req, reply) => {
    const url = base + req.url.replace(prefix, '')
    const res = await fetch(url, { method: req.method, headers: buildForwardHeaders(req), body: req.method === 'GET' || req.method === 'HEAD' ? undefined : req.raw })
    reply.status(res.status)
    for (const [k,v] of res.headers) reply.header(k, v)
    reply.send(await res.arrayBuffer())
  })
}

proxy('/ads', ADS)
proxy('/rewards', REWARDS)
proxy('/translate', TRANS)
proxy('/labs', LABS)
proxy('/vault', VAULT)
proxy('/connect', CONNECT)
proxy('/doctor', DOCTOR)

const port = process.env.PORT || 8088
app.listen({ port, host: '0.0.0.0' })


