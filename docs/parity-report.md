# MyChannel YouTube Parity – Gap Report (v1)

This document scores product/tech parity versus YouTube, identifies gaps, and assigns priorities.

## Legend
- PASS: implemented and integrated
- PARTIAL: present but needs expansion or hardening
- MISS: not present
- P0: must-have for parity/launch blockers
- P1: important for parity or growth
- P2: nice-to-have

## Summary Table

| Area | Capability | Status | Priority | Notes/Actions |
|---|---|---|---|---|
| Watch | HLS ABR, resume, background, PiP, mini-player | PARTIAL | P0 | HLS player present; persist resume position; PiP + DVR tracking TODO |
| Watch | Chapters, captions (VTT/SRT), dubs, speed control | MISS | P0 | Add captions/dubs Storage + player UI; speed verify/enable |
| Watch | Shorts vertical feed (endless, autoplay chains) | PARTIAL | P0 | Stub exists; connect to Firestore shorts + prefetch |
| Live | LL‑HLS, chat, reactions, DVR, replay, premieres | MISS | P0 | Transcoder templates + ingest; chat presence; countdown/premieres |
| Discovery | Home personalized, Trending, Explore hubs | PARTIAL | P1 | Basic feed; add ranking pipeline + Explore hubs |
| Search | Typos, filters, suggestions/autocomplete | MISS | P1 | Managed search (Algolia/OpenSearch) + facets |
| Subs/Notif | Subscriptions feed, push & in‑app inbox | PARTIAL | P0 | Subs persisted; build feeds + inbox UI; FCM topics |
| Localization | i18n locales, region policies | MISS | P1 | Remote Config + localized metadata + policy blocks |
| Channel | Tabs: Home/Videos/Shorts/Playlists/Community/About | PARTIAL | P0 | Views exist; polish Shorts/Community/About |
| Upload | Metadata, thumbs, schedule, visibility, tags, rating | PARTIAL | P0 | Add schedule/premieres + content rating flags |
| Playlists | Public/unlisted/private; series | PARTIAL | P1 | Firestore playlists live; add unlisted/private + series |
| Comments | Threads, mentions, moderation | PARTIAL | P0 | Live comments + hydration; add threads, pin, mod tools |
| Studio | Analytics (views, retention, CTR, RPM) | MISS | P0 | GA4→BQ export + dashboards |
| Monetization | Ads toggles, tips, memberships, PPV | MISS | P0 | Stripe Connect, tips/memberships, PPV & statements |
| Ads | Pre/mid/post, VMAP, OpenRTB, OMID, caps | MISS | P0 | Scaffold OpenRTB + VMAP; Ad Manager; viewability |
| Policy | AI moderation, DMCA, fingerprinting, age‑gate | MISS | P0 | ChannelShield queues & DMCA workflow |
| Growth | ASO, referrals, review gating, push drips | PARTIAL | P1 | ChannelBoost/ChannelMind rollout |
| Ops | Synthetics, SLOs, DR drills, guardrails | MISS | P1 | Doctor runbooks + Monitoring dashboards |

## P0 Backlog (near‑term)
1. HLS parity: resume position, PiP, watch progress sync
2. Captions/dubs pipeline: Storage + track switching in player
3. Shorts feed: Firestore shorts + prefetch/autoplay
4. Subscriptions and notifications inbox + FCM topics per channel
5. Upload: schedule/premieres + content rating/policy flags
6. Comments: threads, moderation (flag/ban), mentions notify
7. Studio analytics: GA4→BigQuery export + dashboards
8. Monetization: Stripe Connect (tips, memberships, PPV) + statements
9. Ads: VMAP, Ad Manager, OpenRTB service (MVP) + viewability
10. Policy: moderation queues + DMCA flow

## Notes
- See /firebase for rules, indexes, and Storage rules.
- See /functions for triggers and HTTP endpoints.
- See /infra/terraform for GCP provisioning (WIP).

## Visual Blueprint (Mermaid Mindmap)

Paste into a Mermaid-compatible viewer or view via GitHub Pages index once published.

```mermaid
mindmap
  root((Parity: MyChannel vs YouTube))
    iOS App
      Watch Experience
        HLS/DASH ABR(PASS)
        Resume position(PASS)
        Captions/Subtitles (VTT)(PARTIAL)
        Multilingual dubs(PARTIAL)
        Speed control(PASS)
        PiP/Background audio(PASS)
        Miniplayer(PARTIAL)
        Chapters editor(MISS)
        Live: LL-HLS, chat, DVR(MISS)
      Discovery & Ranking
        Home personalized(PARTIAL)
        Trending/Explore(PARTIAL)
        Topic hubs/Hashtags(PARTIAL)
        Search filters/autocomplete(MISS)
        Subscriptions feed(PASS)
        Notifications inbox(PARTIAL)
        Watch history & up next(PARTIAL)
        Localization (lang/region)(PARTIAL)
      Creator Tools
        Upload (metadata, thumbnails)(PASS)
        Schedule/visibility(PARTIAL)
        Playlists(PASS)
        Comments threads(PARTIAL)
        Community posts(MISS)
        Studio analytics(MISS)
      Monetization
        Tips(Test mode)(PARTIAL)
        Memberships toggles(MISS)
        Ads toggles per video(PARTIAL)
      Platform
        Universal Links(AASA)(PASS)
        Review gating stub(PASS)
        Accessibility/Dark mode(PASS)
    Backend (GCP/Firebase)
      Content Pipeline
        Upload svc (GCS signed URLs)(PASS)
        Transcoder templates(HLS ladders)(PASS)
        Thumbs/sprites(MISS)
        CDN signed URLs(PASS)
        DRM hooks(TODO)
      Data
        Firestore schemas/rules(PASS)
        Composite indexes(PASS)
        Storage rules (avatars,banners,videos,captions,dubs)(PASS)
        Functions 2nd gen (triggers/http)(PARTIAL)
        BigQuery datasets/tables(PASS)
      Auth/Security
        Firebase Auth + custom claims(PARTIAL)
        App Check(MISS)
        Cloud Armor (WAF)(PARTIAL)
        Rate limits/CORS(PARTIAL)
      Analytics
        GA4 mapping stub(PARTIAL)
        BigQuery export enabled(TODO)
        Performance/Crashlytics(PARTIAL)
    Ads & Brand Safety
      Ad Serving
        VMAP endpoint(PARTIAL)
        OpenRTB stub(PARTIAL)
        OMID viewability(TODO)
        Frequency caps(TODO)
      Compliance
        app-ads.txt stub(PASS)
        SKAdNetwork IDs(PARTIAL)
      Brand Safety
        ChannelShield moderation queues(PARTIAL)
        Copyright (DMCA intake)(PARTIAL)
        Fingerprinting (PDQ/VPDQ/WAV)(TODO)
    Growth
      ChannelMind/Boost
        ASO rotation(TODO)
        Referrals (links, anti-fraud)(PARTIAL)
        Review prompts gating(PASS)
        Localization(Partially planned)
        Drip notifications(TODO)
      Dashboards
        Studio KPIs(MISS)
        Monitoring dashboards(TODO)
    Operations
      CI/CD
        GitHub Actions(Deploy rules/functions)(PASS)
      Terraform
        Cloud Run/PubSub/Scheduler/Transcoder/CDN/Secrets(PASS)
        IAM least privilege(PARTIAL)
      SRE
        Alerts (5xx,p95)(PASS)
        Doctor synthetics(PASS)
        Runbooks (incident/DMCA/cost/DR)(PASS)
```
