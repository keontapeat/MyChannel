# Cloud Function IAM — Least Privilege

## escrow-payments

| Principal | Role | Scope |
|-----------|------|-------|
| `escrow-payments@...` runtime SA | `roles/datastore.user` | Firestore read/write for money collections only |
| Same | `secretmanager.secretAccessor` | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` |
| Same | **No** `firebaseauth.admin` | Uses `verifyIdToken` only |
| Invokers | `allUsers` **denied** | Authenticated via Firebase ID token in handler |

## music-payouts / identity

- Stripe Identity session create: dedicated SA, rate-limited (10/min per uid in CF).
- Webhook handlers: no public invoke; Stripe signature only.

## Deployment checklist

```bash
# Grant only Firestore + Secret Manager
gcloud functions add-invoker-policy-binding escrowPayments \
  --region=us-central1 \
  --member="allUsers"  # ONLY if behind Cloud Armor / App Check — prefer IAM + gateway
```

Prefer API Gateway + App Check over `allUsers` on money functions.

## Audit

- Review IAM quarterly via `gcloud functions get-iam-policy`.
- No Editor/Owner on runtime service accounts.
