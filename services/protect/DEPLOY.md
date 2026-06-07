# Content ID Service — Deploy

Real acoustic fingerprinting with Chromaprint (`fpcalc`) + ffmpeg.

## Prereqs
- A Postgres instance reachable via `DATABASE_URL` (Cloud SQL or Neon).
- Artifact Registry repo `app-repo` in your region.
- Cloud Build + Cloud Run enabled.

## 1. Apply the DB schema
```bash
DATABASE_URL=postgres://... npm --prefix services/protect run migrate
```

## 2. Build the image (from repo root)
```bash
gcloud builds submit --config services/cloudbuild-protect.yaml \
  --substitutions _REGION=us-east1 .
```

## 3. Deploy to Cloud Run
```bash
gcloud run deploy mychannel-protect \
  --image us-east1-docker.pkg.dev/$PROJECT_ID/app-repo/mychannel-protect:latest \
  --region us-east1 \
  --no-allow-unauthenticated \
  --set-env-vars DATABASE_URL="postgres://..." \
  --memory 1Gi --cpu 1 --timeout 120 --concurrency 4
```
(1Gi memory: ffmpeg decode + fingerprint compare. Concurrency low because each
request is CPU-bound.)

## 4. Wire the Cloud Function
Grant the functions service account `roles/run.invoker` on this service, then:
```bash
firebase functions:config:set  # (or set env on the codebase)
# Set PROTECT_SERVICE_URL on the platform-functions-v4 codebase:
gcloud run services update <noop> # actually set via functions env:
```
Set `PROTECT_SERVICE_URL=https://mychannel-protect-xxxxx-ue.a.run.app` as an
environment variable on the `platform-functions-v4` codebase (in
`functions-v4/.env` or via the deploy). The `content_id_scan_on_ready` function
calls `/protect/scan` with a Google ID token; if the service is unreachable it
falls back to metadata matching automatically.

## Endpoints
- `POST /protect/register { referenceId, audioUrl, ownerId, policy, title }`
- `POST /protect/scan     { videoId, audioUrl, creatorId }`
- `GET  /health`

## How matching works
1. `fpcalc -raw` extracts a Chromaprint fingerprint (array of 32-bit frames).
2. Reference fingerprints are stored in Postgres (`reference_fingerprint`).
3. On scan, the video fingerprint is slid over each reference and the best
   alignment's bit-error-rate is computed. Score ≥ 0.85 over ≥ 50 frames = match.
4. On match, a `content_id_claims` doc is written to Firestore and the rights
   holder's policy (block / monetize / track) is applied to the video.
