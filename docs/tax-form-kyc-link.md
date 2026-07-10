# Tax Forms & KYC — Creator Linkage

## US creators (1099-K / 1099-NEC)

When lifetime payouts exceed IRS reporting thresholds, Stripe Connect collects tax identity (W-9) during onboarding or via Stripe Dashboard prompts.

## VS Match wager KYC (players)

Separate from creator tax KYC:

| Purpose | Collection | Storage |
|---------|------------|---------|
| Wager > $500 identity | Stripe Identity (document + selfie) | Stripe + `vs_match_compliance.kycStatus` |
| Creator tax ID | Stripe Connect | Stripe only — never in Firestore PII fields |

## Support playbook

1. **Player:** "Why do I need ID for $500 match?" → Skill-based real-money compliance; Stripe Identity; data not stored on device.
2. **Creator:** "Where's my 1099?" → Stripe Express Dashboard → Tax documents.
3. **Rejected KYC:** Compliance sheet shows re-verify + support escalation; check `stripe_identity_webhook` logs.

## Docs cross-links

- Player KYC UX: `VSMatchComplianceSheet.swift`
- Server webhook: `functions/main.py` → `stripe_identity_webhook`
- Xcode setup: `docs/stripe-identity-xcode.md`
