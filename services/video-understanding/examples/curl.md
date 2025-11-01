# ChannelMind cURL examples

## Health

curl -s http://localhost:8080/health | jq

## Ingest (requires bearer token)

curl -s -X POST http://localhost:8080/ingest \
  -H "Authorization: Bearer $API_AUTH_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"video_gcs_uri": "gs://mc-videos/path/to/video.mp4"}' | jq

## Search moments

curl -s "http://localhost:8080/search?q=hello&k=5" | jq

## Chapters

curl -s http://localhost:8080/chapters/$VIDEO_ID | jq

## Tags

curl -s http://localhost:8080/tags/$VIDEO_ID | jq

## Summarize (requires bearer token)

curl -s -X POST http://localhost:8080/summarize \
  -H "Authorization: Bearer $API_AUTH_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"video_id": "'$VIDEO_ID'"}' | jq

