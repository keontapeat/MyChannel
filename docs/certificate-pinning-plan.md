# Certificate Pinning Plan (stub)

## Current state

- `CertificateValidationService` is registered at `.critical` in `LazyServiceManager`.
- `URLSession.configured` is the shared session for API traffic.
- Money endpoints use Firebase ID tokens via `AuthTokenProvider` — pinning is defense-in-depth, not primary auth.

## Phase 1 — Inventory (done)

| Domain | Service | Pin priority |
|--------|---------|--------------|
| `us-central1-mychannel-ca26d.cloudfunctions.net` | escrow-payments | P0 |
| `us-east1-*.cloudfunctions.net` | Identity / KYC | P0 |
| `api.mychannel.app` | REST gateway | P1 |
| `api.openai.com` | OpenAI | P2 (proxy preferred) |

## Phase 2 — SPKI pins (TODO)

1. Export leaf/intermediate SPKI hashes per domain from production certs.
2. Store pins in `CertificateValidationService` keyed by host.
3. Fail closed on pin mismatch; log to Sentry with host + cert fingerprint.
4. Rotation: ship two pins (current + next) before cert renewal.

## Phase 3 — Rollout

1. DEBUG builds: log-only pin checks.
2. TestFlight: enforce on money hosts only.
3. Production: enforce P0 hosts.

## Out of scope

- Firebase/Google SDK traffic (managed by Google SDK pinning).
- CDN image hosts (ytimg, cloudinary) — too many rotations.

## Related

- `MyChannel/Core/Services/CertificateValidationService.swift`
- `docs/app-check-money.md` (App Check for CF abuse)
