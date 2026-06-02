---
inclusion: fileMatch
fileMatchPattern: ['web-v2/**', 'web/**', '**/*.tsx', '**/*.jsx']
---

# Web Standards (Next.js 14 + TypeScript)

Applies when working in `web-v2/` (primary) or `web/` (legacy), or any `.tsx`/`.jsx` file.

## Stack
- Next.js 14 (App Router), TypeScript, Tailwind CSS, Video.js (HLS), Firebase (Auth/Firestore/Storage/RTDB), Vertex AI.
- **Deployed as a static export to Firebase Hosting** (`output: 'export'`, `images.unoptimized: true`). This constraint drives several rules below.

## Project Structure (`web-v2/`)
- `app/` — routes/pages (App Router)
- `components/` — `layout/`, `video/`, `flicks/`, `live/`, `comments/`
- `lib/` — `firebase/`, `vertex-ai/`, `utils/`
- `services/` — business logic incl. `agi-agents/`
- `types/` — TypeScript types. **Use `types/`, never `@types/`** (an `@types` folder breaks App Router parallel routes).

## Server vs Client Components
- Default to Server Components. Add `'use client'` only when you need state, effects, event handlers, browser APIs, or client-only libraries.
- **Every dynamic route must export `generateStaticParams()`** (return `[]` for client-side routing) because of static export.
- A page that needs `generateStaticParams()` cannot be a client component — split into a server page wrapper that renders a `'use client'` child.

## Firebase (web)
- Initialize as a singleton, guard with `typeof window !== 'undefined'`.
- Use `uploadBytesResumable` with progress callbacks for uploads.
- Only `NEXT_PUBLIC_*` env vars reach the client — never put server-only secrets there.

## Video.js
- Type error handlers as `any` (`player.on('error', (error: any) => ...)`).
- Use `(player as any).liveTracker` for live latency. Always `player.dispose()` on cleanup.

## Tailwind / Theme
- YouTube-style theme via CSS variables in `globals.css` (`--color-*`), with `.dark` overrides.
- Mobile-first responsive: base styles for mobile, then `sm:`/`md:`/`lg:` breakpoints. Use `LazyVStack`-equivalent patterns (lazy loading, pagination) for long grids.

## Common Pitfalls (from prior fixes)
- Dynamic route missing `generateStaticParams()` → build fails. Add it.
- `'use client'` + `generateStaticParams()` in the same file → split server/client.
- `react-swipeable`: put `ref` AFTER the `{...swipeHandlers}` spread.
- Don't reintroduce an `@types/` folder in `app/`.

## Quality
- Run `npm run lint` before considering web work done. Run `npm run build` to catch static-export errors.
- Don't start `npm run dev` as a blocking command in the agent — ask the user to run dev/watch servers themselves.
- SEO: semantic HTML, meta tags, alt text. A11y: ARIA where needed, keyboard nav, contrast ratios, screen-reader support.
