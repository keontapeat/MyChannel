live-control (scaffold)

- POST /live/start → returns { streamKey, rtmpUrl, hlsUrl }
- POST /live/end → ends stream, writes status
- GET /live/status/:id → returns live status

Backed by Cloud Run; integrate with RTMP ingress and HLS packager.



