# Web CSP — Money Routes

Content-Security-Policy notes for `/medals`, `/wallet`, and escrow checkout surfaces.

## Why noindex + CSP together

Money routes (`/medals`, `/wallet`, `/medals/create-match`) export `robots: { index: false }` in App Router layouts. They should also run under a stricter CSP than marketing pages because they attach Firebase ID tokens and call Stripe escrow Cloud Functions.

## Recommended CSP directives (hosting / Next headers)

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'unsafe-inline' https://js.stripe.com;
  connect-src 'self'
    https://us-central1-mychannel-ca26d.cloudfunctions.net
    https://*.googleapis.com
    https://*.firebaseio.com
    https://api.stripe.com;
  frame-src https://js.stripe.com https://hooks.stripe.com;
  img-src 'self' data: https://i.ytimg.com https://lh3.googleusercontent.com;
  style-src 'self' 'unsafe-inline';
```

## Stripe Elements

- Load `https://js.stripe.com/v3/` only on deposit / create-match checkout steps.
- Never inline Stripe secret keys — `clientSecret` only, from authenticated CF response.

## Escrow API

- `connect-src` must include `escrow-payments` gen2 base URL from `MONEY_CONTRACT.escrow.apiBase`.
- Reject arbitrary `fetch()` targets from money pages (no third-party analytics on wallet).

## Firebase Auth

- `connect-src` needs Firebase Auth / Firestore endpoints for signed-in wallet reads.
- ID tokens travel in `Authorization: Bearer` — never in query strings.

## Deployment checklist

1. Add headers in `firebase.json` or Next `headers()` for `/medals/*` and `/wallet/*`.
2. Verify Stripe webhook origin is server-only (not in browser CSP).
3. Run Playwright smoke: `npm run test -- tests/e2e/medals-hub.spec.ts`.
4. Pin `WAGER_POLICY.currentTermsVersion` in compliance banner before shipping.
