# MyChannel Music — Distribution, Payouts & Content ID (real implementation)

This document covers what changed to move the music hub from simulated flows to
real, production-grade integrations with clean configuration points. The app's
visual design is unchanged.

## What's now real

| Area | Before | Now |
|------|--------|-----|
| Payouts | 100% to main artist, TODO keys | Per-collaborator Stripe transfers grouped by `transfer_group`, owed-balance accrual + claim, API onboarding |
| Distribution | Firestore status only | Real DDEX ERN 4.3 feed generation + aggregator/DDEX-SFTP delivery |
| ISRC / UPC | Fake `US-MCH-…` | Atomic allocation from your IFPI registrant code + GS1 prefix, with validation |
| Content ID | `Math.random()` matching | Chromaprint acoustic fingerprints + Hamming-similarity matching (or ACRCloud/Pex) |
| Transcoding | Moved first chunk only | GCS compose of all chunks → HLS ladder + MP3 320 + FLAC lossless, loudness-normalized |
| Analytics demographics | Hardcoded percentages | Aggregated from real listener profiles |
| Revenue (Content ID) | `Math.random()` | Real ad-revenue attribution × agreed split |
| Parity polish | — | Pre-save/HyperFollow smart links, synced LRC lyrics, cover-song mechanical licensing |

## Services

| File | Port | Purpose |
|------|------|---------|
| `main.ts` | 8080 | Upload, chunked upload + compose, publish, CRUD |
| `distribution.ts` | 8081 | ISRC/UPC allocation, DDEX generation, delivery, status |
| `analytics.ts` | 8082 | Streams, geographic, **real** demographics, device |
| `content-id.ts` | 8083 | Fingerprint register, **real** scan/match, policies, strikes, revenue |
| `artists.ts` | 8084 | Verification, rights, collaborators + splits |
| `albums.ts` | 8085 | Albums/EPs |
| `features.ts` | 8086 | Scheduling, versions, lyrics, sharing |
| `fan-engagement.ts` | 8087 | Messaging, subscriptions, collaborations |
| `business.ts` | 8088 | Tax forms, labels, merch, tours |
| `advanced.ts` | 8089 | Live, playlists, promotion, sync licensing |
| `transcode.ts` | 8090 | **HLS + lossless transcode + auto fingerprint** (needs ffmpeg/fpcalc) |
| `presave.ts` | 8091 | Smart links, synced lyrics, cover licensing |

Helper modules: `codes.ts` (ISRC/UPC), `ddex.ts` (ERN builder), `aggregator.ts`
(delivery adapters), `fingerprint.ts` (chromaprint + ACRCloud/Pex).

## Cloud Function payouts (`cloud-functions/music-payouts/`)

Endpoints: `payoutArtist`, `requestPayout`, `getAvailableBalance`,
`claimOwedEarnings`, `createConnectOnboardingLink`, `stripeWebhook`.

Collaborator splits read `music_track_collaborators/{trackId}`. Each payee with a
linked `artistId` + connected Stripe account receives its own transfer; payees
without a connected account accrue an `owed` ledger entry in
`music_split_earnings` they can later claim via `claimOwedEarnings`.

## Configuration checklist (the only things you must supply)

Set these as Cloud Run / Cloud Function env vars (see `.env.example` in each dir):

1. **Stripe** — `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`. Point the iOS app's
   `AppConfig.API.musicPayoutsBaseURL` at your deployed functions.
2. **ISRC** — `ISRC_REGISTRANT` (from usisrc.org / your IFPI agency), `ISRC_COUNTRY`.
3. **UPC** — `GS1_COMPANY_PREFIX` (from gs1.org).
4. **Distribution** — `DISTRIBUTION_PROVIDER` + `AGGREGATOR_API_BASE`/`AGGREGATOR_API_KEY`
   (FUGA/Revelator/SonoSuite/Believe), or `MYCHANNEL_DPID` + SFTP for direct DDEX.
   Leave as `mock` to exercise the full flow without a partner.
5. **Content ID** — defaults to self-hosted `chromaprint` (needs `fpcalc` in the
   image). For managed recognition set `FINGERPRINT_PROVIDER=acrcloud|pex` + keys.
6. **Transcode** — deploy with `Dockerfile.transcode` (bundles ffmpeg + fpcalc).
   Set `MUSIC_BUCKET`, `ENABLE_LOSSLESS`.

## End-to-end flow

1. Artist uploads (existing UI) → `main.ts` composes chunks into a master.
2. `transcode.ts` renders HLS + MP3 + FLAC, normalizes loudness, **and computes a
   real chromaprint fingerprint registered to Content ID automatically**.
3. Artist distributes → `distribution.ts` allocates real ISRC/UPC, builds a DDEX
   ERN, delivers via the configured aggregator, stores the ERN for audit.
4. Streams accrue → artist requests payout → Cloud Function splits revenue to all
   collaborators via Stripe Connect.
5. When others upload video using the track, `content-id.ts` matches by acoustic
   fingerprint and applies the artist's policy (track/monetize/block).

## Notes / honest limitations

- The aggregator adapter uses a conventional `/v1/deliveries` contract; adjust to
  your partner's exact API when you sign with them. `mock` works out of the box.
- DDEX-over-SFTP queues a delivery; a worker process must ship the batch (the
  ERN + binaries) to the DSP's bucket. Most teams use an aggregator instead.
- Content ID matching scans up to 2000 active references per request. At larger
  catalog scale, move to a vector/LSH index over sub-fingerprints or a managed
  provider (ACRCloud/Pex).
