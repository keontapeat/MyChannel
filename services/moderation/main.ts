import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

// POST /v1/moderate/video { title, description, thumbnailUri }
app.post('/v1/moderate/video', async (req, res) => {
  try {
    const { title, description, thumbnailUri } = req.body || {};
    // TODO: integrate with safety ML (Vertex AI, Perspective, custom)
    const result = {
      titleSafe: true,
      descriptionSafe: true,
      thumbnailSafe: true,
      flags: [] as string[],
    };
    return res.json(result);
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`moderation service listening on ${port}`));




