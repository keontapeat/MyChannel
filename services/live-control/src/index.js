import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

// In-memory stub store
const streams = new Map();

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.post('/live/start', (req, res) => {
  const id = `live_${Date.now()}`;
  const streamKey = `sk_${Math.random().toString(36).slice(2, 10)}`;
  const rtmpUrl = `rtmp://rtmp.mychannel.live/live/${streamKey}`;
  const hlsUrl = `https://cdn.mychannel.live/hls/${id}/master.m3u8`;
  streams.set(id, { id, streamKey, rtmpUrl, hlsUrl, status: 'live', startedAt: new Date().toISOString() });
  res.json({ id, streamKey, rtmpUrl, hlsUrl });
});

app.post('/live/end', (req, res) => {
  const { id } = req.body || {};
  if (!id || !streams.has(id)) return res.status(404).json({ error: 'not_found' });
  const s = streams.get(id);
  s.status = 'ended';
  s.endedAt = new Date().toISOString();
  streams.set(id, s);
  res.json({ ok: true });
});

app.get('/live/status/:id', (req, res) => {
  const { id } = req.params;
  if (!streams.has(id)) return res.status(404).json({ error: 'not_found' });
  res.json(streams.get(id));
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`live-control listening on ${port}`));




