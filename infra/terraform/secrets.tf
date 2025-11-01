# Secret Manager secrets for services

locals {
  app_secrets = [
    "JWT_SECRET",
    "SUPABASE_URL",
    "SUPABASE_SERVICE_KEY",
    "ADS_BASE_URL",
    "TMDB_API_KEY",
    "RECAPTCHA_SECRET"
  ]
}

variable "provision_secret_versions" {
  type    = bool
  default = false
  description = "Whether to create placeholder latest versions for app secrets"
}

resource "google_secret_manager_secret" "app" {
  for_each  = toset(local.app_secrets)
  secret_id = each.value
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_latest" {
  for_each = var.provision_secret_versions ? google_secret_manager_secret.app : {}
  secret      = each.value.id
  secret_data = "TODO_SET_VALUE_IN_CICD"
}

# Allow Cloud Run runtime SA to access secrets
resource "google_secret_manager_secret_iam_member" "run_reader" {
  for_each  = google_secret_manager_secret.app
  project   = each.value.project
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_service_account.run_svc.email}"
}


