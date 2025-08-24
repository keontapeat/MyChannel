terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.29.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.29.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "media_bucket_name" {
  type        = string
  description = "Globally-unique bucket name for media"
}

variable "ingest_bucket_name" {
  type        = string
  description = "Bucket for raw uploads (ingest/)"
}

variable "public_bucket_name" {
  type        = string
  description = "Bucket for public HLS/MPD outputs"
}

resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "apigateway.googleapis.com"
  ])
  service = each.value
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "app-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.services]
}

data "google_service_account" "run_svc" {
  project    = var.project_id
  account_id = "run-svc"
}

# API Gateway service account
resource "google_service_account" "apigw_sa" {
  account_id   = "apigw-sa"
  display_name = "API Gateway SA"
}

resource "google_project_iam_member" "roles" {
  for_each = toset([
    "roles/run.invoker",
    "roles/aiplatform.user",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/pubsub.publisher",
    "roles/bigquery.dataEditor"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${data.google_service_account.run_svc.email}"
}

# Grant API Gateway SA permission to invoke Cloud Run
resource "google_project_iam_member" "apigw_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.apigw_sa.email}"
}

# Read Cloud Run service URL
data "google_cloud_run_service" "ai" {
  name     = "mychannel-ai"
  location = var.region
}

# Cloud Run services for core APIs (images must exist in Artifact Registry)
resource "google_cloud_run_service" "upload" {
  name     = "mychannel-upload"
  location = var.region
  template {
    spec {
      service_account_name = data.google_service_account.run_svc.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/mychannel-upload:latest"
        env {
          name  = "INGEST_BUCKET"
          value = var.ingest_bucket_name
        }
        ports {
          name           = "http1"
          container_port = 8080
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service" "transcode" {
  name     = "mychannel-transcode"
  location = var.region
  template {
    spec {
      service_account_name = data.google_service_account.run_svc.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/mychannel-transcode:latest"
        ports {
          name           = "http1"
          container_port = 8080
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service" "content" {
  name     = "mychannel-content"
  location = var.region
  template {
    spec {
      service_account_name = data.google_service_account.run_svc.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/mychannel-content:latest"
        ports {
          name           = "http1"
          container_port = 8080
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service" "events" {
  name     = "mychannel-events"
  location = var.region
  template {
    spec {
      service_account_name = data.google_service_account.run_svc.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/mychannel-events:latest"
        env {
          name  = "EVENTS_TOPIC"
          value = google_pubsub_topic.events.name
        }
        ports {
          name           = "http1"
          container_port = 8080
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Render OpenAPI with backend URL
resource "local_file" "apigw_openapi" {
  filename = "${path.module}/apigateway_openapi.yaml"
  content = templatefile("${path.module}/openapi.tmpl.yaml", {
    backend_url   = data.google_cloud_run_service.ai.status[0].url,
    upload_url    = google_cloud_run_service.upload.status[0].url,
    content_url   = google_cloud_run_service.content.status[0].url,
    events_url    = google_cloud_run_service.events.status[0].url,
    transcode_url = google_cloud_run_service.transcode.status[0].url
  })
}

# API Gateway API and config
resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "mychannel-api"
}

resource "google_api_gateway_api_config" "api_config" {
  provider = google-beta
  api      = google_api_gateway_api.api.api_id
  lifecycle {
    create_before_destroy = true
  }

  openapi_documents {
    document {
      # Provide both a stable path and inline base64 contents
      path = "${path.module}/openapi.tmpl.yaml"
      contents = base64encode(templatefile("${path.module}/openapi.tmpl.yaml", {
        backend_url   = data.google_cloud_run_service.ai.status[0].url,
        upload_url    = google_cloud_run_service.upload.status[0].url,
        content_url   = google_cloud_run_service.content.status[0].url,
        events_url    = google_cloud_run_service.events.status[0].url,
        transcode_url = google_cloud_run_service.transcode.status[0].url
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.apigw_sa.email
    }
  }
  depends_on = [google_project_service.services, data.google_cloud_run_service.ai]
}

resource "google_api_gateway_gateway" "gateway" {
  provider   = google-beta
  gateway_id = "mychannel-gw"
  api_config = google_api_gateway_api_config.api_config.id
  region     = var.region
}

# Outputs
output "api_gateway_hostname" {
  value       = google_api_gateway_gateway.gateway.default_hostname
  description = "Default hostname for API Gateway"
}

output "upload_service_url" {
  value       = google_cloud_run_service.upload.status[0].url
  description = "Cloud Run URL for upload service"
}

output "transcode_service_url" {
  value       = google_cloud_run_service.transcode.status[0].url
  description = "Cloud Run URL for transcode service"
}

output "content_service_url" {
  value       = google_cloud_run_service.content.status[0].url
  description = "Cloud Run URL for content service"
}

output "events_service_url" {
  value       = google_cloud_run_service.events.status[0].url
  description = "Cloud Run URL for events service"
}

# Grant Cloud Build service account permissions to access Artifact Registry and GCS
resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

# Workaround: grant Compute Engine default SA read access to Cloud Build bucket
resource "google_project_iam_member" "compute_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# Compute Engine default SA needs to push to Artifact Registry and write logs
resource "google_project_iam_member" "compute_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_pubsub_topic" "events" {
  name = "events"
}

# Topic for media ingestion jobs
resource "google_pubsub_topic" "media_ingest" {
  name = "media-ingest"
}

# Topic for video features used for learning pipeline
resource "google_pubsub_topic" "video_features" {
  name = "video-features"
}

# BigQuery dataset for analytics
resource "google_bigquery_dataset" "analytics" {
  dataset_id    = "analytics"
  location      = "US"
  friendly_name = "MyChannel Analytics"
  description   = "Event analytics dataset"
}

# BigQuery table for events
resource "google_bigquery_table" "events" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "events"
  deletion_protection = false
  schema = jsonencode([
    { name = "timestamp", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "type", type = "STRING", mode = "NULLABLE" },
    { name = "ok", type = "BOOLEAN", mode = "NULLABLE" },
    { name = "metadata", type = "STRING", mode = "NULLABLE" }
  ])
}

# BigQuery table for video features
resource "google_bigquery_table" "video_features" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "video_features"
  deletion_protection = false
  schema = jsonencode([
    { name = "ingested_at", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "video_id", type = "STRING", mode = "NULLABLE" },
    { name = "uri", type = "STRING", mode = "NULLABLE" },
    { name = "labels", type = "STRING", mode = "REPEATED" },
    { name = "shots", type = "INTEGER", mode = "NULLABLE" },
    { name = "explicit_content", type = "BOOLEAN", mode = "NULLABLE" },
    { name = "text_annotations", type = "STRING", mode = "REPEATED" },
    { name = "object_annotations", type = "STRING", mode = "REPEATED" },
    { name = "duration_seconds", type = "FLOAT", mode = "NULLABLE" }
  ])
}

# Pub/Sub subscription that writes directly to BigQuery table
resource "google_pubsub_subscription" "events_bq" {
  name  = "events-bq"
  topic = google_pubsub_topic.events.name

  bigquery_config {
    table            = "${var.project_id}:${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.events.table_id}"
    use_table_schema = true
    write_metadata   = false
  }
}

# Pub/Sub subscription that writes video features into BigQuery table
resource "google_pubsub_subscription" "video_features_bq" {
  name  = "video-features-bq"
  topic = google_pubsub_topic.video_features.name

  bigquery_config {
    table            = "${var.project_id}:${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.video_features.table_id}"
    use_table_schema = true
    write_metadata   = false
  }
}

# Allow Pub/Sub service agent to write into BigQuery dataset
resource "google_bigquery_dataset_iam_member" "pubsub_bq_writer" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Cloud Storage bucket for media (provide unique name via var)
resource "google_storage_bucket" "media" {
  name                        = var.media_bucket_name
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
}

# Ingest bucket: receives raw uploads via signed URLs
resource "google_storage_bucket" "ingest" {
  name                        = var.ingest_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  cors {
    origin          = ["*"]
    method          = ["GET", "PUT", "POST", "HEAD"]
    response_header = ["*", "Authorization", "Content-Type"]
    max_age_seconds = 3600
  }
}

# Public bucket: serves transcoded HLS/MPD assets
resource "google_storage_bucket" "public" {
  name                        = var.public_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}


# Allow Cloud Run service account to read HLS output segments from the media bucket
resource "google_storage_bucket_iam_member" "media_viewer_run_svc" {
  bucket = var.media_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:run-svc@${var.project_id}.iam.gserviceaccount.com"
}

# Allow transcode service to write outputs to public bucket
resource "google_storage_bucket_iam_member" "public_object_admin_run_svc" {
  bucket = var.public_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:run-svc@${var.project_id}.iam.gserviceaccount.com"
}

# Allow runtime to read from ingest bucket if needed
resource "google_storage_bucket_iam_member" "ingest_viewer_run_svc" {
  bucket = var.ingest_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:run-svc@${var.project_id}.iam.gserviceaccount.com"
}

# BigQuery tables for plays, impressions, likes
resource "google_bigquery_table" "plays" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "plays"
  deletion_protection = false
  schema = jsonencode([
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "user_id", type = "STRING", mode = "NULLABLE" },
    { name = "video_id", type = "STRING", mode = "REQUIRED" },
    { name = "position", type = "FLOAT", mode = "NULLABLE" },
    { name = "autoplay", type = "BOOLEAN", mode = "NULLABLE" },
    { name = "device", type = "STRING", mode = "NULLABLE" },
    { name = "session_id", type = "STRING", mode = "NULLABLE" }
  ])
}

resource "google_bigquery_table" "impressions" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "impressions"
  deletion_protection = false
  schema = jsonencode([
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "user_id", type = "STRING", mode = "NULLABLE" },
    { name = "video_id", type = "STRING", mode = "REQUIRED" },
    { name = "context", type = "STRING", mode = "NULLABLE" },
    { name = "rank", type = "INTEGER", mode = "NULLABLE" }
  ])
}

resource "google_bigquery_table" "likes" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "likes"
  deletion_protection = false
  schema = jsonencode([
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "user_id", type = "STRING", mode = "REQUIRED" },
    { name = "video_id", type = "STRING", mode = "REQUIRED" }
  ])
}


