import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

// GET /v1/creator/drafts
app.get('/v1/creator/drafts', async (_req, res) => {
  // TODO: fetch drafts from database
  return res.json({ drafts: [] });
});

// POST /v1/creator/drafts
app.post('/v1/creator/drafts', async (req, res) => {
  try {
    const draft = req.body || {};
    // TODO: persist draft
    return res.status(201).json({ draft, id: 'draft_1' });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// GET /v1/creator/analytics
app.get('/v1/creator/analytics', async (_req, res) => {
  // TODO: query BigQuery or analytics store
  return res.json({ views: 0, watchTime: 0, subscribers: 0 });
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`creator service listening on ${port}`));




