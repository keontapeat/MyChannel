# Secrets Rotation Checklist

Use this when rotating API keys, Firebase config, or payment credentials. Never commit secrets to git.

## Pre-flight

- [ ] Run `./scripts/scan-for-secrets.sh` — no new hardcoded keys in source
- [ ] Confirm `.gitignore` includes:
  - `functions/.env*`
  - `**/google-services.json`
  - `android/app/google-services.json`
  - `**/GoogleService-Info.plist`
  - `**/Secrets.local.xcconfig`
  - `web-v2/.env.local`

## iOS (AppSecrets)

| Secret | Storage order | Rotate via |
|--------|---------------|------------|
| Anthropic / OpenAI | Keychain → env → Info.plist | Developer settings / CI env |
| TMDB | Keychain → Info.plist → env | TMDB dashboard; no source fallback |
| Stripe publishable | Keychain → env → Info.plist | Stripe Dashboard |
| Google Cloud | Keychain → env → Info.plist | GCP Console |
| Sentry / PostHog / RevenueCat | env → Info.plist | Vendor dashboards |

**Never** add `STRIPE_SECRET_KEY` to the iOS client — server Cloud Functions only.

## Web (web-v2)

- [ ] Rotate keys in Vercel/Firebase hosting env vars
- [ ] Update `web-v2/.env.local` locally (not committed)
- [ ] Redeploy hosting after rotation

## Android

- [ ] Replace local `android/app/google-services.json` (gitignored)
- [ ] Rotate Firebase Android app in Console if compromised
- [ ] Store API keys in `local.properties` or BuildConfig — not in Kotlin source

## Cloud Functions

- [ ] Update `functions/.env` (gitignored)
- [ ] Redeploy: `firebase deploy --only functions`
- [ ] Verify escrow-payments with staging Stripe keys first

## Post-rotation

- [ ] Revoke old keys in vendor dashboards
- [ ] Smoke test: auth, TMDB movies row, VS Match preflight, Stripe deposit
- [ ] Bump `WagerPolicy.currentTermsVersion` only if **legal terms** changed (not for key rotation)

## Emergency leak response

1. Revoke exposed key immediately
2. `git log -p -- path/to/leaked/file` — assess exposure window
3. Rotate and redeploy all platforms
4. File incident in ops channel
