import express from 'express';
import cors from 'cors';
import { Storage } from '@google-cloud/storage';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';

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
app.use(cors({ origin: '*', methods: ['POST','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
app.use(express.json());

// TODO: verify Firebase JWT here

app.post('/v1/uploads/signed-url', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { filename } = req.body || {};
    if (!filename) return res.status(400).json({ error: 'filename required' });

    const objectName = `uploads/${user.userId}/${Date.now()}-${normalizeFilename(String(filename))}`;

    const file = storage.bucket(INGEST_BUCKET).file(objectName);
    const [url] = await file.getSignedUrl({
      action: 'write',
      version: 'v4',
      expires: Date.now() + 15 * 60 * 1000,
      // Do NOT bind contentType; some browsers override or omit the header (e.g., iOS Safari),
      // which would cause SignatureDoesNotMatch if included in the signed headers
    });
    const [getUrl] = await file.getSignedUrl({
      action: 'read',
      version: 'v4',
      expires: Date.now() + 24 * 60 * 60 * 1000, // 24 hours
    });

    // Allow browser direct PUT upload
    return res
      .set({ 'Access-Control-Allow-Origin': '*' })
      .json({ url, method: 'PUT', bucket: INGEST_BUCKET, object: objectName, getUrl });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// Return a temporary read URL for an object (defaults to ingest bucket)
app.post('/v1/uploads/get-url', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { object, bucket } = req.body || {};
    const bkt = String(bucket || INGEST_BUCKET);
    const obj = String(object || '').trim();
    if (!obj) return res.status(400).json({ error: 'object required' });
    if (!obj.startsWith(`uploads/${user.userId}/`)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const file = storage.bucket(bkt).file(obj);
    const [getUrl] = await file.getSignedUrl({ action: 'read', version: 'v4', expires: Date.now() + 24 * 60 * 60 * 1000 }); // 24 hours
    return res.set({ 'Access-Control-Allow-Origin': '*' }).json({ url: getUrl, bucket: bkt, object: obj });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// Finalize upload: set contentType metadata and return a fresh read URL
app.post('/v1/uploads/finalize', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { object, bucket, contentType } = req.body || {};
    const bkt = String(bucket || INGEST_BUCKET);
    const obj = String(object || '').trim();
    if (!obj) return res.status(400).json({ error: 'object required' });
    if (!obj.startsWith(`uploads/${user.userId}/`)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const file = storage.bucket(bkt).file(obj);
    if (contentType) {
      try { await file.setMetadata({ contentType: String(contentType) }); } catch {}
    }
    // Return signed read URL; do not make public
    const [getUrl] = await file.getSignedUrl({ action: 'read', version: 'v4', expires: Date.now() + 24 * 60 * 60 * 1000 }); // 24 hours
    return res.set({ 'Access-Control-Allow-Origin': '*' }).json({ url: getUrl, publicUrl: buildPublicUrl(bkt, obj), bucket: bkt, object: obj, contentType: contentType || null });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`upload service listening on ${port}`));


