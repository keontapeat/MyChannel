# Android Money Parity (Phase-486)

Tracks Android parity with iOS/web money and wager compliance. iOS is canonical; Android must mirror constants before shipping real-money VS Matches on Android.

## Completed (this batch)

| Phase | Item | Artifact |
|-------|------|----------|
| 486 | Android wager policy mirror | `android/app/src/main/java/com/mychannel/util/WagerPolicy.kt` |
| 487 | Android MoneyMath cents | `android/app/src/main/java/com/mychannel/util/MoneyMath.kt` |
| 488 | google-services.json not committed | `.gitignore` entries |
| 490 | Phase-86 plan progress check | This doc |
| 503 | Document Android money gaps | See gaps below |
| 491 | Stripe Identity stub | `services/stripe/StripeIdentityStub.kt` |
| 492 | Escrow CF client stub | `services/escrow/EscrowPaymentsClient.kt` |
| 488 | MoneyMath unit test | `MoneyMathTest.kt` |
| 483 | Secrets fail-closed note | See BuildConfig section below |

## Constants sync checklist

When changing wager policy on iOS, update in the same PR:

1. `MyChannel/Core/Utils/WagerPolicy.swift`
2. `web-v2/lib/wager-policy.ts` + `wager-policy.mjs`
3. `android/.../util/WagerPolicy.kt`
4. `cloud-functions/escrow-payments` server enforcement
5. `MyChannelTests/TermsVersionSyncTests.swift`

Pinned values (2025.1):

- Terms version: `"2025.1"`
- Platform fee: 10%
- Wager bounds: $1 – $100,000
- KYC above: $500
- Allowed regions: 50 US states + DC

## Android VS Match compliance (stub — phase-489)

**Status:** Not implemented on Android yet.

Planned parity with iOS `VSMatchComplianceSheet`:

1. **Eligibility gate** before create/accept wager
2. **Age verification** (18+) — date picker + Firestore write
3. **Terms acceptance** — version `WagerPolicy.CURRENT_TERMS_VERSION`
4. **KYC** (Stripe Identity) for wagers > $500
5. **Blockers** — region, account status, daily limit (server-authoritative)

Suggested Compose surface: `VSMatchComplianceBottomSheet` wired to `VSMatchViewModel`, calling the same Cloud Functions as iOS (`VSMatchComplianceService` equivalent).

## Remaining gaps (post phase-486)

| Phase | Gap |
|-------|-----|
| 489 | VS Match compliance UI (Compose sheet) |
| 491 | Stripe Identity SDK integration |
| 492 | Escrow Cloud Function client on Android |
| 493 | Flicks player unify with iOS global player |
| 494 | Offline downloads parity |
| 478 | Android DI for money services |
| 483 | Android secrets fail-closed |
| 488 | Android unit tests for `MoneyMath` / `WagerPolicy` |

## Stub notes (no huge ports — batch-6)

| Area | Status | Note |
|------|--------|------|
| DI (Hilt) | Stub | Register `EscrowPaymentsClient` + `StripeIdentityStub` in `RepositoryModule` when VS Match ships on Android |
| Flicks player | Stub | `FlicksScreen.kt` uses local ExoPlayer — unify with iOS `GlobalVideoPlayerManager` in phase-493 |
| Offline downloads | Stub | `DownloadWorker.kt` exists; parity with iOS `OfflineDownloadService` deferred to phase-494 |

## BuildConfig fail-closed (phase-483)

Android must **not** ship API keys in `BuildConfig` for production money routes.

- `KeychainManager.migrateFromBuildConfig()` is one-time migration only.
- `NetworkModule` enables logging in `BuildConfig.DEBUG` only.
- TMDB / Stripe / Firebase secrets: load from `local.properties` or remote config — empty key → feature disabled (mirrors iOS `AppSecrets` fail-closed).
- `google-services.json` is gitignored; CI injects per-environment file.

## Verification

```bash
# Web/iOS money tests
./scripts/run-unit-tests.sh

# Android (manual until JVM tests added)
# Compare WagerPolicy.ALLOWED_REGIONS.count == 51 with iOS WagerPolicyTests
```
