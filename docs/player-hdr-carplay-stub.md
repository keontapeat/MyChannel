# Player HDR / Dolby / CarPlay stubs (batch-7)

## HDR & Dolby Atmos

- **Policy:** Never force HDR/EDR or spatial audio on assets that are SDR-only.
- **Code path:** `VideoPlayerManager.configureAudioSession()` sets
  `audiovisualBackgroundPlaybackPolicy = .continuesIfPossible` only on iOS 15+.
  No manual `AVPlayerItem.videoComposition` HDR overrides.
- **Premium gate:** 4K/HDR remains behind `PremiumFeature.highQuality` — see `PremiumService`.
- **Safe no-op:** If the asset has no Dolby/Atmos track, AVFoundation ignores selection; we do not crash.

## CarPlay

- **Status:** Basic play/pause is routed through `UniversalPlayerHandoffService.enableCarPlayMode()`
  and `NowPlayingService` remote commands when CarPlay audio session category is active.
- **Not shipped:** Full CarPlay video browsing template — out of scope for Flicks vertical feed.
- **Enable flag:** `AppConfig.Features.enableCarPlay` (default false in debug).

## Watch companion

- **Implemented:** `WatchConnectivityService` pushes now-playing + handles play/pause/skip from watch.
