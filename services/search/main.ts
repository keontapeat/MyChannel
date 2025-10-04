import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

// GET /v1/search?q=term
app.get('/v1/search', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    if (!q) return res.json({ items: [], total: 0 });
    // TODO: integrate with real index (BQ, Algolia, ES, Meilisearch)
    return res.json({ items: [], total: 0, q });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// GET /v1/suggest?q=te
app.get('/v1/suggest', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    // TODO: implement typeahead suggestions based on search index
    const suggestions: string[] = q ? [] : [];
    return res.json({ suggestions });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`search service listening on ${port}`));




