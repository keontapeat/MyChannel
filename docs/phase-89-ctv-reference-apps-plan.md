# Phase 89 — Roku / Fire TV / Samsung Tizen

**Status:** ⬜ pending · **Depends on:** Phase 88 (PWA backend endpoints)

## Goal
Ship three Connected-TV reference apps using platform-native tech. All three hit the same REST contract as the iOS + Android clients.

## Platform matrix

### Roku
- BrightScript + SceneGraph
- DASH + HLS playback via native `Video` node
- Sideload via Developer install, then Roku Store cert
- Channel ID reserved: `mychannel-tv` (TBC)
- Repository path: `apps/roku/`

### Fire TV
- Reuse Phase 87 Android TV APK; ship via Amazon Appstore
- Replace Google Play Billing with Amazon IAP
- File path: `apps/android/tv/build-flavors/fireTV/`

### Samsung Tizen
- Tizen Studio + TypeScript + Preact
- Build target: Tizen 7.0+
- HLS via native `<object>` AVPlay
- Submit via Samsung Seller Office
- Repository path: `apps/tizen/`

## Shared contract
All three apps call:
- `GET /v1/feed` — home rows
- `GET /v1/videos/:id` — detail + manifest
- `POST /v1/events` — analytics
- `POST /oauth/device` — pairing code flow

## Out of scope
- PlayStation (future)
- Xbox (future)
- LG webOS (after Tizen ships and we harden the shared TS codebase)
