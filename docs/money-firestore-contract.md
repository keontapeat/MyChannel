# Money Firestore Contract

**Canonical unit: integer cents (`Int`).** Dollar `Double` fields are legacy/display only.

## Collections

### `escrow/{escrowId}`

| Field | Type | Notes |
|-------|------|-------|
| `amountCents` | Int | Gross hold amount (authoritative) |
| `platformFeeCents` | Int | Platform fee at hold time |
| `netAmountCents` | Int | Net after fee |
| `amount` | Double | Legacy display — do not use for settlement |
| `status` | String | `held`, `released`, `refunded`, `disputed`, `expired` |
| `currency` | String | Always `USD` |

### `vs_match_transactions`

Write `amountCents` when possible; `amount` (Double) for legacy reads.

### `payout_requests` / `creator_earnings`

Prefer `amountCents`; server pay-api is authoritative for withdrawals.

## Rules

1. **Settlement math** uses `MoneyMath` / `Money` on the client; Cloud Functions are authoritative for captures and transfers.
2. **Never** compute fees with raw `Double * 0.10` — use `MoneyMath.platformFeeCents(grossCents:)`.
3. **Disputed** escrow rows must not be released until dispute resolution clears the flag.
4. **Currency** is USD-only for VS Match escrow; reject non-USD at the API boundary.
