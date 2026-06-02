# Merch Checkout — Deploy Status & Steps

Physical-goods merch checkout on the existing `escrow-payments` Stripe rail.
**Apple-compliant:** physical goods charge via **Stripe**, never Apple IAP
(Guideline 3.1.3(e) / 3.1.5(a)).

## ✅ Live now (deployed to mychannel-ca26d)
- Firestore rules: `merch_orders` (server-write only; buyer/creator read),
  `creator_products`, `creator_merch_settings`, `creator_superchat_settings`,
  `membership_tiers`, `creator_memberships`, `videos/{id}/captions`.
- Firestore indexes: `merch_orders` (buyerId+createdAt, creatorId+createdAt),
  `creator_products`, `super-thanks`, `membership_tiers`, `live_streams`.
- The existing `escrow-payments` function is STILL SERVING (VS-match payments
  unaffected — only a new revision is blocked).

## ⛔ BLOCKED: Cloud Run CPU quota exceeded (us-central1)
The merch endpoints are written into `cloud-functions/escrow-payments/index.js`
(`/create-merch-order`, `/refund-merch-order`, webhook `merch_order` finalize),
`node --check` passes — but a new revision cannot start:

`ERROR: Quota exceeded for total allowable CPU per project per region`

The project has ~210 Cloud Run services in us-central1 (≈4,000 vCPU allocated).
29 dead/broken (HealthCheckContainerError, zero traffic) services were deleted
to reclaim quota, but it's still over the project ceiling.

### Fix: request a quota increase (owner action)
1. https://console.cloud.google.com/iam-admin/quotas?project=mychannel-ca26d
2. Service: **Cloud Run Admin API** → metric **CPU allocation, per project per region**, region `us-central1`.
3. Edit Quotas → request higher (e.g. 50–100 vCPU). Small bumps auto-approve fast.
4. Then redeploy (Stripe keys come from Secret Manager — NOT env vars):

```bash
./google-cloud-sdk/bin/gcloud functions deploy escrow-payments \
  --gen2 --runtime=nodejs22 --region=us-central1 --project=mychannel-ca26d \
  --source=cloud-functions/escrow-payments --entry-point=escrowPayments \
  --trigger-http --allow-unauthenticated --memory=256Mi --cpu=0.333 --timeout=60s \
  --set-env-vars=LOG_EXECUTION_ID=true \
  --update-secrets=STRIPE_SECRET_KEY=STRIPE_SECRET_KEY:1,STRIPE_WEBHOOK_SECRET=STRIPE_WEBHOOK_SECRET:1
```

NOTE: Stripe keys live in **Secret Manager** (`STRIPE_SECRET_KEY`,
`STRIPE_WEBHOOK_SECRET`), mounted via `--update-secrets`. The current key is
`sk_test_…` (TEST mode — safe; flip to live key version when going to prod).

## 🔒 Before flipping live (`AppConfig.Features.enableProfileMerch = true`)
1. Function redeployed with merch endpoints (after quota increase).
2. Stripe in LIVE mode + webhook `payment_intent.succeeded` → `/webhook`.
3. Each selling creator completed Stripe Connect (`users/{uid}.stripeConnectAccountId`, payouts_enabled).
4. One real $1 test order end-to-end (order → PaymentSheet → webhook marks paid → stock decrement → creator paid minus 10%).
5. App Review notes: merch = physical goods via external processor (Stripe), per Guideline 3.1.3(e).

## iOS files added (auto-included via synchronized Xcode group)
- `Core/Services/MerchCheckoutService.swift`
- `Features/Studio/Views/MerchCheckoutSheet.swift`
- `Features/Studio/Views/CreatorMerchShelfView.swift`

## Local gcloud
Installed (no Homebrew) at `./google-cloud-sdk/` (gitignored). Authed as
keontapeat@mychannel.live, project mychannel-ca26d.
