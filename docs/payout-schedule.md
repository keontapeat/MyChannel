# Creator Payout Schedule

## MyChannel vs YouTube

| | MyChannel | YouTube |
|---|-----------|---------|
| Minimum threshold | **$0** (`CreatorPayoutService.minimumPayoutThresholdCents`) | $100 |
| Standard schedule | Monthly (1st business day) | Monthly net-30 |
| Instant payout | Available via Stripe Connect instant (fee applies) | Limited |

## Flow

1. **Accrual:** Ad impressions, Super Thanks, memberships → `creator_earnings` / `pendingBalance`.
2. **Hold:** Fraud checks (`FraudDetectionAgent`) may delay high-risk accruals.
3. **Payout batch:** `CreatorPayoutService.processPayout` when Stripe Connect connected.
4. **Transfer:** Stripe Connect transfer to creator's linked account.
5. **Record:** `payoutHistory` + Firestore `payouts` collection.

## Stripe Connect requirements

- Creator completes Connect onboarding (`StripeConnectService`).
- KYC for creators receiving > IRS thresholds → link to `docs/tax-form-kyc-link.md`.

## Escrow (VS Match) — separate path

Match winnings settle via `MoneyEscrowService` / escrow Cloud Function — not mixed with ad payout batch. See `docs/backend-money-runbook.md`.

## Support macros

- "When do I get paid?" → Monthly automatic if Connect linked; no minimum balance.
- "Instant payout?" → Settings → Wallet → Instant (Stripe fee disclosed at tap).
