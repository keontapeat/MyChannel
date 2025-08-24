import express from 'express';
import cors from 'cors';
const app = express();
app.use(cors());
app.use(express.json());
app.post('/v1/events', async (req, res) => {
    try {
        // TODO: publish to Pub/Sub 'events'
        console.log('event', req.body);
        return res.json({ ok: true });
    }
    catch (e) {
        return res.status(500).json({ error: e?.message || 'internal' });
    }
});
const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`events service listening on ${port}`));
