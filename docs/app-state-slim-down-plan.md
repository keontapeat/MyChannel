# AppState Slim-Down Plan

## Problem

`AppState` holds 30+ `@Published` collections (watch later, liked, playlists, etc.) and duplicates data already in Firestore-backed services. This increases memory, save-loop risk, and logout cleanup surface.

## Target architecture

| Concern | Move to | AppState keeps |
|---------|---------|----------------|
| Watch later / liked / subs | `UserCollectionsFirestoreService` | `currentUser`, `isAuthenticated` only |
| Playback position | `GlobalVideoPlayerManager` | — |
| Search history | `SearchHistoryService` | — |
| Wallet / compliance | DI services (`VSMatchWalletService`, `VSMatchComplianceService`) | — |
| Theme / locale | `UserPreferencesService` (new) | — |

## Phases

1. **Read path** — Views read from services; AppState mirrors for one release behind feature flag.
2. **Write path** — Debounced saves move to service layer; remove `$watchLaterVideos` sink.
3. **Logout** — Only `resetState()` + `DependencyContainer.unregisterUserScopedServices()` (done batch-7).
4. **Delete mirrors** — Remove duplicate arrays once all tabs use services.

## Non-goals

- No mass delete of `AppState.swift` in one pass.
- No pbxproj changes; new services register in `DependencyContainer` only.
