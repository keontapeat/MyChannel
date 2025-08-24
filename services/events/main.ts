import express from 'express';
import cors from 'cors';
import { PubSub } from '@google-cloud/pubsub';

const app = express();
const pubsub = new PubSub();
const EVENTS_TOPIC = process.env.EVENTS_TOPIC || 'events';
app.use(cors());
app.use(express.json());

app.post('/v1/events', async (req, res) => {
  try {
    const payload = req.body || {};
    await pubsub.topic(EVENTS_TOPIC).publishMessage({ json: payload });
    return res.json({ ok: true });
  } catch (e:any) {
    return res.status(500).json({ error: e?.message || 'internal' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`events service listening on ${port}`));


