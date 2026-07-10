# WagerPolicy Server Mirror — Parity Checklist

Client checks are **UX only**. Authoritative enforcement:

- **Escrow:** `cloud-functions/escrow-payments/index.js` → `assertWagerCompliance`
- **Identity KYC:** `functions/main.py` → `stripe_identity_webhook`

## Constant parity

| Rule | iOS `WagerPolicy.swift` | Server `WAGER_POLICY` (index.js) | Match |
|------|---------------------------|----------------------------------|-------|
| Minimum age | `minimumAge = 18` | `minimumAge: 18` | ✅ |
| KYC threshold | `kycRequiredAboveDollars = 500` | `kycRequiredAboveDollars: 500` | ✅ |
| Terms version | `currentTermsVersion = "2025.1"` | `currentTermsVersion: '2025.1'` | ✅ |
| Daily limit — new | $100 | `new: 100` | ✅ |
| Daily limit — verified | $1,000 | `verified: 1000` | ✅ |
| Daily limit — premium | $10,000 | `premium: 10000` | ✅ |
| Daily limit — VIP | $100,000 | `vip: 100000` | ✅ |
| Allowed regions | `allowedRegions` Set (51) | `allowedRegions` Set (51) | ✅ |
| Platform fee | `MoneyMath.platformFeePercent` (10%) | `PLATFORM_FEE_PERCENT = 0.10` | ✅ |

## Gate order (both sides)

1. Age verified (`ageVerified` or approved KYC on iOS reads)
2. KYC if amount > $500
3. Terms accepted **at current version**
4. Region in allowlist (fail closed if empty)
5. `accountStatus === active`
6. Daily wager sum + new amount ≤ tier limit

## Known intentional differences

| Topic | iOS | Server | Action |
|-------|-----|--------|--------|
| Daily window | `Calendar.current.startOfDay` (local) | UTC midnight (`setUTCHours(0,0,0,0)`) | Align iOS to UTC before launch — see `WagerPolicy.isWithinDailyLimit` comment |
| Audit log | `compliance_audit_logs` on deny | 403 only | Add server-side audit write in escrow if needed |

## Web / Android

- **Web:** `web-v2/lib/wager-policy.ts` — keep in sync when bumping terms or limits.
- **Android:** `android/.../WagerPolicy.kt` — same constants.

## Bump procedure

When changing policy:

1. Update `WagerPolicy.swift`
2. Update `cloud-functions/escrow-payments/index.js` `WAGER_POLICY`
3. Update `web-v2/lib/wager-policy.ts` + tests
4. Update `android/.../WagerPolicy.kt`
5. Bump `currentTermsVersion` if legal text changed
6. Run `MyChannelTests/WagerPolicyTests.swift` + `web-v2/lib/wager-policy.test.ts`
