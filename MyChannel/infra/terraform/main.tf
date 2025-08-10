terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.29.0"
    }
  }
}

provider "google" {
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

resource "google_service_account" "run_svc" {
  account_id   = "run-svc"
  display_name = "Cloud Run SA"
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
    "roles/pubsub.publisher"
  ])
  project = var.project_id
  role   = each.value
  member = "serviceAccount:${google_service_account.run_svc.email}"
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

# Render OpenAPI with backend URL
resource "local_file" "apigw_openapi" {
  filename = "${path.module}/apigateway_openapi.yaml"
  content  = templatefile("${path.module}/openapi.tmpl.yaml", {
    backend_url = data.google_cloud_run_service.ai.status[0].url
  })
}

# API Gateway API and config
resource "google_api_gateway_api" "api" {
  api_id = "mychannel-api"
}

resource "google_api_gateway_api_config" "api_config" {
  api      = google_api_gateway_api.api.name
  config_id = "v1"

  openapi_documents {
    document {
      path     = local_file.apigw_openapi.filename
      contents = file(local_file.apigw_openapi.filename)
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
  gateway_id = "mychannel-gw"
  api_config = google_api_gateway_api_config.api_config.id
  location   = var.region
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

# BigQuery dataset for analytics
resource "google_bigquery_dataset" "analytics" {
  dataset_id    = "analytics"
  location      = "US"
  friendly_name = "MyChannel Analytics"
  description   = "Event analytics dataset"
}

# BigQuery table for events
resource "google_bigquery_table" "events" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "events"
  deletion_protection = false
  schema = jsonencode([
    { name = "timestamp", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "type",      type = "STRING",     mode = "NULLABLE" },
    { name = "ok",        type = "BOOLEAN",    mode = "NULLABLE" },
    { name = "metadata",  type = "STRING",     mode = "NULLABLE" }
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


