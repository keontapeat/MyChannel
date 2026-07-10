# Launch Performance Checklist

Targets align with `.cursor/rules/performance.mdc` and `LazyServiceManager` cold-start tiers.

## First-frame targets

| Metric | Target | Owner |
|--------|--------|-------|
| Cold start to first frame | **< 400 ms** | `LazyServiceManager` critical tier |
| Critical services complete | **< 500 ms** | Security, Firebase, Auth |
| High-priority services | **< 1 s** (background) | Video, user data |
| Medium-priority services | **< 2 s** (background) | Analytics, image prewarm |
| AI / deferred agents | **Never on cold path** | `.deferred` priority only |
| List scroll | **60 fps** (16 ms/frame) | LazyVStack + pagination |
| Image load (cached) | **< 50 ms** | ImagePrefetcher |
| Image load (network) | **< 200 ms** | CDN + prefetch |

## Before release

- [ ] Profile cold launch in Instruments (Time Profiler + App Launch)
- [ ] Confirm `LazyServiceManager.printStatistics()` shows deferred AI after first frame
- [ ] Home feed uses `FeedMath.feedPageSize` (24) for pagination
- [ ] No synchronous network on main thread during `MyChannelApp.init`
- [ ] Flicks preload uses `FeedMath.preloadRange` (no empty-range crashes)

## LazyServiceManager audit

Deferred (must NOT block launch):

- OpenAIAgent, AgentLog, PerspectiveModeration, AutoCaption, Doctor

Critical (must complete before UI):

- Security, Firebase, Authentication, ValetStorage

See comment in `LazyServiceManager.swift` register block (phase-1223).

## Regression commands

```bash
# Build timing (local)
./scripts/measure_build_times.sh

# Unit tests (money + policy)
./scripts/run-unit-tests.sh
```

## Red flags

- New `@StateObject` singleton touching network in `init`
- Promoting AI services from `.deferred` to `.medium`
- Feed fetching > 24 items on first paint
- Hardcoded API keys causing sync init failures
