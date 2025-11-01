# Cloud Scheduler jobs

resource "google_cloud_scheduler_job" "growth_aso_sync_daily" {
  name        = "growth-aso-sync-daily"
  description = "Daily ASO keyword sync"
  schedule    = "0 6 * * *" # 06:00 UTC daily
  time_zone   = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://us-central1-${var.project_id}.cloudfunctions.net/growth_aso_sync"
    headers     = { "Content-Type" = "application/json" }
    body        = base64encode("{}")
  }
  depends_on = [google_project_service.services]
}

resource "google_cloud_scheduler_job" "doctor_synthetics_hourly" {
  name        = "doctor-synthetics-hourly"
  description = "Ping events service health for uptime"
  schedule    = "0 * * * *" # hourly
  time_zone   = "Etc/UTC"

  http_target {
    http_method = "GET"
    uri         = google_cloud_run_service.events.status[0].url
  }
  depends_on = [google_cloud_run_service.events]
}




