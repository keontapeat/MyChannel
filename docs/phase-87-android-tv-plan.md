# Phase 87 — Android TV & Google TV

**Status:** ⬜ pending · **Depends on:** Phase 86 (Android parity)

## Goal
Ship a 10-foot UI optimized for living-room Android TV and Google TV. Leverages the Phase 86 Android codebase as a shared module.

## Stack additions
- **UI:** Jetpack Compose for TV (material3-tv)
- **Input:** D-pad focus engine + voice search via `android.app.SearchManager`
- **HDR:** HDR10 + Dolby Vision playback via ExoPlayer
- **Cast:** Act as Cast receiver

## Scope
- [ ] Browse, Detail, Search, Library rows
- [ ] 4K 60fps playback with HDR
- [ ] Voice search bound to existing `VoiceSearchService` backend
- [ ] Recommendations row powered by `recommendations` Cloud Run agent
- [ ] SignIn via QR pairing (device code flow)
- [ ] Live row with red dot
- [ ] Continue-watching sync with phone + tablet

## Store listing
- Google Play TV track
- Sony Bravia store (same APK via Google TV)
- Fire TV via Amazon Appstore (separate build target, BillingClient → AmazonIAP adapter)

## Acceptance
- Passes Leanback Launcher quality guidelines
- Cold start on 2019 Shield < 2.5s
- Controller-only UX: 0 touch dependencies
