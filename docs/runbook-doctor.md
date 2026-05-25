# Doctor Runbook (Synthetic QA + SLOs)

- Scope: Upload→Transcode→Serve→Ads→Analytics→Payout flows.
- Synthetics: run tools/doctor/smoke.sh hourly and on deploy.
- SLOs: p95 latency < 800ms for APIs; error rate < 1%; ad fill > 60%.
- Alerting: page on 2 consecutive failures; auto-rollback Cloud Run revision.
- DR: weekly restore simulation of BQ+GCS; CDN purge test.

Recovery steps:
1) Check Cloud Run logs for latest failing service.
2) Compare last two revisions; rollback if error spike observed.
3) Verify Pub/Sub backlog size; if high, scale workers.
4) Check Secrets access; ensure runtimes have secretAccessor.
5) Confirm Storage bucket ACLs and signed URL key validity.
