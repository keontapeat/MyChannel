# Simple HTTP Global Load Balancer with Cloud CDN for public bucket

variable "cdn_signed_key_name" {
  type        = string
  description = "Name for CDN signed URL key"
  default     = "mychannel-key"
}

variable "cdn_signed_key_value" {
  type        = string
  description = "Base64-encoded 128-bit key for signed URLs (hex or base64)"
  default     = ""
}

resource "google_compute_backend_bucket" "public_backend" {
  name        = "public-bucket-backend"
  bucket_name = var.public_bucket_name
  enable_cdn  = true
}

resource "google_compute_backend_bucket_signed_url_key" "key" {
  count           = var.cdn_signed_key_value != "" ? 1 : 0
  name            = var.cdn_signed_key_name
  key_value       = var.cdn_signed_key_value
  backend_bucket  = google_compute_backend_bucket.public_backend.name
  depends_on      = [google_compute_backend_bucket.public_backend]
}

resource "google_compute_url_map" "cdn" {
  name            = "mychannel-cdn-map"
  default_service = google_compute_backend_bucket.public_backend.id
}

resource "google_compute_target_http_proxy" "cdn" {
  name    = "mychannel-cdn-proxy"
  url_map = google_compute_url_map.cdn.id
}

resource "google_compute_global_address" "cdn_ip" {
  name = "mychannel-cdn-ip"
}

resource "google_compute_global_forwarding_rule" "cdn" {
  name                  = "mychannel-cdn-fw"
  ip_address            = google_compute_global_address.cdn_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.cdn.id
  load_balancing_scheme = "EXTERNAL"
}

output "cdn_ip" {
  value       = google_compute_global_address.cdn_ip.address
  description = "Global IP for CDN"
}


