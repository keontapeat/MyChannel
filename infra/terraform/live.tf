resource "google_cloud_run_service" "live_control" {
  name     = "mychannel-live-control"
  location = var.region
  template {
    spec {
      service_account_name = data.google_service_account.run_svc.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/mychannel-live-control:latest"
        ports { name = "http1" container_port = 8080 }
      }
    }
  }
  traffic { percent = 100 latest_revision = true }
}

output "live_control_url" {
  value = google_cloud_run_service.live_control.status[0].url
}



