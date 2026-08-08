import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';
import { createHash, randomUUID } from 'node:crypto';
import { PubSub } from '@google-cloud/pubsub';

if (!admin.apps.length) admin.initializeApp();

const app = express();
const pubsub = new PubSub();
const EVENTS_TOPIC = process.env.EVENTS_TOPIC || 'events';
const JWT_SECRET = process.env.JWT_SECRET || '';
const REQUIRE_APP_CHECK = process.env.REQUIRE_APP_CHECK !== 'false';
const EVENT_TYPES = new Set([
  'view', 'playback_start', 'heartbeat', 'playback_end', 'watch_time',
  'like', 'unlike', 'dislike', 'undislike', 'comment', 'share', 'not_interested'
]);

type Caller = { actorId: string; source: 'firebase' | 'service' };

async function authenticate(header: string | undefined): Promise<Caller | null> {
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  if (!token) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return { actorId: decoded.uid, source: 'firebase' };
  } catch {}
  if (!JWT_SECRET) return null;
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as jwt.JwtPayload;
    const actorId = String(decoded.uid || decoded.userId || decoded.sub || '').trim();
    return actorId ? { actorId, source: 'service' } : null;
  } catch {
    return null;
  }
}

function cleanId(value: unknown, field: string): string {
  const id = String(value || '').trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw new Error(`invalid ${field}`);
  return id;
}

function finiteNumber(value: unknown, min: number, max: number): number | undefined {
  if (value === undefined || value === null) return undefined;
  const number = Number(value);
  if (!Number.isFinite(number) || number < min || number > max) throw new Error('invalid numeric field');
  return number;
}

app.use(cors({
  origin: process.env.CORS_ORIGIN || 'https://mychannel.live',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Authorization', 'Content-Type', 'X-Idempotency-Key', 'X-Firebase-AppCheck']
}));
app.use(express.json({ limit: '32kb' }));
app.use('/v1/events', rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: true, legacyHeaders: false }));

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'events' }));
app.get('/', (_req, res) => res.json({ status: 'ok', service: 'mychannel-events', version: '2.0.0' }));

async function publishEvent(req: express.Request, res: express.Response, forcedType?: string) {
  const caller = await authenticate(req.headers.authorization);
  if (!caller) return res.status(401).json({ error: 'Unauthorized' });
  if (caller.source === 'firebase' && REQUIRE_APP_CHECK) {
    const appCheckToken = req.header('x-firebase-appcheck');
    if (!appCheckToken) return res.status(401).json({error: 'App Check required'});
    try {
      await admin.appCheck().verifyToken(appCheckToken);
    } catch {
      return res.status(401).json({error: 'Invalid App Check token'});
    }
  }

  try {
    const body = req.body || {};
    const type = String(forcedType || body.type || '').trim();
    if (!EVENT_TYPES.has(type)) return res.status(400).json({ error: 'Unsupported event type' });

    const videoId = cleanId(body.videoId, 'videoId');
    const sessionId = cleanId(body.sessionId || randomUUID(), 'sessionId');
    const headerKey = req.header('x-idempotency-key');
    const idempotencyKey = cleanId(headerKey || body.idempotencyKey || randomUUID(), 'idempotencyKey');
    const positionSeconds = finiteNumber(body.positionSeconds, 0, 86400);
    const watchTime = finiteNumber(body.watchTime, 0, 86400);
    const completionRate = finiteNumber(body.completionRate, 0, 1);

    const eventId = randomUUID();
    const occurredAt = new Date().toISOString();
    const event = {
      schemaVersion: 1,
      eventId,
      idempotencyKey,
      type,
      videoId,
      sessionId,
      actorId: caller.actorId,
      source: caller.source,
      occurredAt,
      ...(positionSeconds !== undefined && { positionSeconds }),
      ...(watchTime !== undefined && { watchTime }),
      ...(completionRate !== undefined && { completionRate })
    };
    const fingerprint = createHash('sha256')
      .update(JSON.stringify({type, videoId, sessionId, actorId: caller.actorId, positionSeconds, watchTime, completionRate}))
      .digest('hex');
    const reservationId = createHash('sha256')
      .update(`${caller.actorId}\u001f${idempotencyKey}`)
      .digest('hex');
    const reservationRef = admin.firestore().collection('_eventIdempotency').doc(reservationId);
    const publisherToken = randomUUID();

    const reservation = await admin.firestore().runTransaction(async transaction => {
      const snapshot = await transaction.get(reservationRef);
      const existing = snapshot.data();
      if (existing) {
        if (existing.fingerprint !== fingerprint) {
          throw new Error('idempotency key reused with different event');
        }
        if (existing.status === 'published') {
          return {
            action: 'duplicate' as const,
            eventId: String(existing.eventId),
            messageId: String(existing.messageId),
            occurredAt: String(existing.occurredAt),
          };
        }
        const leaseUntil = existing.leaseUntil instanceof admin.firestore.Timestamp
          ? existing.leaseUntil.toMillis()
          : 0;
        if (existing.status === 'publishing' && leaseUntil > Date.now()) {
          return {
            action: 'in_progress' as const,
            eventId: String(existing.eventId),
            messageId: '',
            occurredAt: String(existing.occurredAt),
          };
        }
      }

      const reservedEventId = String(existing?.eventId || eventId);
      const reservedOccurredAt = String(existing?.occurredAt || occurredAt);
      transaction.set(reservationRef, {
        actorId: caller.actorId,
        idempotencyKey,
        fingerprint,
        eventId: reservedEventId,
        occurredAt: reservedOccurredAt,
        status: 'publishing',
        publisherToken,
        leaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + 60_000),
        createdAt: existing?.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        action: 'publish' as const,
        eventId: reservedEventId,
        messageId: '',
        occurredAt: reservedOccurredAt,
      };
    });

    if (reservation.action === 'duplicate') {
      return res.status(202).json({
        ok: true,
        duplicate: true,
        eventId: reservation.eventId,
        messageId: reservation.messageId,
      });
    }
    if (reservation.action === 'in_progress') {
      return res.status(202).json({ok: true, duplicate: true, pending: true, eventId: reservation.eventId});
    }

    const publishableEvent = {
      ...event,
      eventId: reservation.eventId,
      occurredAt: reservation.occurredAt,
    };
    try {
      const messageId = await pubsub.topic(EVENTS_TOPIC).publishMessage({
        json: publishableEvent,
        attributes: {type, videoId, actorId: caller.actorId, idempotencyKey}
      });
      await reservationRef.set({
        status: 'published',
        messageId,
        publisherToken: admin.firestore.FieldValue.delete(),
        leaseUntil: admin.firestore.FieldValue.delete(),
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return res.status(202).json({ok: true, duplicate: false, eventId: reservation.eventId, messageId});
    } catch (publishError) {
      await reservationRef.set({
        status: 'failed',
        publisherToken: admin.firestore.FieldValue.delete(),
        leaseUntil: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true}).catch(() => {});
      throw publishError;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Event publish failed';
    if (message.includes('idempotency key reused')) {
      return res.status(409).json({error: message});
    }
    if (message.startsWith('invalid')) {
      return res.status(400).json({error: message});
    }
    console.error('Event publish failed:', message);
    return res.status(500).json({error: 'Failed to publish event'});
  }
}

app.post('/v1/events', (req, res) => { void publishEvent(req, res); });
app.post('/v1/events/view', (req, res) => { void publishEvent(req, res, 'view'); });

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`events service listening on ${port}`));
