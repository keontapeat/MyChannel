# Phase 86 — Android Parity Push

**Status:** ⬜ pending · **Owner:** TBD · **Target:** 2 quarters of dedicated Android work

## Goal
Feature-complete Android app at parity with the iOS app. This is a net-new build that reuses the existing Firebase backend + Cloud Run ML fleet.

## Stack
- **Language:** Kotlin 2.x
- **UI:** Jetpack Compose (Material 3)
- **Player:** Media3 ExoPlayer (HLS adaptive + FairPlay-equivalent Widevine L1)
- **Billing:** Google Play Billing Library 7
- **DI:** Hilt
- **Networking:** Retrofit + OkHttp + kotlinx.serialization
- **Reactive:** Coroutines + Flow
- **Build:** Gradle KTS + Version Catalog
- **CI:** GitHub Actions → Firebase App Distribution → Play Console

## Scope — MUST have on day 1
- [ ] Firebase Auth (Google, Apple-via-web, Email/Password)
- [ ] Home feed / Shorts feed / Subscriptions feed
- [ ] Video detail + comments + likes
- [ ] Live streaming playback
- [ ] Creator Studio (upload, analytics, edit)
- [ ] Push notifications (FCM)
- [ ] IAP via Google Play Billing — mirror of StoreKit products
- [ ] Deep links via App Links
- [ ] Dark mode
- [ ] 20 locales at parity

## Out of scope for day 1
- Android TV (Phase 87), Vision Pro (Phase 90)
- Podcast Mode, Watch Parties — add later

## Backend wiring
All Cloud Run agents are reachable via the same `agentProxy` callable. No new backend required except:
- [ ] Android-specific Universal Links / App Links config in `apple-app-site-association` sibling file
- [ ] FCM topic routing for push categories

## Milestones
| Week | Deliverable |
|------|-------------|
| 1–2  | Project skeleton, Firebase init, auth, theme |
| 3–4  | Home feed + player |
| 5–6  | Shorts feed + subscriptions |
| 7–8  | Video detail, comments, likes |
| 9–10 | Creator Studio upload + basic analytics |
| 11–12 | Push, billing, deep links |
| 13   | Localization pass (20 locales) |
| 14   | Beta on Play Store internal track |
| 15–16 | Closed beta + bugfix |

## Success metrics
- Crash-free sessions ≥ 99.7%
- Cold start < 1.5s on Pixel 6a
- D1 retention within 5% of iOS baseline
