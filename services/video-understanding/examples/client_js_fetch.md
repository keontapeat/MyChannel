# ChannelMind client fetch examples

// Search moments
fetch(`http://localhost:8080/search?q=${encodeURIComponent('hello')}&k=5`)
  .then(r => r.json())
  .then(console.log)

// Ingest (requires token)
fetch('http://localhost:8080/ingest', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${API_AUTH_TOKEN}`
  },
  body: JSON.stringify({ video_gcs_uri: 'gs://mc-videos/path/video.mp4' })
}).then(r => r.json()).then(console.log)

