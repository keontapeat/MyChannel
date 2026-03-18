---
description: MyChannel project rules for Windsurf AI coding assistant
---

# MyChannel Project Rules

## Project Architecture
- **Firebase Hosting frontend**: Vanilla JS + HTML/CSS — `index.html`, `public/` — live at `mychannel.live`
- **web-v2 frontend**: Next.js 14 (App Router, static export), TypeScript, Tailwind CSS, Video.js — in `web-v2/`
- **iOS App**: Swift/SwiftUI in `MyChannel/` directory
- **Firebase Functions**: Python 3.12 2nd-gen in `functions/`
- **Cloud Run services** (GCP project `mychannel-ca26d`, region `us-central1`): upload, transcode, content, events, auth, search, moderation, creator
- **API Gateway**: `mychannel-gw-1l792fzz.uc.gateway.dev` — web currently calls Cloud Run direct; migrate to Gateway when stabilized
- **Database**: Firestore + BigQuery (`analytics` dataset) + Pub/Sub topics: `events`, `media-ingest`, `video-features`
- **Storage**: Firebase Storage + GCS buckets `mychannel-ingest` (uploads), `mychannel-public` (HLS/MPD)
- **Infra**: Terraform in `infra/terraform`, CI/CD via GitHub Actions + Cloud Build
- Always confirm which platform (vanilla web, web-v2, iOS, Cloud Run service, Firebase Functions) before editing
- Never mix platform concerns in the same edit

## File Protection — CRITICAL
- NEVER delete any file without explicit user confirmation
- NEVER use `rm -rf` on any directory
- NEVER run `git reset --hard` or `git clean -fd` without approval
- NEVER overwrite existing files with the write tool — use edit/StrReplace instead
- NEVER delete Swift files, TypeScript files, config files (.json, .yaml, .yml), or Xcode project files
- Protected directories: `MyChannel/Core/`, `MyChannel/Features/`, `MyChannel/App/`, `MyChannel.xcodeproj/`, `web-v2/`, `services/`, `firebase/`, `.github/`
- Protected files: `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `.swiftlint.yml`, `web-v2/package.json`

## No New Markdown Files
- DO NOT create new `.md` files in the project root unless explicitly asked
- The root already has 300+ markdown docs — do not add to the clutter
- Use existing files or chat responses for documentation and summaries

## Firebase Safety
- NEVER deploy Firebase rules, indexes, or functions without explicit user approval
- NEVER modify `firestore.rules` or `storage.rules` without showing the diff first
- Always use `firebase deploy --only` with specific targets, never blind full deploys
- Firestore queries MUST always have `.limit()` — never unbounded queries (cost protection)
- Prefer batched writes over individual writes when updating multiple documents

## Coding Standards
- Do NOT add or remove comments or documentation unless explicitly asked
- Follow existing code style in every file — don't introduce new patterns without reason
- Prefer minimal, focused edits over rewrites
- Always read a file before editing it
- Preserve all existing imports — never remove them

## Image & Media URLs
- NEVER use `wikipedia.org` or `wikimedia.org` image URLs (blocked by CORS)
- NEVER use `.svg` URLs in Swift `AsyncImage` (not supported)
- Approved CDNs: `ytimg.com`, `image.tmdb.org`, `m.media-amazon.com`, `googleusercontent.com`, `cloudinary.com`, `cloudfront.net`, `akamaized.net`, `imgur.com`

## TMDB & Streaming APIs
- Always use free/ad-supported streaming sources: Tubi, Freevee, Roku Channel, Pluto TV, Plex
- Prefer modern high-profile titles over old public domain films
- TMDB API key is stored in `.ai_api_key` — never hardcode it in source files
- Never use paid streaming APIs (Netflix, Disney+, Prime Video premium endpoints)

## iOS Swift Standards
- Use spring animations for all interactive state changes (`response: 0.35, dampingFraction: 0.85`)
- Add haptic feedback: light for tab switches, medium for primary actions, warning for destructive actions
- Use `AnimatedStatItem` for numeric stats (count-up animation on appear)
- Always respect `reduceMotion` preference for accessibility
- Use `.drawingGroup()` for complex animated views in lists

## Web Frontend Standards
- Vanilla JS only in `index.html` and `public/` — no framework imports unless already present
- Always use the existing Firebase SDK version already loaded in the project
- Service worker (`sw.js`) handles offline caching — don't break its cache strategy
- Test changes against both desktop and mobile viewports

## Performance Rules
- Firestore: always paginate with cursors, never fetch entire collections
- Images: use lazy loading, always provide fallback URLs
- Avoid redundant Firebase reads — check if data is already in local state first
- Functions: keep Cloud Function cold start times low, avoid heavy imports at top level

## web-v2 Next.js Rules
- Framework: Next.js 14 App Router, static export (`output: 'export'`), deployed to Firebase Hosting from `out/`
- All dynamic routes MUST have `export async function generateStaticParams() { return []; }`
- Never put `'use client'` and `generateStaticParams` in the same file — split into server wrapper + client component
- Types folder must be `types/` NOT `@types/` (Next.js treats `@types` as a parallel route)
- Video.js error handlers must type `error` as `any` to avoid TS errors
- Swipeable `ref` must come AFTER the spread operator: `{...swipeHandlers} ref={containerRef}`
- Use `bg-[rgb(var(--color-background))]` pattern for theme-aware colors
- Mobile-first responsive: start with mobile classes, add `sm:`, `md:`, `lg:` breakpoints

## Service Worker Rules
- `sw.js` handles offline caching — never break its cache strategy
- HLS/MP4/Range requests must bypass SW cache for smooth playback
- When changing caching strategy, always bump the SW version (`mychannel-vX.Y.Z`) AND the registration query string in `index.html` (`/sw.js?v=NNN`)
- After any deploy, verify SW version matches on both `mychannel.live` and `mychannel-ca26d.web.app`

## Cloud Run & GCP Rules
- Cloud Run service endpoints are in `DEV_CONTEXT.md` — always reference before hardcoding URLs
- Never deploy Cloud Run services without using `gcloud builds submit` via the cloudbuild YAML configs in `services/`
- Never run `terraform apply` without explicit user approval — it provisions real GCP infrastructure
- API Gateway migration: don't switch frontend calls to Gateway until user explicitly asks
- Service account: `run-svc@mychannel-ca26d.iam.gserviceaccount.com` — never change IAM bindings without approval
- If Cloud Run returns 403, check Run Invoker grants for Firebase Hosting service accounts (see `DEV_CONTEXT.md`)

## CI/CD Rules
- GitHub Actions workflows are in `.github/workflows/` — never edit without approval
- Required secrets: `FIREBASE_TOKEN`, `GCP_WORKLOAD_IDP`, `GCP_DEPLOY_SA` — never expose or log these
- Hosting deploys on PR (preview channel) and `main` (live)
- Functions and Cloud Run deploy on `main` only
- Always use preview channel deploy for testing: `firebase hosting:channel:deploy preview-$(date +%Y%m%d-%H%M%S) --non-interactive`

## Post-Deploy Verification
- After every Hosting deploy, verify: both custom domains return 200, SW version matches, cache headers correct
- HTML/SW must have `no-store` cache headers; JS/CSS can have `max-age=31536000`
- Auth authorized domains must include all 4: `mychannel.live`, `www.mychannel.live`, `mychannel-ca26d.web.app`, `mychannel-ca26d.firebaseapp.com`
- Feature flag: `APPLE_SIGNIN_ENABLED=false` — do not flip to true without Apple Service ID configured

## Safety Commands
- Safe to run: `git status`, `git log`, `git diff`, `ls`, `cat`, `grep`, `find` (read-only), `curl -sI` (read-only)
- Requires approval: `git push`, `firebase deploy`, `npm install`, any `rm` command, `mv`, `gcloud builds submit`
- Never auto-run: `rm -rf`, `git reset --hard`, `find . -delete`, `git push --force`, `terraform apply`
