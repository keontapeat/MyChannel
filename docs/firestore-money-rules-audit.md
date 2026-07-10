# Firestore Rules — Money Collections Audit

## Client-writable (deny direct writes)

| Collection | Client write | Server (Admin SDK) |
|------------|--------------|-------------------|
| `stripe_escrow` | ❌ | ✅ escrow-payments CF |
| `stripe_transfers` | ❌ | ✅ CF |
| `vs_match_wallets` | ❌ | ✅ webhook credit only |
| `vs_match_wallet_credits` | ❌ | ✅ idempotent ledger |
| `vs_match_transactions` | ❌ | ✅ CF wager rows |
| `money_audit_log` | ❌ | ✅ append-only |
| `money_metrics_daily` | ❌ | ✅ CF counters |
| `platform_revenue` | ❌ | ✅ CF |

## Client-readable (authenticated)

| Collection | Read rule |
|------------|-----------|
| `vs_match_wallets/{uid}` | `request.auth.uid == uid` |
| `vs_match_compliance/{uid}` | `request.auth.uid == uid` |
| `versus_matches/{id}` | participant or public if `status == open` |

## Compliance

- `vs_match_compliance` missing doc → server denies wager (batch-7 `assertWagerCompliance`).
- `kycStatus` enum: `none|pending|approved|rejected|expired`.
- `termsVersion` must match `WAGER_POLICY.currentTermsVersion`.

## Action items

- [ ] Add rules tests in `firestore.rules` simulator for wallet self-credit attempt → deny
- [ ] Index: `vs_match_transactions` composite `(userId, type, createdAt)` for daily limits
