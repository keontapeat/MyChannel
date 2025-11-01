import express from 'express';
import cors from 'cors';
import { Storage } from '@google-cloud/storage';

const app = express();
const storage = new Storage();
const INGEST_BUCKET = process.env.INGEST_BUCKET || 'mychannel-ingest';
app.use(cors({ origin: '*', methods: ['POST','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
app.use(express.json());

// TODO: verify Firebase JWT here

app.post('/v1/uploads/signed-url', async (req, res) => {
  try {
    const { filename } = req.body || {};
    if (!filename) return res.status(400).json({ error: 'filename required' });

    const file = storage.bucket(INGEST_BUCKET).file(filename);
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
      .json({ url, method: 'PUT', bucket: INGEST_BUCKET, object: filename, getUrl });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// Return a temporary read URL for an object (defaults to ingest bucket)
app.post('/v1/uploads/get-url', async (req, res) => {
  try {
    const { object, bucket } = req.body || {};
    const bkt = String(bucket || INGEST_BUCKET);
    const obj = String(object || '').trim();
    if (!obj) return res.status(400).json({ error: 'object required' });
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
    const { object, bucket, contentType } = req.body || {};
    const bkt = String(bucket || INGEST_BUCKET);
    const obj = String(object || '').trim();
    if (!obj) return res.status(400).json({ error: 'object required' });
    const file = storage.bucket(bkt).file(obj);
    if (contentType) {
      try { await file.setMetadata({ contentType: String(contentType) }); } catch {}
    }
    // Return signed read URL; do not make public
    const [getUrl] = await file.getSignedUrl({ action: 'read', version: 'v4', expires: Date.now() + 24 * 60 * 60 * 1000 }); // 24 hours
    return res.set({ 'Access-Control-Allow-Origin': '*' }).json({ url: getUrl, bucket: bkt, object: obj, contentType: contentType || null });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`upload service listening on ${port}`));


