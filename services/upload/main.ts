import express from 'express';
import cors from 'cors';
import { Storage } from '@google-cloud/storage';

const app = express();
const storage = new Storage();
const INGEST_BUCKET = process.env.INGEST_BUCKET || 'mychannel-ingest';
app.use(cors());
app.use(express.json());

// TODO: verify Firebase JWT here

app.post('/v1/uploads/signed-url', async (req, res) => {
  try {
    const { filename, contentType } = req.body || {};
    if (!filename || !contentType) return res.status(400).json({ error: 'filename, contentType required' });

    const file = storage.bucket(INGEST_BUCKET).file(filename);
    const [url] = await file.getSignedUrl({
      action: 'write',
      version: 'v4',
      expires: Date.now() + 15 * 60 * 1000,
      contentType,
    });

    return res.json({ url, method: 'PUT', headers: { 'Content-Type': contentType } });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`upload service listening on ${port}`));


