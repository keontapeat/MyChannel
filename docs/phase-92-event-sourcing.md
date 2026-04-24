# Phase 92 — Event-Sourced Core

**Status:** ⬜ pending · **Depends on:** Phase 49 BigQuery pipeline · **Target:** 2 quarters

## Goal
Move `feed`, `comments`, and `watchHistory` off direct Firestore writes and onto an append-only event log with replayable projections. This unblocks cost-efficient analytics, temporal queries, and debugging.

## Architecture
```
Client → Cloud Run Gateway → Pub/Sub topic(s)
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
  Firestore projection    BigQuery projection    Elastic projection
   (serves live UI)        (analytics + ML)       (search index)
```

## Event schema (Avro)
```avro
record VideoEvent {
  string  id;           // ULID
  string  type;         // "video.published", "video.liked", "comment.created", ...
  long    ts;           // micros since epoch
  string  actorUid;
  string  entityId;
  string  entityKind;   // "video" / "comment" / "stream"
  map<string> attrs;
}
```

## Migration plan
1. **Dual-write phase** — legacy writes + new Pub/Sub publish (idempotent).
2. **Backfill** — replay 18 months of Firestore history into Pub/Sub with original timestamps.
3. **Swap reads** — switch feed reads to the projection.
4. **Retire dual-write** — legacy writes become projection-only.

## Topics
- `events.video` — publish, edit, delete, like, comment, view
- `events.creator` — upload, monetize, milestone
- `events.user` — signup, subscribe, unsubscribe, watch-time
- `events.moderation` — report, action, appeal

## Retention
- Pub/Sub: 7 days (replay window)
- GCS archive (Avro): 7 years (compliance)
- BigQuery: hot 90d + cold-storage 2y

## Risks & mitigations
- **Hot partitions** on viral videos → partition by `(entityId, shard)` with 32 shards.
- **Order guarantees** — consumers must handle out-of-order events; use `ts` for tie-break.
