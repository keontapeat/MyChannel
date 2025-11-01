terraform {
  required_providers { google = { source = "hashicorp/google" version = ">= 5.0.0" } }
}

provider "google" {
  project = var.project
  region  = var.region
}

variable "project" {}
variable "region" { default = "us-central1" }

resource "google_secret_manager_secret" "stripe" {
  secret_id = "STRIPE_SECRET"
  replication { automatic = true }
}

# Cloud Run service placeholders (container build handled by CI)
resource "google_cloud_run_v2_service" "ads" {
  name     = "ads"
  location = var.region
  template { containers { image = var.ads_image } }
}

variable "ads_image" { description = "Ads container image" }



