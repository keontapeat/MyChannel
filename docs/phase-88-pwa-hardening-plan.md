# Phase 88 — Web-v2 PWA Hardening

**Status:** ⬜ pending · **Target file surface:** `web-v2/`, `public/`, `sw.js`, `manifest.json`

## Goal
Turn the existing web-v2 app into a first-class installable PWA with offline shell and WebRTC live ingest from the browser.

## Deliverables
- [ ] `manifest.json` audit (icons, shortcuts, handle_links, share_target)
- [ ] Upgrade `sw.js` to Workbox 7 with:
  - Offline app-shell precache
  - Runtime stale-while-revalidate for thumbnails
  - Network-first for `/api/*`
  - Background sync for likes/comments when offline
- [ ] Installability banner (beforeinstallprompt)
- [ ] Badging API for unread notifications
- [ ] Web Share Target API (accept shared videos into uploader)
- [ ] Media Session API (hardware media key support)
- [ ] Picture-in-Picture API wired everywhere
- [ ] WebRTC live ingest: MediaStream → MediaRecorder → WHIP to `services/live-control`
- [ ] Lighthouse PWA score 100/100
- [ ] Playwright test: install flow, offline playback, share target

## Browser matrix
- Chrome 124+ (desktop + Android)
- Safari 17.4+ (macOS + iOS Add-to-Home-Screen)
- Edge 124+
- Firefox 125+

## Non-goals
- Full desktop Electron wrapper (future, Phase 43 macOS Catalyst covers this)
