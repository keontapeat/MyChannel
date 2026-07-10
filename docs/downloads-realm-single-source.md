# Offline downloads: Realm vs file manifest (batch-7)

## Single source of truth

| Layer | Role |
|-------|------|
| `OfflineDownloadService` + `downloads_manifest.json` | **Canonical** queue, progress, expiry, file paths |
| `RealmOfflineService` | **Mirror only** — updated via `syncRealmMetadata(for:localPath:)` on completed downloads |
| `NuclearDownloadManager` | **Removed** — do not reintroduce; migration reads manifest on launch |

## Rules

1. **No dual write without sync:** Every completed download calls `syncRealmMetadata` once.
2. **Delete path:** `deleteDownload` removes file + manifest row + Realm row together.
3. **Offline DRM:** HLS packages route through `HLSDownloadManager` (background `URLSession`).
4. **Hash verify:** Progressive downloads run `verifyDownloadedFile` before marking `.completed`.
5. **Profile tab:** `ProfileDownloadsTabView` reads `OfflineDownloadService.shared.completedDownloads`.

## Background URLSession

`HLSDownloadManager` owns the background session identifier; `OfflineDownloadService.resumeInterruptedHLSDownloads()`
reattaches on cold start.
