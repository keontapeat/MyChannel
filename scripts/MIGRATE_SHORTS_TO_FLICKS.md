# Migration: `shorts` → `flicks`

The Flicks feed's Firestore collection was renamed from **`shorts`** to **`flicks`**.

All app code, Cloud Functions, security rules, and indexes now point at `flicks`.

## Status: ✅ COMPLETE (3 docs migrated)

On `mychannel-ca26d`, the 3 existing documents in `shorts` were copied into
`flicks` (verified — titles + video URLs intact). The original `shorts` docs
were **left in place** as a safety net and can be deleted later (see below).

## What's handled

- **App reads**: `NuclearFlicksViewModel` writes to `flicks` and, while the new
  collection is empty, also falls back to reading the legacy `shorts` collection.
  Works with no downtime before/after migration.
- **Rules**: `flicks` (+ `flicks/{id}/events`), `flickReports`, and
  `users/{uid}/feedSignals` are deployed. `shorts` rules kept as a legacy fallback.
- **Indexes**: composite indexes for the `flicks` feed/trending queries deployed.

## The migration script

`scripts/migrate-shorts-to-flicks.cjs` — copies `shorts/*` → `flicks/*`
(including `events` subcollections), via the Firestore REST API.

**Auth**: uses the access token already stored by the Firebase CLI
(`~/.config/configstore/firebase-tools.json`). No service account or gcloud
required. The script auto-refreshes the token through the CLI if it's stale.

```bash
# Dry run — reads only, writes nothing
node scripts/migrate-shorts-to-flicks.cjs

# Perform the copy (idempotent — same doc IDs, safe to re-run)
node scripts/migrate-shorts-to-flicks.cjs --commit

# Optional: after verifying the flicks feed, delete the old shorts docs
node scripts/migrate-shorts-to-flicks.cjs --commit --delete-source
```

## Cleanup once you're confident

1. Delete the legacy source docs:
   `node scripts/migrate-shorts-to-flicks.cjs --commit --delete-source`
2. Remove the legacy fallback code/rules (marked `🔄 MIGRATION FALLBACK` / `LEGACY`):
   - `loadLegacyShortsFlicks(...)` in `NuclearFlicksViewModel.swift`
   - the `shorts` blocks in `firestore.rules` (root + `firebase/`)
