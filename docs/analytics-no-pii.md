# Client Analytics — No PII

## Allowed properties

- `user_id` — opaque Firebase UID only (hashed in PostHog if required)
- `match_id`, `video_id` — resource IDs
- `amount_cents` — integer, never card/bank details
- `region` — `US-XX` normalized, not full address
- `account_tier`, `kyc_status` — enum strings

## Forbidden in client events

- Email, phone, legal name, DOB
- Stripe customer/payment method IDs
- Full shipping addresses (merch checkout logs `order_id` only)
- Anthropic/OpenAI API keys or prompt contents with user PII

## Money events

See `docs/analytics-event-naming-money.md`. All wager events use:

```
vs_match_wager_attempt | vs_match_wager_denied | vs_match_payout_settled
```

With `code` from `MONEY_ERROR.*` stable codes — never raw Stripe error strings.

## Verification

- Grep PostHog/Sentry identify calls for `email` — only Sentry (crash context), scrub in Release.
- `PostHogAnalyticsService.identify` uses `display_name` only — no email in properties.
