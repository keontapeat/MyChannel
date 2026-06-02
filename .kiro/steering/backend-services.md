---
inclusion: fileMatch
fileMatchPattern: ['services/**', 'functions/**', 'cloud-functions/**', 'gateway/**', 'firebase/**', '**/*.mjs', 'firestore.rules', 'storage.rules', 'firebase.json', 'firestore.indexes*.json']
---

# Backend, Services & Firebase Config

Applies to Node services (`services/`, `functions/`, `cloud-functions/`, `gateway/`), Firebase config, and `.mjs` files.

## General
- Use modern ESM (`.mjs` / `import`) consistent with the file you're editing. Match the surrounding module's style.
- Keep services small and single-purpose. Don't add cross-service coupling without reason.
- All external/network input is untrusted: validate and sanitize on the server side.
- Make handlers idempotent where retries are possible (webhooks, payouts, queue consumers).

## Endpoints & Security
- Any network-exposed endpoint must have authentication/authorization. If you add one without auth, flag it explicitly to the user.
- Never trust client-side checks for money, auth, or access control — enforce server-side and via Firebase Security Rules.
- No secrets in code or in the repo. Use environment variables / secret managers.

## Firebase Rules & Indexes
- `firestore.rules`, `storage.rules`, and `firestore.indexes*.json` are sensitive. Changing rules can open security holes or break access — explain changes and confirm before deploying.
- There are multiple index files (`.COMPLETE`, `.NUCLEAR`, `.optimized`, etc.). Confirm which is the active/source-of-truth file before editing; don't assume.
- Deploying rules/indexes affects live data — treat `firebase deploy` as high-risk and confirm first.

## Money-Touching Services
- See the money-and-compliance steering. Anything in an ads/wager/escrow/payout service inherits those rules: transactional writes, integer-cents math, idempotency, no PII/secret logging.

## Testing
- Tests live alongside services (e.g. `services/ads/test/*.test.mjs`). Run the relevant test suite after changes.
- Use the package's own test runner (check `package.json` scripts). Prefer single-run modes over watch mode in the agent.
- Add or update tests when changing behavior in a service that already has tests.

## Deploy Scripts
- The repo has many `deploy-*.sh` / `DEPLOY_*.sh` scripts, several labeled "NUCLEAR". Do not run deploy scripts on your own — they affect production. Confirm with the user and prefer the most specific, current script.
