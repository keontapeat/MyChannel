# Singleton Baseline (.shared)

Tracked to measure DI migration progress. Re-run after large refactors.

## Latest count

**Generated:** 2026-07-09  
**Command:** `bash scripts/count-shared-singletons.sh`

| Metric | Value |
|--------|------:|
| Total `.shared` references | 3311 |
| Files with `.shared` | 637 |

## Top offenders (migration targets)

| Count | File |
|------:|------|
| 57 | `Features/Home/Stories/AssetStoriesPagerView.swift` |
| 55 | `Features/Home/MusicHubView.swift` |
| 53 | `Features/Player/VideoDetailView.swift` |
| 37 | `Core/Services/AuthService.swift` |
| 36 | `Core/Services/AppState.swift` |
| 32 | `Core/Performance/LazyServiceManager.swift` |

## Goal

Reduce new `.shared` usage to zero in Features/; resolve via `DependencyContainer` + `@Injected`.

## Tooling

- Count: `scripts/count-shared-singletons.sh`
- Staged guard: `scripts/lint-no-new-shared.sh`
- SwiftLint note: `.swiftlint.yml` → `ban_new_shared_singleton` (warning)
