# MyChannel — Project Overview

MyChannel is a next-generation video platform that combines the best of several products:
- **Video hosting & streaming** (like YouTube)
- **Live streaming & creator awards** (like Twitch)
- **Real-money competitions** (like DraftKings)
- **Championship rankings** (like UFC)

## Tech Stack
- **iOS app:** SwiftUI, Swift 5.9+, Xcode 15+, deployment target iOS 15+. Lives in `MyChannel/` (project `MyChannel.xcodeproj`). tvOS target in `MyChannelTV/`.
- **Web app:** Next.js 14 (App Router) + TypeScript + Tailwind CSS in `web-v2/`. Deployed to Firebase Hosting as a static export. Legacy web in `web/`.
- **Backend:** Firebase (Auth, Firestore, Storage, Realtime DB, Cloud Functions), Node services under `services/`, `functions/`, `cloud-functions/`, and `gateway/`.
- **AI/Agents:** AGI agent system (Money Maker, Growth, Gaming, Safety, Analytics, Scale categories), Google Cloud Vertex AI, ML agents under `ml-agents-deploy/`.
- **Android:** early-stage under `android/`.

## Repo Layout (high level)
- `MyChannel/` — iOS app source (`Core/`, `Features/`, `App/`)
- `web-v2/` — primary Next.js web app (`app/`, `components/`, `lib/`, `services/`, `types/`)
- `services/` — backend microservices (e.g. `services/ads/`)
- `firebase/`, `functions/`, `cloud-functions/` — Firebase config & functions
- `scripts/` — automation and tooling
- `.kiro/` — Kiro steering and notes

## Important Boundaries
- **AI video/image generation features belong to Parachute/Gekko (a separate app), NOT MyChannel.** Do not add generative AI media features here.
- The platform handles **real money** (wagers, escrow, payouts). Treat anything touching money, wagers, KYC, or payouts as high-risk — see the compliance steering.

## Domain
- Live web: https://mychannel.live
- Deep link scheme: `mychannel://`

## Working Style
This repo is large and has heavy historical doc clutter (many `*.md` status reports and `._*` AppleDouble files). When in doubt, read the current state of files rather than trusting the many "COMPLETE"/"FINAL" markdown reports — they are often outdated snapshots.
