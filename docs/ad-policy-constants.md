# Ad policy constants (iOS + web parity)

Source of truth: `MyChannel/Core/Services/AdsService.swift` → `AdPolicy`.

| Constant | Value | Notes |
|----------|-------|-------|
| `skipAfterSeconds` | 5 | Skip button after 5s (YouTube parity) |
| `maxAdsPerHour` | 4 | Frequency cap |
| `maxAdsPerDay` | 20 | Rolling 24h cap |
| `platformRevenueSharePercent` | 0.10 | Use `MoneyMath.platformFeeCents`, not raw `* 0.1` |
| `creatorRevenueSharePercent` | 0.90 | Creator share |
| `midRollMinVideoDurationSeconds` | 480 | 8 min before mid-roll |
| `blockedBrandSafetyCategories` | violence, adult, … | Brand safety block list |
| `membershipTierPriceCents` | 499 / 999 / 1999 | Channel / premium / VIP |
| `channelTipPresetsCents` | 100, 500, 1000, 5000 | Tip sheet presets |

Web `DynamicPricingAgent` parity: see `web-v2/services/agi-agents/money-maker/DynamicPricingAgent.ts` and iOS `MoneyMakerAgents.swift`.

Remaining ads work: `docs/ads-remaining.md` (creator dashboard stub, advertiser billing, refund path, gift membership).
