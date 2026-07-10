# Analytics Event Naming — Money Domain

Use **snake_case** with domain prefix. Never include PII, card numbers, or ephemeral keys in properties.

## Prefixes

| Prefix | Domain |
|--------|--------|
| `money_escrow_` | Hold, capture, release |
| `money_wager_` | VS Match create/accept |
| `money_payout_` | Creator transfers |
| `money_super_thanks_` | Super Thanks purchase |
| `money_compliance_` | Gate deny/pass (reason codes only) |
| `ads_impression_` | Ad served / skipped |

## Examples

```
money_wager_create_started     { match_id, amount_cents, tier }
money_wager_create_denied      { reason_codes: ["kyc_required"] }
money_escrow_hold_succeeded    { match_id, amount_cents }
money_payout_completed         { amount_cents, instant: false }
ads_impression_served          { placement: "preroll", cpm_cents: 1250 }
ads_impression_skipped_premium { reason: "plus_subscriber" }
money_compliance_kyc_started   { source: "ios_sheet" }
```

## PostHog / Firebase

- Map to same names in `PostHogAnalyticsService` and Firebase Analytics (truncate param keys to 40 chars for Firebase).
- Currency always `_cents` integer property alongside optional display `_dollars`.

## Crashlytics custom keys (escrow)

```
money_domain = escrow
match_id = <uuid>
amount_cents = <int>
```

Never set `stripe_customer_id` or bank tokens as Crashlytics keys.
