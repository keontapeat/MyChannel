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

## Next tasks (carryover)
- Implement full‑screen Flicks (Shorts‑style) viewer:
  - Vertical swipe through portrait videos; persistent controls; pull to dismiss
  - Preload next/prev; haptic on like; double‑tap to like
- Remove any residual inline code under Comments if observed on certain videos
- Wire real gallery upload for videos (Storage + Firestore metadata), with progress + retry

## One‑liner handoff for new chats
Say: “Load DEV_CONTEXT.md and resume. Deploy target is `mychannel-ca26d` (Firebase Hosting, CLI 14.13.0). After deploy, auto‑verify custom domains (`mychannel.live`, `www.mychannel.live`), compare headers and `/sw.js` on both domains, and bump SW + registration `?v=` if stale.”

This gives the assistant everything needed to continue without re‑configuration.
