# MyChannel – Dev Context (Bulletproof Quick Start)

This file lets any new session pick up exactly where we left off. Keep it in the repo root.

## Environment
- Machine working dir: `/Users/keonta/Documents/MyChannel`
- Firebase CLI: `14.13.0`
- Firebase Project ID: `mychannel-ca26d`
- Active Hosting:
  - Default: `https://mychannel-ca26d.web.app`
  - Firebaseapp: `https://mychannel-ca26d.firebaseapp.com`
  - Custom: `https://mychannel.live` (primary)
- Node/JS runtime: vanilla Hosting (no SSR), static assets + `sw.js`

### Current platform architecture (2025‑08‑24)
- GCP Project: `mychannel-ca26d` (region `us-central1`)
- Terraform (infra/terraform) provisions:
  - Cloud Run services: `mychannel-upload`, `mychannel-transcode`, `mychannel-content`, `mychannel-events`
  - API Gateway: `mychannel-gw` (hostname will be output as `api_gateway_hostname`)
  - Pub/Sub topics: `events`, `media-ingest`, `video-features`
  - BigQuery: dataset `analytics`, tables `events`, `video_features`, `plays`, `impressions`, `likes`
  - Cloud Storage buckets: `mychannel-ingest` (uploads), `mychannel-public` (HLS/MPD), plus media bucket
  - Service account: `run-svc@mychannel-ca26d.iam.gserviceaccount.com` with required IAM on buckets/BQ/PubSub
- Deployed Cloud Run endpoints (direct):
  - Upload: `https://mychannel-upload-fkri6ifojq-uc.a.run.app/v1/uploads/signed-url`
  - Transcode: `https://mychannel-transcode-fkri6ifojq-uc.a.run.app/v1/transcode/ingest`
  - Content: `https://mychannel-content-fkri6ifojq-uc.a.run.app/v1/feed/home`
  - Events: `https://mychannel-events-fkri6ifojq-uc.a.run.app/v1/events`
- API Gateway: `mychannel-gw-1l792fzz.uc.gateway.dev` (OpenAPI deployed; web currently calls Cloud Run direct; we can switch to Gateway when ready)

### Recent UI and Web App updates
- Profile Settings modal: dark mode toggle and autoplay toggle (persisted in localStorage)
- Dark Mode: CSS variables + `data-theme` support; enabled only via Settings
- Live TV: “See All” full‑screen modal with tabs/search/view toggle; fixed modal open/close and sizing
- Movie Detail: full‑screen modal with hero, metadata, actions, synopsis, chips
- Trending “See All”: styled ranked list with correct alignment/contrast
- Home cards: reverted to black backgrounds; removed duplicate FEATURED text and view count
- Video thumbnails/autoplay: IntersectionObserver + SW adjustments (no caching for HLS/MP4/Range requests)
- PWA: service worker caches `site.webmanifest`; media requests bypass cache for smooth playback
- Events: `trackUserEngagement()` now POSTs to Events service
- Uploads: Upload modal now requests a signed URL from Upload service and PUTs file directly (placeholder flow)
- Feed: Home feed fetch points to Content service with fallback to TMDB if unavailable

## Authorized domains (Auth)
Ensure these exist in Firebase Console → Authentication → Settings:
- `mychannel.live`, `www.mychannel.live`
- `mychannel-ca26d.web.app`, `mychannel-ca26d.firebaseapp.com`

Google Sign‑In works via popup; Apple button present but disabled behind flag.

## Commands
- Live deploy (Hosting only):
  ```bash
  firebase deploy --only hosting --non-interactive
  ```
- Preview channel deploy:
  ```bash
  firebase hosting:channel:deploy preview-$(date +%Y%m%d-%H%M%S) --non-interactive
  ```
- Confirm active project:
  ```bash
  firebase use | cat
  ```

### Functions deploy (2nd‑gen Python 3.12)
```bash
# Ensure local venv exists for CLI analysis (optional but faster):
cd functions
/usr/local/bin/python3.12 -m venv venv
./venv/bin/python -m pip install -U pip
./venv/bin/pip install -r requirements.txt

# Deploy all functions
cd ..
firebase deploy --only functions --non-interactive
```

### Terraform (Infra) – provision/update Cloud Run, buckets, Pub/Sub, BigQuery, API Gateway
```bash
cd MyChannel/infra/terraform
terraform init -lock=false -upgrade
terraform apply -auto-approve -lock=false \
  -var "project_id=mychannel-ca26d" -var "region=us-central1" \
  -var "media_bucket_name=mychannel-media" \
  -var "ingest_bucket_name=mychannel-ingest" \
  -var "public_bucket_name=mychannel-public"

# Outputs include api_gateway_hostname and service URLs
terraform output -no-color | cat
```

### Cloud Build (images for each service)
```bash
# From repo root
gcloud builds submit --config services/cloudbuild-upload.yaml services
gcloud builds submit --config services/cloudbuild-transcode.yaml services
gcloud builds submit --config services/cloudbuild-content.yaml services
gcloud builds submit --config services/cloudbuild-events.yaml services
```

### Fix Hosting → Functions 403 (grant Cloud Run invoker)
If `/api/*` routes return 403, grant Run invoker to Firebase Hosting identities:
```bash
PROJECT=mychannel-ca26d
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')
for svc in tmdb-trending tmdb-popular tmdb-free-ads tmdb-details; do
  gcloud run services add-iam-policy-binding "$svc" \
    --region=us-central1 \
    --member=serviceAccount:firebase-app-hosting-compute@${PROJECT}.iam.gserviceaccount.com \
    --role=roles/run.invoker
  gcloud run services add-iam-policy-binding "$svc" \
    --region=us-central1 \
    --member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-firebaseapphosting.iam.gserviceaccount.com \
    --role=roles/run.invoker
  gcloud run services add-iam-policy-binding "$svc" \
    --region=us-central1 \
    --member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-firebase.iam.gserviceaccount.com \
    --role=roles/run.invoker
done
```
Then redeploy Hosting to refresh rewrites if changed:
```bash
firebase deploy --only hosting --non-interactive
```

## Custom domains & post-deploy verification (run every deploy)
- Verify Hosting site + DNS for `mychannel.live` and `www.mychannel.live`:
  ```bash
  firebase hosting:sites:list | cat
  dig +short mychannel.live CNAME; dig +short mychannel.live A; dig +short www.mychannel.live CNAME; dig +short www.mychannel.live A | cat
  ```
- Compare headers and SW on custom vs default domain (ensures both point to latest):
  ```bash
  curl -sI https://mychannel.live/index.html | cat
  curl -sI https://mychannel-ca26d.web.app/index.html | cat
  curl -s https://mychannel.live/sw.js | sed -n '1,12p'
  curl -s https://mychannel-ca26d.web.app/sw.js | sed -n '1,12p'
  curl -s https://mychannel.live | grep -n 'sw.js?v=' | cat
  ```
- If SW is stale anywhere:
  1) Bump versions in `sw.js` (e.g., `mychannel-vX.Y.Z`, `static-vN`, `dynamic-vN`)
  2) Update the SW registration in `index.html` (e.g., `/sw.js?v=NNN`)
  3) Redeploy Hosting with the live deploy command above
  4) Optional: Instruct hard refresh or DevTools → Application → Service Workers → "Update on reload"

## Post-deploy checklist (fast path)
- Custom domains (`mychannel.live`, `www.mychannel.live`) return 200 for `/` and `/index.html`
- Cache headers for HTML are `no-store, max-age=0` (from `firebase.json`)
- Service worker shows expected version at `/sw.js` on both custom and default domains
- `index.html` registers SW with the latest `?v=` cache-buster
- Comments UI renders via `openVideoDetail()`; no stray inline JS under Comments
- Auth authorized domains include all four: `mychannel.live`, `www.mychannel.live`, `mychannel-ca26d.web.app`, `mychannel-ca26d.firebaseapp.com`
- `robots.txt`, `sitemap.xml`, `manifest.json` accessible

## Hosting/Cache
- `firebase.json` headers:
  - `**/*.js` and `**/*.css`: `max-age=31536000`
  - `**/*.html` and `/sw.js`: `no-store`
- `index.html` registers SW with cache‑buster: `/sw.js?v=…`
- If Safari shows stale UI: open `mychannel.live/sw.js` and verify version, then reload.

## App behavior snapshot
- Banner (welcome):
  - Visible by default for guests
  - Hides on login or X (7‑day dismissal)
  - Safari‑safe (class‑based visibility, no flicker)
- Auth:
  - Google: popup first; redirect path removed to avoid storage partition issues
  - Apple: present but gated by `APPLE_SIGNIN_ENABLED=false`
- Notifications:
  - On first login: local welcome notification in bell dropdown; badge shows when items exist
- Comments:
  - Rendered via JS inside `openVideoDetail()` only. No inline scripts should appear under Comments
- Profile header:
  - Values (subscribers/videos/views) pulled from `users/{uid}`; default to `0`
  - Avatar updates immediately across header + stories
- Stories:
  - Filtered to `users/{uid}.following` + own story
  - Refresh hook runs after avatar change and on load

## Endpoints quick reference (current)
- Upload Signed URL (Cloud Run): `https://mychannel-upload-fkri6ifojq-uc.a.run.app/v1/uploads/signed-url`
- Ingest Transcode webhook (Cloud Run): `https://mychannel-transcode-fkri6ifojq-uc.a.run.app/v1/transcode/ingest`
- Content Home Feed (Cloud Run): `https://mychannel-content-fkri6ifojq-uc.a.run.app/v1/feed/home`
- Events Ingest (Cloud Run): `https://mychannel-events-fkri6ifojq-uc.a.run.app/v1/events`
- API Gateway host: `mychannel-gw-1l792fzz.uc.gateway.dev` (switch frontend to this when stabilized)

## Troubleshooting
- Banner flicker (Safari):
  - Ensure `.promo-banner` uses class toggle `.hidden`; do not set inline `display` elsewhere
- Comments showing code text:
  - Verify there is no inline script between Comments and Suggested; logic must live inside `openVideoDetail()`
- Stuck cache:
  - Clear site data for `mychannel.live` or open in a new tab
- Verify deploy took effect:
  ```bash
  curl -s https://mychannel.live | grep -n "DEV_CONTEXT" -n | cat
  ```

## Feature flags / switches
- `APPLE_SIGNIN_ENABLED=false` (flip to true once Apple Service ID + return URL configured)
- SW version in `sw.js` (bump `mychannel-vX.Y.Z` when changing caching strategy)

### One-liners for quick verification
```bash
curl -sI https://mychannel.live/index.html | cat
curl -s https://mychannel.live/sw.js | sed -n '1,12p'
curl -s https://mychannel.live | grep -n 'sw.js?v=' | cat
```

## What we’ve done so far (high‑level)
- Deployed four Cloud Run services (upload, transcode, content, events) with CI/CD via Cloud Build
- Provisioned Pub/Sub topics and BigQuery dataset/tables for analytics
- Created API Gateway and OpenAPI routing to services
- Implemented PWA fixes (SW caching rules) and multiple UI features (dark mode via settings, Live TV/Movie Detail/Trending modals, home card styling)
- Integrated web analytics posting to Events service
- Implemented placeholder signed upload flow (request signed URL + direct PUT)
- Updated web feed to use Content service with resilient fallback

## Remaining work to reach 100k+ DAU and creator uploads (web + iOS)
- Web
  - Switch all service calls through API Gateway hostname (central auth, quotas, logging)
  - Signed URL flow: real signer using GCS v4 signatures; auth via Firebase JWT
  - Content service: persist video metadata; paginate feeds; search endpoints
  - Events service: publish to Pub/Sub; add batching; backoff/retry; schema validation
  - Observability: Cloud Logging structured logs; Metrics; Error Reporting; Trace; uptime checks
  - Security: CORS hardening, CSP, rate limiting (API Gateway or Cloud Armor), WAF rules
  - Performance: CDN for `mychannel-public` HLS; Cache-Control tuning; image proxy/thumbnails
  - Data: write streams to BigQuery (Pub/Sub → BQ direct or Dataflow); partitioned tables
  - AI: connect Vertex pipelines for ranking and content safety; feature extraction
- iOS
  - Integrate Events SDK to POST to `/v1/events` (Gateway)
  - Implement signed upload flow (request URL → PUT file → notify content service)
  - Playback: HLS from `mychannel-public` with fairplay readiness (future)
- Backend/Infra
  - Transcoder integration: GCP Transcoder API pipeline + webhooks → publish assets to `mychannel-public`
  - Storage lifecycle/CORS finalization; signed cookies/tokens for private variants if needed
  - Autoscaling policies on Cloud Run; min instances for p95 latency; health checks
  - Cost controls: budget alerts; per‑service concurrency tuning
  - Multi‑AZ/region strategy & backups; DR runbook

## Scale‑readiness checklist
- Auth: Verify Firebase JWT in API Gateway or per‑service middleware
- Quotas: Configure API Gateway usage plans and per‑IP throttles
- Logging/Monitoring: Dashboard with error rates, latency, 99th percentile
- Data governance: Retention policies (GCS/BQ), PII handling, exports
- Privacy/Security: Key rotation, Secret Manager, least‑privilege IAM, audit logs
- Load testing: k6/Gatling scenarios for upload, feed, events; validate autoscaling
- SLOs/alerts: e.g., p95 < 300ms events ingest, 99.9% uptime, oncall

## One‑liner handoff for new chats
Say: “Load DEV_CONTEXT.md and resume. Project `mychannel-ca26d` (us‑central1). Cloud Run services (upload/transcode/content/events) + API Gateway are deployed via Terraform. Web posts analytics to Events and uses Content for home feed; upload uses placeholder signed URL. Next: route web through API Gateway, finalize signed URLs, wire Events→Pub/Sub→BigQuery, and add iOS events/upload. After any web deploy, verify custom domains and SW version.”

This gives the assistant everything needed to continue without re‑configuration.
