# Ads — remaining work & parity notes

Policy constants: `docs/ad-policy-constants.md` · iOS `AdPolicy` in `AdsService.swift`.

## DynamicPricingAgent iOS parity

| Surface | Location | Status |
|---------|----------|--------|
| Web | `web-v2/services/agi-agents/money-maker/DynamicPricingAgent.ts` | Vertex AI, 5-min interval |
| iOS | `MyChannel/Core/AI/MoneyMakerAgents.swift` → `DynamicPricingAgent` | On-demand multipliers; same 10% platform fee via `WagerPolicy` |

Both agents cap price at ≥ 70% of base and use demand / time / segment multipliers.

## Creator ads dashboard

- **iOS stub:** `MyChannel/Features/Ads/CreatorAdsDashboardStubView.swift`
- **Web stub:** `web-v2/app/ads/creator/page.tsx`
- Full dashboard (revenue share, RPM, fill rate) ships after Firestore `creator_ad_stats` collection.

## Advertiser billing

- **iOS stub:** `MyChannel/Core/Services/AdvertiserBillingService.swift`
- Stripe Customer + invoice webhooks; prepaid balance debited per impression.
- Production path: Cloud Function `ad-billing-charge` (not wired in batch-8).

## Refund ad spend path

- **iOS stub:** `MyChannel/Core/Services/AdRefundService.swift`
- Policy: refund unused prepaid balance within 30 days; prorated for paused campaigns.
- Idempotency key: `ad_refund_{campaignId}_{reason}`.

## Gift membership

- **Implemented:** `ProfileMembershipService.giftMembership` + `GiftMembership` model.
- IAP / StoreKit receipt verify before granting tier (see `docs/storekit-receipt-verify.md`).
