---
inclusion: fileMatch
fileMatchPattern: ['**/*.swift', 'web-v2/**', 'web/**', '**/*.tsx']
---

# Image & Media URL Standards

Broken thumbnails are a recurring problem. Follow these rules whenever you set image or stream URLs (channel logos, thumbnails, avatars, live previews).

## Never Use These Image Sources
- `wikipedia.org` / `wikimedia.org` — they block external image requests.
- `.svg` files for thumbnails/logos — `AsyncImage` doesn't render SVG reliably.
- Any URL requiring auth or with CORS restrictions.

## Approved Image Sources
- **YouTube thumbnails (preferred for channel logos):**
  - `https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg`
  - `https://i.ytimg.com/vi/{VIDEO_ID}/maxresdefault.jpg`
- Approved CDNs: `ytimg.com`, `imgur.com`, `cloudinary.com`, `googleusercontent.com`, `akamaized.net`, `cloudfront.net`, `pluto.tv`, `image.tmdb.org`, `m.media-amazon.com`.
- Direct `.jpg` / `.jpeg` / `.png` / `.webp` / `.gif` from reliable hosts.

## Live TV Channels (iOS)
When creating `LiveTVChannel` objects:
- `logoURL` must be a YouTube thumbnail or an approved CDN URL.
- Always set `previewFallbackURL` to the Apple test stream:
  `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8`

## Loading
- iOS: use `CachedAsyncImage` / `MultiSourceAsyncImage` with explicit frame sizes and a failure fallback.
- Web: lazy-load images; provide alt text.
