# Geo Region Hint (Stub)

**Endpoint:** `geo_region_hint` in `functions-v2/main.py` (region `us-east1`)

## Purpose

Pre-fill the compliance sheet region `TextField` — **not** authoritative for wagering. Users must still save an explicit `US-XX` code; escrow `assertWagerCompliance` fails closed when `region` is missing.

## Current behavior (stub)

```json
GET /geo_region_hint
{
  "ip": "203.0.113.1",
  "geo_region_hint": null,
  "authoritative": false,
  "note": "stub — wire IP geolocation before pre-filling compliance region"
}
```

## Production wiring (TODO)

1. Choose provider (MaxMind GeoIP2, IPinfo, Cloudflare `CF-IPCountry` + state header).
2. Map ISO subdivision → `US-CA` format matching `WagerPolicy.allowedRegions`.
3. Return `geo_region_hint` only when confidence ≥ threshold; else `null`.
4. Log hint separately from saved `users.region` for audit.
5. Never auto-write region without user confirmation (GDPR / state gaming laws).

## iOS integration (future)

Call from `VSMatchComplianceSheet.refresh()` when `!regionAllowed` to seed `regionInput` — user still taps **Save Region**.
