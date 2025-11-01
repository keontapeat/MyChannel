# Terraform stubs for Ingest/Rights Cloud Run and GCS proof bucket

# TODO: wire provider and project variables

# resource "google_storage_bucket" "proof" {
#   name          = var.proof_bucket
#   location      = var.region
#   force_destroy = true
#   lifecycle_rule { action { type = "Delete" } condition { age = 365 } }
# }

# resource "google_cloud_run_v2_service" "ingest" {
#   name     = "ingest-api"
#   location = var.region
#   template { containers { image = var.ingest_image env { name = "PROOF_BUCKET" value = var.proof_bucket } } }
# }

# resource "google_cloud_run_v2_service" "rights" {
#   name     = "rights-api"
#   location = var.region
#   template { containers { image = var.rights_image env { name = "PROOF_BUCKET" value = var.proof_bucket } } }
# }



