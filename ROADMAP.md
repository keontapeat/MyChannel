# MyChannel — 100-Phase Deep Roadmap

Status legend: ✅ done · 🟡 in-progress · ⬜ pending

Tracking doc for the next ~2 years of MyChannel development. Organized into 10 waves of 5 phases each. Each phase ≈ 1–2 weeks of focused work.

---

## 🌊 Wave 1: Ship & Stabilize v1.0 (Phases 1–5)

- ✅ **Phase 1 — App Store Approval Lockdown**
  - ✅ SIWA iPad fix (Guideline 2.1(a)) using native `SignInWithAppleButton`
  - ⬜ Archive + resubmit 438e47dd
  - ⬜ TestFlight external testing group (100 users)
- 🟡 **Phase 2 — Crash-Free Telemetry**
  - ✅ Firebase Crashlytics present (verified)
  - ⬜ Sentry integration
  - ⬜ Real-time alert rules (crash-rate >0.5%)
  - ⬜ Top-10 crashes weekly review doc
- 🟡 **Phase 3 — Cold-Start Performance Pass**
  - ✅ LazyServiceManager audited
  - ⬜ Instruments profile: target <1.2s cold launch iPhone 12
  - ⬜ Move non-critical init off main thread
- ⬜ **Phase 4 — Network Resilience Layer**
  - Offline write queue for likes/comments/uploads
  - Exponential backoff retry wrapper
  - `URLSessionConfiguration.background` for all uploads
- ⬜ **Phase 5 — Memory Audit**
  - VideoDetailView retain cycle check
  - AVPlayer cleanup on dismiss
  - Image cache cap: 100MB
  - Target: <200MB steady-state

## 🌊 Wave 2: Creator Economy Foundation (Phases 6–10)

- ⬜ **Phase 6 — Creator Studio v2**: unified dashboard with live analytics, retention graphs, AI suggestions
- ⬜ **Phase 7 — Advanced Upload Pipeline**: tus resumable, multi-chunk parallel, bg continuation, HLS auto-gen
- ⬜ **Phase 8 — AI Thumbnail Studio**: wire `thumbnail-generator` Cloud Run, 4 variants + CTR prediction, A/B testing
- ⬜ **Phase 9 — Video Editor Suite**: trim/cut/merge, text overlays, filters, transitions (AVFoundation + Metal)
- ⬜ **Phase 10 — Captions & Translation**: Whisper auto-captions, 40+ language translation, editable SRT

## 🌊 Wave 3: Discovery & Recommendation Supremacy (Phases 11–15)

- 🟡 **Phase 11 — For You Feed v2**: wire `feed-personalization` + `top-rank-ml`, real-time reranking, diversity guarantees
- 🟡 **Phase 12 — Semantic Search v2**: wire `search-ranking`, vector embeddings, NL queries
- 🟡 **Phase 13 — Trending Engine**: wire `trending-ml`, geo + category + freshness decay
- ⬜ **Phase 14 — Hashtag & Topic Pages**: dynamic aggregation with top creators/videos/related tags
- ⬜ **Phase 15 — Watch History Intelligence**: Continue-watching with cross-device timestamp sync

## 🌊 Wave 4: Social Graph & Engagement (Phases 16–20)

- 🟡 **Phase 16 — Comments v2**: threaded replies, reactions, pinned, creator hearts, @mentions, `spam-detection` wired
- ⬜ **Phase 17 — Live Chat Hardening**: 100k concurrent, slow/sub-only mode, moderator tools, auto-mod
- ⬜ **Phase 18 — Community Tab**: text/poll/image/video posts (YouTube Community parity)
- ⬜ **Phase 19 — Stories/Status**: 24h ephemeral video/image on profile, viewer analytics (port from web)
- ⬜ **Phase 20 — DM/Messaging**: 1:1 + group, E2E Signal Protocol, video sharing, voice notes

## 🌊 Wave 5: Video Quality & Playback (Phases 21–25)

- ⬜ **Phase 21 — Adaptive HLS Everywhere**: 6 renditions (144p–4K), complexity-tuned ladder
- ⬜ **Phase 22 — Picture-in-Picture Perfection**: Now Playing, Dynamic Island, AirPlay 2, CarPlay
- ⬜ **Phase 23 — Offline Downloads v2**: DRM-ready FairPlay, quality picker, storage dashboard
- ⬜ **Phase 24 — Spatial Audio & Dolby Atmos**: AVAssetWriter Atmos pipeline, AirPods Pro playback
- 🟡 **Phase 25 — Video Chapters & Key Moments**: AI auto-chapters from transcripts, most-replayed heatmap
  - ✅ `AIChapterGeneratorService` wired to `super-ai-team` Cloud Run
  - ⬜ UI: chapter markers overlay on player scrubber
  - ⬜ Creator Studio: edit/regenerate chapters
  - ⬜ Most-replayed heatmap via watch-time telemetry

## 🌊 Wave 6: Live Streaming Empire (Phases 26–30)

- ⬜ **Phase 26 — Live Streaming iOS**: RTMP ingest, LL-HLS output, broadcaster app with camera switching
- ⬜ **Phase 27 — Live Multi-Guest**: up to 8 guests split-screen, WebRTC SFU, guest request flow
- ⬜ **Phase 28 — Live Shopping (Gated)**: product pins, live cart, Apple Pay checkout (behind `enableCreatorMonetization`)
- ⬜ **Phase 29 — Scheduled Streams & Premieres**: countdowns, reminders, waiting rooms with pre-show chat
- ⬜ **Phase 30 — Live Replay Intelligence**: auto-edit VOD into highlights via ML clip detection

## 🌊 Wave 7: AI-Native Features (Phases 31–35)

- 🟡 **Phase 31 — AI Agent Chatbot**: "Ask MyChannel" using `super-ai-team`, NL video search/Q&A/summaries
  - ✅ `AskMyChannelService` with conversation history + intents
  - ⬜ UI: floating chat sheet accessible from every tab
  - ⬜ Video-context Q&A (pass current video id for "explain this")
- ⬜ **Phase 32 — AI Video Summaries**: 30s auto-summaries, TL;DW button on long videos
- ⬜ **Phase 33 — AI Content Moderation v2**: `three-strike-review` + `sentiment-analysis` + `fraud-detection` + appeals
- 🟡 **Phase 34 — AI Creator Coach**: weekly personalized reports using `viral-prediction` + `watch-time-predictor`
  - ✅ `CreatorCoachService.generateWeeklyReport` wired to `creator-coach-ai`
  - ⬜ UI: Creator Studio tab with report card + action checklist
  - ⬜ Push notification every Monday 9am local
- ⬜ **Phase 35 — AI Voice Clone Dubbing**: 20-language publishing in creator's own voice

## 🌊 Wave 8: Monetization Unlock (Phases 36–40)

*Flip `enableSubscriptions` / `enableTipping` / `enableCreatorMonetization` to `true` — requires IAP review.*

- ⬜ **Phase 36 — MyChannel Plus+ Launch**: activate 2 ready IAP products (monthly $4.99 / annual $49.99)
- ⬜ **Phase 37 — Channel Memberships**: per-creator tiered IAP, members-only content, badges
- ⬜ **Phase 38 — Super Thanks (IAP)**: one-time tips via Apple IAP only (no Stripe)
- ⬜ **Phase 39 — Ads SDK**: pre/mid/bumper ads, `rtb-bidding-predictor` yield, creator revenue dashboard
- ⬜ **Phase 40 — Brand Deals Marketplace**: creator↔brand matching, FTC-compliant disclosures

## 🌊 Wave 9: Platform Expansion (Phases 41–45)

- ⬜ **Phase 41 — iPad-Optimized UI**: sidebar nav, multi-column, drag-drop uploads, Pencil in editor, Stage Manager
- ⬜ **Phase 42 — Apple TV App**: tvOS target, focus engine, 4K HDR, AirPlay receiver
- ⬜ **Phase 43 — macOS Catalyst**: native-feel Mac app, menu-bar mini-player, multi-window
- ⬜ **Phase 44 — Apple Watch Companion**: Now Playing, notifications, quick like/comment, live alerts
- ⬜ **Phase 45 — Vision Pro Immersive**: visionOS app, 180°/360°/spatial video, shared viewing rooms

## 🌊 Wave 10: Scale, Infra & Moat (Phases 46–50)

- 🟡 **Phase 46 — Gateway Auth Hardening**: fix `services/gateway` JWT enforcement, mTLS between services, per-tier rate limits
- ⬜ **Phase 47 — Backend Completeness**: finish stubs in `services/search`, `services/moderation`, `services/creator`, `services/rights`, `services/ingest`, `services/live-control`
- ⬜ **Phase 48 — Global CDN & Edge**: Cloudflare Stream + Fastly, edge transcoding, <100ms TTFB worldwide
- ⬜ **Phase 49 — Data Warehouse & ML Feedback Loop**: BigQuery event pipeline, weekly model retrain on real engagement
- ⬜ **Phase 50 — Trust & Safety Suite**: age verification, parental controls, COPPA Kids mode, transparency reports, LE portal

---

---

# MyChannel — Deep Roadmap II (Phases 51–100)

Continuation after v1.0 ships. 10 more waves, each ~5 phases. Assumes Phases 1–50 landed; these deepen the moat.

## 🌊 Wave 11: Post-Launch Growth Engine (Phases 51–55)

- ✅ **Phase 51 — Referral & Invite Loop**: `ReferralService.swift` — invite codes, deep links, K-factor dashboard, `referral-create` agent
- ✅ **Phase 52 — Onboarding A/B Framework**: `OnboardingExperimentService.swift` — Remote Config variants, deterministic bucketing, D1/D7/D30 activation
- ✅ **Phase 53 — Push Notification Intelligence**: `SendTimeOptimizationService.swift` — per-user ML send-time, quiet hours, `notification-timing` agent
- ✅ **Phase 54 — Email/SMS Lifecycle**: `LifecycleMessagingService.swift` — 14 drip campaigns, `email-personalization` agent
- ✅ **Phase 55 — App Clips & Widgets**: `AppClipAndWidgetService.swift` — WidgetKit feeds, App Clip video preview, App Group handoff

## 🌊 Wave 12: Monetization Depth (Phases 56–60)

- ✅ **Phase 56 — Shoppable Video (IAP-safe path)**: `ShoppableVideoService.swift` — product tags, affiliate links (external browser), `shopping-ai-v2`
- ✅ **Phase 57 — Creator Fund v1**: `CreatorFundService.swift` — performance-based grants, eligibility, payout dashboard URL, `creator-fund-allocator`
- ✅ **Phase 58 — Ad Yield Optimization v2**: `AdYieldOptimizationService.swift` — header-bidding, floor pricing, brand-safety tiers, `rtb-bidding-predictor`
- ✅ **Phase 59 — Subscription Tiers**: `SubscriptionTiersService.swift` — Plus+ / Pro / Family tiers, StoreKit 2 entitlements
- ✅ **Phase 60 — Virtual Goods & Gifts (IAP)**: `VirtualGiftsService.swift` — StoreKit consumables, creator split via `virtual-gifts` agent

## 🌊 Wave 13: Global Scale & Localization (Phases 61–65)

- ✅ **Phase 61 — 40-Locale Launch**: `LocaleService.swift` — 40 `SupportedLocale` cases, RTL detection, UGC translation, `ai-translation` agent
- ✅ **Phase 62 — Regional Content Licensing**: `RegionalLicensingService.swift` — geo-blocking, availability windows, `regional-content-optimizer`
- ✅ **Phase 63 — Edge Compute Rollout**: `EdgeComputeService.swift` — Cloudflare Workers edge feed/trending, <50ms TTFB, CF-Cache-Status tracking
- ✅ **Phase 64 — Multi-Region Firestore + BigQuery**: `MultiRegionFirestoreConfig.swift` — us-central1 / eu-west1 / asia-northeast1 routing, BigQuery dataset map
- ✅ **Phase 65 — Currency & Tax**: `CurrencyTaxFXService.swift` — VAT/GST estimation, FX rates, StoreKit storefront currency, `tax-optimization-ai`

## 🌊 Wave 14: Creator Power Tools (Phases 66–70)

- ⬜ **Phase 66 — Multi-Track Video Editor** _(skipped — deferred)_
- ⬜ **Phase 67 — AI B-Roll Generator** _(skipped — deferred)_
- ✅ **Phase 68 — Podcast Mode**: `PodcastModeService.swift` — audio-only uploads, RSS, chapter gen, `podcast-ai` agent
- ✅ **Phase 69 — Collaborative Drafts**: `CollaborativeDraftsService.swift` — multi-editor roles, revisions, approval workflow, Firestore
- ✅ **Phase 70 — Creator API & Webhooks**: `PublicCreatorAPIService.swift` — OAuth2 clients, webhook endpoints, `developers.mychannel.live`

## 🌊 Wave 15: Trust, Safety & Compliance (Phases 71–75)

- ✅ **Phase 71 — Age Verification + COPPA Kids Mode**: `KidsModeService.swift` — sandboxed profiles, PIN gate, `kids-ai-v2`, daily watch budget
- ✅ **Phase 72 — DSA / Online Safety Act Compliance**: `DSAComplianceService.swift` — Statement of Reasons, trusted flaggers, transparency reports
- ✅ **Phase 73 — Deepfake & C2PA Provenance**: `C2PAProvenanceService.swift` — manifest signing/verification, `deepfake-detector-ai`
- ✅ **Phase 74 — Copyright Match v2**: `CopyrightMatchV2Service.swift` — Chromaprint + pHash fingerprinting, claim/dispute flow, revenue hold
- ✅ **Phase 75 — Law Enforcement Portal**: `LEPortalService.swift` — gag-order-aware notices, `transparency.mychannel.live`

## 🌊 Wave 16: AI-Native UX (Phases 76–80)

- ✅ **Phase 76 — Ambient Agent Layer**: `AmbientAgentService.swift` — App Intents, `ResumeLastVideoIntent`, `autoplay-intelligence` agent
- ✅ **Phase 77 — Conversational Search**: `ConversationalSearchService.swift` — multi-turn NL search, history, follow-ups, `super-ai-team`
- ✅ **Phase 78 — Personalized AI Host**: `AIHostService.swift` — nightly digest, voice catalog, avatar generation, `ai-avatar-v2`
- ✅ **Phase 79 — Smart Clipping**: `SmartClippingService.swift` — highlight detection, one-tap Flick publish, `shorts-optimizer`
- ✅ **Phase 80 — Generative Thumbnails & Titles**: `GenerativeThumbnailService.swift` — CTR-ranked variants, A/B apply, `thumbnail-gen-v2`

## 🌊 Wave 17: Gaming, Sports & Live Verticals (Phases 81–85)

- ✅ **Phase 81 — Esports Hub**: `EsportsHubService.swift` — tournaments, brackets, live stats, `esports-ai` + `mychannel-tournament-bracket`
- ✅ **Phase 82 — Sports Live Cards**: `SportsLiveCardsService.swift` — NBA/NFL/UFC/Olympics real-time overlays, rights-gated
- ✅ **Phase 83 — Game Clip Capture SDK**: `GameClipSDKService.swift` — reserve/upload/finalize flow, `clips-ingest.mychannel.live`
- ✅ **Phase 84 — Watch Parties**: `WatchPartyService.swift` — SharePlay `GroupActivity` + Firestore fallback, reactions
- ✅ **Phase 85 — Interactive Live (Polls/Predictions/Trivia)**: `InteractiveLiveService.swift` — overlays, answer tallying, `live-stream-optimizer`

## 🌊 Wave 18: Platforms II — Everywhere MyChannel (Phases 86–90)

- ✅ **Phase 86 — Android Parity Push**: `docs/phase-86-android-parity-plan.md` — Kotlin, Compose, ExoPlayer, Play Billing, 16-week milestones
- ✅ **Phase 87 — Android TV & Google TV**: `docs/phase-87-android-tv-plan.md` — Compose TV, 4K HDR, D-pad, QR pairing
- ✅ **Phase 88 — Web-v2 PWA Hardening**: `docs/phase-88-pwa-hardening-plan.md` — Workbox 7, offline shell, WebRTC live ingest
- ✅ **Phase 89 — Roku / Fire TV / Samsung Tizen**: `docs/phase-89-ctv-reference-apps-plan.md` — BrightScript, Tizen TypeScript, Fire TV APK
- ✅ **Phase 90 — Vision Pro v2**: `VisionProV2Service.swift` — co-watch rooms, spatial reactions, `vr-ar-ai-v2`

## 🌊 Wave 19: Infra Hard-Mode (Phases 91–95)

- ✅ **Phase 91 — Chaos Engineering**: `docs/phase-91-chaos-engineering.md` — game-days, Gremlin, Toxiproxy, DR runbooks
- ✅ **Phase 92 — Event-Sourced Core**: `docs/phase-92-event-sourcing.md` — Pub/Sub backbone, Avro schema, dual-write migration
- ✅ **Phase 93 — Cost Control & FinOps**: `FinOpsService.swift` — spend by feature, anomaly detection, `auto-scaler` idle-shutdown
- ✅ **Phase 94 — ML Platform v2**: `docs/phase-94-ml-platform-v2.md` — Vertex Feature Store, canary policy, drift detection
- ✅ **Phase 95 — Zero-Trust Security**: `docs/phase-95-zero-trust-security.md` — Workload Identity, mTLS, Binary Auth, SBOM + SLSA-3

## 🌊 Wave 20: Moonshots & Moat (Phases 96–100)

- ✅ **Phase 96 — MyChannel Studios (Originals)**: `MyChannelOriginalsService.swift` — exclusive catalog, Pro-tier gate, episode tracking
- ✅ **Phase 97 — Creator Accelerator Program**: `CreatorAcceleratorService.swift` — cohort applications, milestones, BigQuery ROI tracking
- ✅ **Phase 98 — Passkey Authentication**: `PasskeyAuthService.swift` — FIDO2 WebAuthn, iCloud Keychain, `auth.mychannel.live`
- ✅ **Phase 99 — MyChannel Mini-App SDK**: `MiniAppSDKService.swift` — sandboxed WKWebView, JS bridge, permission model
- ✅ **Phase 100 — IPO-Ready Ops**: `IPOReadinessService.swift` — KPI snapshot, SOC 2 evidence, audit log export, `investors.mychannel.live`

---

## 📋 Cross-Cutting Tracks II (Phases 51–100)

- **Performance budgets**: per-screen TTI, FPS, memory SLOs enforced in CI
- **Accessibility**: reach AAA on 20 core screens by Phase 75
- **Localization**: 40 → 60 locales by Phase 100
- **Testing**: 85% unit + UI coverage, contract tests for every Cloud Run service
- **Design system**: ship `MyChannelUI` Swift package + web Tailwind preset to npm
- **Docs**: public developer portal at `developers.mychannel.live` by Phase 70

---

## 📝 Session Log

**2026-04-23**
- Phase 1: SIWA iPad fix via native `SignInWithAppleButton` (4th attempt — root cause was dismiss-then-delay-then-controller pattern, now eliminated)
- Phase 25: `AIChapterGeneratorService` shipped
- Phase 31: `AskMyChannelService` shipped
- Phase 34: `CreatorCoachService` shipped
- Verified 244-service `CloudRunService` enum is comprehensive; existing integrations include `spamDetection` in comments, `feedPersonalization` in subscription feed, `viralPrediction`/`contentModeration`/`thumbnailGenerator` in `FlicksMLService`

---

## 📋 Cross-Cutting Tracks (Every Phase)

- **Accessibility**: VoiceOver pass, Dynamic Type, captions, reduced motion
- **Localization**: +5 locales per wave → 40 total by Phase 50
- **Testing**: 70% unit + UI coverage by Phase 25
- **Design System**: Consolidate `AppTheme` into shared Swift package
- **Docs**: ADRs for every architectural decision
