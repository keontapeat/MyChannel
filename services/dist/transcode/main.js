import express from 'express';
import cors from 'cors';
const app = express();
app.use(cors());
app.use(express.json());
// Pub/Sub push endpoint (for tests) or manual trigger
app.post('/v1/transcode/ingest', async (req, res) => {
    try {
        // TODO: call Transcoder API or Mux; write outputs to public bucket
        console.log('ingest message', req.body);
        return res.json({ ok: true });
    }
    catch (e) {
        return res.status(500).json({ error: e?.message || 'internal' });
    }
});
const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`transcode service listening on ${port}`));
