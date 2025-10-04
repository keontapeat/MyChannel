import express from 'express';
import cors from 'cors';
import { PubSub } from '@google-cloud/pubsub';

const app = express();
const pubsub = new PubSub();
const EVENTS_TOPIC = process.env.EVENTS_TOPIC || 'events';
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'events' });
});

app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'mychannel-events', version: '1.0.0' });
});

app.post('/v1/events', async (req, res) => {
  try {
    const payload = req.body || {};
    await pubsub.topic(EVENTS_TOPIC).publishMessage({ json: payload });
    return res.json({ ok: true });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

// Sharded view counter (same-origin, bypasses public IAM)
app.post('/v1/events/view', async (req, res) => {
  try {
    const { videoId } = req.body || {};
    if (!videoId) return res.status(400).json({ error: 'missing videoId' });
    // Publish to events topic; a future consumer can aggregate shards
    await pubsub.topic(EVENTS_TOPIC).publishMessage({ json: { type: 'view', videoId, ts: Date.now() } });
    return res.json({ ok: true });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`events service listening on ${port}`));


