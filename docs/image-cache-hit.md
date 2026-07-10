# Image Cache Hit Rate

## Stack

| Layer | Component | Capacity |
|-------|-----------|----------|
| HTTP | `NetworkOptimizer.urlCache` | 100 MB memory / 500 MB disk |
| Images | `AppAsyncImage` / `CachedAsyncImage` | NSCache via NetworkOptimizer |
| Prefetch | `ImagePrefetcher.prewarmCritical` | Launch: 20 video posters |

## Hit-rate targets

- **Cached:** <50 ms to first pixel (performance rule)
- **Network:** <200 ms on Wi‑Fi for thumbnails
- **Hit rate goal:** >70% for repeat Home/Flicks scroll sessions

## How dedupe works

`NetworkOptimizer.optimizedRequest` checks `URLCache.cachedResponse(for:)` before network. Identical GET URLs within TTL return without a second socket — this is the primary request dedupe path.

## Measuring (DEBUG)

1. Instruments → Network → compare "Cache Hit" vs miss for `ytimg.com` URLs.
2. Log prefix: `⚡ [NetworkOptimizer] Cache initialized` on launch.
3. On memory warning, cache clears — expect temporary miss spike.

## Tuning

- Bump `thumbnail_cache_version` in `MyChannelApp` to force refresh after CDN migration.
- Poor cellular: `ImageQualityManager` downgrades ytimg suffix (`mqdefault` vs `maxresdefault`).

See also: `docs/launch-perf-checklist.md`
