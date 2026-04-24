# Phase 95 — Zero-Trust Security

**Status:** ⬜ pending · **Target:** SOC 2 Type II prerequisite

## Goal
Assume the network is already compromised. Every request must authenticate itself, every dependency must be provenance-verified, every secret must rotate automatically.

## Principles
1. **Identity everywhere** — no static secrets in code. Use Workload Identity Federation for every runtime.
2. **Short-lived credentials** — max 1h TTL across the stack.
3. **Least privilege** — per-service IAM role; no broad Editor roles.
4. **Provenance** — every artifact has an SBOM + SLSA-3 provenance record.
5. **Default-deny network** — VPC-SC perimeters around Firestore + GCS; Cloud Run ingress via internal-and-LB only.

## Deliverables
- [ ] Migrate all service accounts to **Workload Identity Federation** (no JSON keys)
- [ ] Rotate every Secret Manager entry on a schedule (max 90d)
- [ ] Build pipeline produces **SBOM (SPDX 2.3)** + **SLSA-3 provenance** for every image
- [ ] `firebase-functions` runtime configs moved from env vars to Secret Manager
- [ ] Apply **VPC Service Controls** around production project
- [ ] Replace passwords with Passkeys for owner + admin portal (ties into Phase 98)
- [ ] **mTLS** between every Cloud Run service through the gateway
- [ ] **Binary Authorization** on Cloud Run — only signed images allowed
- [ ] **Cloud Armor** WAF with rate limits + bot mitigation
- [ ] Audit log firehose to immutable GCS bucket (SEC 17a-4 compliant)
- [ ] Dependency scanning (Snyk / GitHub Advanced Security) blocking merges

## Non-goals
- HSM-backed signing for every action (deferred; adopted for payout signing only)
- Physical-key MFA for all users (we ship Passkeys as the default; hardware keys are opt-in)

## Success criteria
- 0 static keys in repo (enforced via `gitleaks` pre-commit + CI)
- 100% of services authenticate via IAM identity, not shared secrets
- SOC 2 Type II auditor finds no critical findings in the identity domain
