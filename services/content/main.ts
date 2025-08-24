import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/v1/feed/home', async (_req, res) => {
  return res.json({ items: [] });
});

app.get('/v1/videos/:id', async (req, res) => {
  return res.json({ id: req.params.id });
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`content service listening on ${port}`));


