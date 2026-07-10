# Offline Downloads — iOS Only

Offline video downloads are **iOS-native only**. The web app (`web-v2/`) does not implement
offline download storage, HLS background sessions, or local playback manifests.

## Platform matrix

| Surface | Offline downloads |
|---------|-------------------|
| iOS (`OfflineDownloadService`) | ✅ Full support — HLS via `HLSDownloadManager`, progressive via Firebase Storage |
| Android | ❌ Not implemented in this repo |
| Web (`web-v2/`) | ❌ Explicitly out of scope — show Plus upsell / deep-link to iOS where needed |

## Canonical iOS entry points

- `OfflineDownloadService.shared` — download queue, storage quota, manifest persistence
- `DownloadsView` — library UI (Plus-gated when `AppConfig.Features.enableSubscriptions`)
- In-player download button — routes through `OfflineDownloadService.downloadVideo`

## Web guidance

When building web download CTAs, treat offline as an iOS Premium/Plus feature. Do not
attempt browser-side HLS offline caching; link users to the App Store or in-app Downloads tab.
