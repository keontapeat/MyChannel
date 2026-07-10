# @Injected Property Wrapper

Lightweight DI for SwiftUI views and `@MainActor` services without singleton spaghetti.

## Usage

```swift
struct VSMatchComplianceSheet: View {
    @Injected private var compliance: VSMatchComplianceService

    var body: some View {
        // use compliance...
    }
}
```

Resolution happens at property init time via `DependencyContainer.shared.resolve(_:)`.

## Registering services

Add factories in `DependencyContainer.registerDefaultServices()`:

```swift
register(VersusMatchService.self) { VersusMatchService.shared }
```

For tests or previews, register a mock **before** the view is created:

```swift
DependencyContainer.shared.register(VSMatchComplianceService.self) {
    MockComplianceService()
}
```

## Previews

`DependencyContainer.preview` aliases `shared`. Override registrations in `#Preview` setup when needed.

### Preview mocks for AI

Register a stub `CreatorIntelligenceService` (or mock `AgentAPIService`) before preview body:

```swift
#Preview {
    DependencyContainer.shared.register(CreatorIntelligenceService.self) { PreviewCreatorIntelligence() }
    return MyView()
}
```

## Batch-7 @Injected views

| View | Injected service |
|------|------------------|
| `VSWalletSheet` | `VSMatchWalletService` |
| `LiveVersusMatchView` | `VersusMatchService` |
| `ChampionshipHubView` | `ChampionshipBeltSystem` |
| `DownloadsView` | `OfflineDownloadService` |
| `NuclearFlicksViewModel` | `AgentAPIService`, `VideoFirestoreService`, `SeedCatalogService` ✅ |

`EnhancedFlicksViewModel` is deprecated/unwired — production Flicks uses `NuclearFlicksViewModel`.

## Rules

1. Prefer `@Injected` over new `.shared` accessors in Features/.
2. New singletons must be registered in `DependencyContainer`.
3. CI baseline tracked in `docs/singleton-baseline.md` (`scripts/count-shared-singletons.sh`).
4. `scripts/lint-no-new-shared.sh` warns on staged files that increase `.shared` usage.

## Current registrations (money + playback + AI)

- `AuthenticationManager`, `GlobalVideoPlayerManager`, `OfflineDownloadService`
- `MoneyEscrowService` / `MoneyEscrowing`, `VSMatchComplianceService` / `ComplianceChecking`
- `VersusMatchService`, `VSMatchWalletService`, `StripeConnectService`
- `CreatorIntelligenceService`
