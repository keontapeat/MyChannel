import express from 'express';
import cors from 'cors';
const app = express();
app.use(cors());
app.use(express.json());
// TODO: verify Firebase JWT here
app.post('/v1/uploads/signed-url', async (req, res) => {
    try {
        // Placeholder: return mock signed URL contract
        const { filename, contentType } = req.body || {};
        if (!filename || !contentType)
            return res.status(400).json({ error: 'filename, contentType required' });
        return res.json({ url: 'https://storage.googleapis.com/ingest-placeholder', method: 'PUT', headers: { 'Content-Type': contentType } });
    }
    catch (e) {
        return res.status(500).json({ error: e?.message || 'internal' });
    }
});
const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`upload service listening on ${port}`));
