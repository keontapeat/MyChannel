import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { Storage } from '@google-cloud/storage';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';
import { createHash, randomUUID } from 'node:crypto';

if (!admin.apps.length) {
  admin.initializeApp();
}

const JWT_SECRET = process.env.JWT_SECRET || '';

type AuthenticatedUser = {
  userId: string;
  email: string | null;
  username: string | null;
};

async function verifyUser(authHeader: string | undefined): Promise<AuthenticatedUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      userId: decoded.uid,
      email: decoded.email || null,
      username: decoded.name || (decoded.email ? decoded.email.split('@')[0] : null)
    };
  } catch {}

  if (!JWT_SECRET) return null;

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const userId = String(decoded.userId || decoded.uid || '').trim();
    if (!userId) return null;
    return {
      userId,
      email: decoded.email || null,
      username: decoded.username || null
    };
  } catch {
    return null;
  }
}

async function requireUser(req: any, res: any): Promise<AuthenticatedUser | null> {
  const user = await verifyUser(req.headers.authorization);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return user;
}

function normalizeFilename(filename: string): string {
  const base = filename.split('/').pop() || filename;
  const sanitized = base.replace(/[^a-zA-Z0-9._-]/g, '_').replace(/_+/g, '_');
  return sanitized || `upload-${Date.now()}`;
}

function buildPublicUrl(bucket: string, object: string): string {
  return `https://storage.googleapis.com/${bucket}/${object.split('/').map(segment => encodeURIComponent(segment)).join('/')}`;
}

const app = express();
const storage = new Storage();
const INGEST_BUCKET = process.env.INGEST_BUCKET || 'mychannel-ingest';
const MAX_VIDEO_BYTES = Number(process.env.MAX_VIDEO_UPLOAD_BYTES || 2 * 1024 * 1024 * 1024);
const ALLOWED_VIDEO_TYPES = new Set([
  'video/mp4', 'video/quicktime', 'video/webm', 'video/x-m4v', 'video/mpeg',
]);

function uploadSessionId(objectName: string): string {
  return createHash('sha256').update(objectName).digest('hex');
}

function validateOwnedObject(value: unknown, userId: string): string {
  const objectName = String(value || '').trim();
  if (!objectName.startsWith(`uploads/${userId}/`) || objectName.includes('..') || objectName.length > 1024) {
    throw new Error('Forbidden object path');
  }
  return objectName;
}

function validateContentType(value: unknown): string {
  const contentType = String(value || 'video/mp4').toLowerCase();
  if (!ALLOWED_VIDEO_TYPES.has(contentType)) throw new Error('Unsupported video content type');
  return contentType;
}

function validateSize(value: unknown): number {
  const size = Number(value);
  if (!Number.isInteger(size) || size <= 0 || size > MAX_VIDEO_BYTES) {
    throw new Error(`Upload size must be between 1 and ${MAX_VIDEO_BYTES} bytes`);
  }
  return size;
}

app.use(cors({
  origin: process.env.CORS_ORIGIN || 'https://mychannel.live',
  methods: ['POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({limit: '16kb'}));
app.use('/v1/uploads', rateLimit({
  windowMs: 60_000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
}));

// Auth is enforced per-route via requireUser() (Firebase ID token or internal JWT).

app.post('/v1/uploads/signed-url', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const {filename, contentType: rawContentType, sizeBytes} = req.body || {};
    if (!filename) return res.status(400).json({error: 'filename required'});
    const contentType = validateContentType(rawContentType);
    const expectedSize = validateSize(sizeBytes);
    const objectName = `uploads/${user.userId}/${randomUUID()}-${normalizeFilename(String(filename))}`;
    const file = storage.bucket(INGEST_BUCKET).file(objectName);
    const [url] = await file.getSignedUrl({
      action: 'write',
      version: 'v4',
      expires: Date.now() + 15 * 60 * 1000,
      contentType,
    });
    const [getUrl] = await file.getSignedUrl({
      action: 'read',
      version: 'v4',
      expires: Date.now() + 60 * 60 * 1000,
    });

    await admin.firestore().collection('_uploadSessions').doc(uploadSessionId(objectName)).set({
      ownerId: user.userId,
      bucket: INGEST_BUCKET,
      object: objectName,
      contentType,
      expectedSize,
      status: 'pending',
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({
      url,
      method: 'PUT',
      bucket: INGEST_BUCKET,
      object: objectName,
      getUrl,
      contentType,
      expectedSize,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Invalid upload request';
    return res.status(message.includes('size') || message.includes('content type') ? 400 : 500)
      .json({error: message});
  }
});

// Return a temporary read URL for an object (defaults to ingest bucket)
app.post('/v1/uploads/get-url', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const {object, bucket} = req.body || {};
    if (bucket && String(bucket) !== INGEST_BUCKET) {
      return res.status(400).json({error: 'Unsupported bucket'});
    }
    const obj = validateOwnedObject(object, user.userId);
    const file = storage.bucket(INGEST_BUCKET).file(obj);
    const [getUrl] = await file.getSignedUrl({
      action: 'read',
      version: 'v4',
      expires: Date.now() + 60 * 60 * 1000,
    });
    return res.json({url: getUrl, bucket: INGEST_BUCKET, object: obj});
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Invalid request';
    return res.status(message.includes('Forbidden') || message.includes('bucket') ? 400 : 500)
      .json({error: message});
  }
});

// Finalize only after server-verifying the actual GCS object against the upload reservation.
app.post('/v1/uploads/finalize', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const {object, bucket, contentType: requestedContentType} = req.body || {};
    if (bucket && String(bucket) !== INGEST_BUCKET) {
      return res.status(400).json({error: 'Unsupported bucket'});
    }
    const obj = validateOwnedObject(object, user.userId);
    const sessionRef = admin.firestore().collection('_uploadSessions').doc(uploadSessionId(obj));
    const session = await sessionRef.get();
    if (!session.exists || session.get('ownerId') !== user.userId || session.get('object') !== obj) {
      return res.status(403).json({error: 'Upload reservation not found'});
    }
    if (session.get('status') === 'finalized') {
      const file = storage.bucket(INGEST_BUCKET).file(obj);
      const [url] = await file.getSignedUrl({action: 'read', version: 'v4', expires: Date.now() + 60 * 60 * 1000});
      return res.json({
        url,
        publicUrl: buildPublicUrl(INGEST_BUCKET, obj),
        bucket: INGEST_BUCKET,
        object: obj,
        contentType: session.get('contentType'),
        sizeBytes: session.get('actualSize'),
        checksum: session.get('checksum') || null,
      });
    }

    const expectedContentType = validateContentType(session.get('contentType'));
    if (requestedContentType && validateContentType(requestedContentType) !== expectedContentType) {
      return res.status(400).json({error: 'Content type does not match upload reservation'});
    }
    const file = storage.bucket(INGEST_BUCKET).file(obj);
    const [metadata] = await file.getMetadata();
    const actualSize = Number(metadata.size);
    if (!Number.isFinite(actualSize) || actualSize <= 0 || actualSize > MAX_VIDEO_BYTES ||
        actualSize !== Number(session.get('expectedSize'))) {
      await sessionRef.set({
        status: 'rejected',
        rejectionReason: 'size_mismatch',
        actualSize: Number.isFinite(actualSize) ? actualSize : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return res.status(422).json({error: 'Uploaded object size does not match reservation'});
    }
    if (metadata.contentType !== expectedContentType) {
      await sessionRef.set({
        status: 'rejected',
        rejectionReason: 'content_type_mismatch',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return res.status(422).json({error: 'Uploaded object content type does not match reservation'});
    }

    await file.setMetadata({
      contentType: expectedContentType,
      cacheControl: 'private, max-age=0, no-store',
      metadata: {
        ownerId: user.userId,
        uploadValidated: 'true',
      },
    });
    await sessionRef.set({
      status: 'finalized',
      actualSize,
      checksum: metadata.crc32c || metadata.md5Hash || null,
      finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    const [getUrl] = await file.getSignedUrl({
      action: 'read',
      version: 'v4',
      expires: Date.now() + 60 * 60 * 1000,
    });
    return res.json({
      url: getUrl,
      publicUrl: buildPublicUrl(INGEST_BUCKET, obj),
      bucket: INGEST_BUCKET,
      object: obj,
      contentType: expectedContentType,
      sizeBytes: actualSize,
      checksum: metadata.crc32c || metadata.md5Hash || null,
    });
  } catch (error) {
    console.error('Upload finalize error:', error instanceof Error ? error.message : error);
    return res.status(500).json({error: 'Failed to finalize upload'});
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`upload service listening on ${port}`));


