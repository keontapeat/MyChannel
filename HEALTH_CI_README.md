# Health Probe CI

This repo includes an internal health probe and a scheduled GitHub Actions workflow for uptime checks.

## Internal Probe (local/CI)
- Script: `scripts/health-probe.sh`
- Logs: `logs/health.log`
- Behavior: Calls the Cloud Run health URL with an identity token and exits non‑zero if not 200.

Run once:
```bash
./scripts/health-probe.sh
```

## GitHub Actions Scheduled Probe
- Workflow: `.github/workflows/health-probe.yml`
- Schedule: every 10 minutes (and manual dispatch)
- On failure: sends Slack and Email alerts (if secrets are set)

### Required GitHub Secrets
- `GCP_SA_KEY`: Service account JSON with permission to mint identity tokens for the health backend. Suggested roles:
  - Project Viewer (read)
  - `roles/iam.serviceAccountTokenCreator` on the backend service account used by Cloud Run (e.g., `124515086975-compute@developer.gserviceaccount.com`)
- `SLACK_WEBHOOK_URL` (optional): Slack incoming webhook URL for alerts
- `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` (optional): SMTP server credentials
- `ALERT_EMAIL_TO`, `ALERT_EMAIL_FROM` (optional): Email recipients/sender

### Health URL
The workflow probes the Cloud Run health URL:
```
RUN_URL=https://health-fkri6ifojq-uc.a.run.app
```
Adjust this in the workflow `env` if your URL changes.
