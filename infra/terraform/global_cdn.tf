# Global CDN Configuration for MyChannel
# Optimized for worldwide video delivery with edge caching

# Cloud CDN for global video delivery
resource "google_compute_global_address" "cdn_ip" {
  name = "mychannel-cdn-ip"
}

resource "google_compute_backend_bucket" "video_backend" {
  name        = "mychannel-video-backend"
  description = "Backend bucket for video content"
  bucket_name = google_storage_bucket.video_storage.name
  enable_cdn  = true

  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    max_ttl                      = 86400
    client_ttl                   = 3600
    negative_caching             = true
    negative_caching_policy {
      code = 404
      ttl  = 120
    }
    negative_caching_policy {
      code = 410
      ttl  = 120
    }
    serve_while_stale = 86400
    
    cache_key_policy {
      include_host           = true
      include_protocol       = true
      include_query_string   = true
      query_string_whitelist = ["v", "quality", "format"]
    }
  }
}

# URL Map for CDN routing
resource "google_compute_url_map" "cdn_url_map" {
  name            = "mychannel-cdn-url-map"
  description     = "URL map for MyChannel CDN"
  default_service = google_compute_backend_bucket.video_backend.id

  host_rule {
    hosts        = ["cdn.mychannel.com", "*.cdn.mychannel.com"]
    path_matcher = "video-paths"
  }

  path_matcher {
    name            = "video-paths"
    default_service = google_compute_backend_bucket.video_backend.id

    path_rule {
      paths   = ["/videos/*", "/thumbnails/*", "/hls/*"]
      service = google_compute_backend_bucket.video_backend.id
    }

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.api_backend.id
    }
  }
}

# SSL Certificate for CDN
resource "google_compute_managed_ssl_certificate" "cdn_ssl" {
  name = "mychannel-cdn-ssl"

  managed {
    domains = [
      "cdn.mychannel.com",
      "video.mychannel.com",
      "thumbnails.mychannel.com"
    ]
  }
}

# HTTPS Proxy for CDN
resource "google_compute_target_https_proxy" "cdn_https_proxy" {
  name             = "mychannel-cdn-https-proxy"
  url_map          = google_compute_url_map.cdn_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cdn_ssl.id]
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "cdn_forwarding_rule" {
  name       = "mychannel-cdn-forwarding-rule"
  target     = google_compute_target_https_proxy.cdn_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.cdn_ip.address
}

# HTTP to HTTPS Redirect
resource "google_compute_url_map" "cdn_http_redirect" {
  name = "mychannel-cdn-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "cdn_http_proxy" {
  name    = "mychannel-cdn-http-proxy"
  url_map = google_compute_url_map.cdn_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "cdn_http_forwarding_rule" {
  name       = "mychannel-cdn-http-forwarding-rule"
  target     = google_compute_target_http_proxy.cdn_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.cdn_ip.address
}

# Backend Service for API endpoints
resource "google_compute_backend_service" "api_backend" {
  name                  = "mychannel-api-backend"
  description           = "Backend service for API endpoints"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn            = true
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_instance_group_manager.api_group.instance_group
  }

  health_checks = [google_compute_health_check.api_health_check.id]

  cdn_policy {
    cache_mode                   = "USE_ORIGIN_HEADERS"
    default_ttl                  = 0
    max_ttl                      = 3600
    client_ttl                   = 0
    negative_caching             = false
    serve_while_stale           = 0
    
    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = false
    }
  }
}

# Health Check for API Backend
resource "google_compute_health_check" "api_health_check" {
  name               = "mychannel-api-health-check"
  check_interval_sec = 30
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

# Instance Group Manager for API servers
resource "google_compute_instance_group_manager" "api_group" {
  name               = "mychannel-api-group"
  base_instance_name = "mychannel-api"
  zone               = var.zone
  target_size        = 3

  version {
    instance_template = google_compute_instance_template.api_template.id
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.api_health_check.id
    initial_delay_sec = 300
  }
}

# Instance Template for API servers
resource "google_compute_instance_template" "api_template" {
  name         = "mychannel-api-template"
  machine_type = "e2-medium"

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")

  service_account {
    email  = google_service_account.api_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["mychannel-api", "http-server"]
}

# Service Account for API servers
resource "google_service_account" "api_service_account" {
  account_id   = "mychannel-api-sa"
  display_name = "MyChannel API Service Account"
}

# Storage Bucket for Video Content
resource "google_storage_bucket" "video_storage" {
  name          = "${var.project_id}-video-storage"
  location      = "US"
  storage_class = "STANDARD"

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 1095  # 3 years
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }
}

# IAM binding for public read access to video content
resource "google_storage_bucket_iam_binding" "video_storage_public_read" {
  bucket = google_storage_bucket.video_storage.name
  role   = "roles/storage.objectViewer"

  members = [
    "allUsers",
  ]
}

# Cloud Armor Security Policy
resource "google_compute_security_policy" "cdn_security_policy" {
  name        = "mychannel-cdn-security-policy"
  description = "Security policy for MyChannel CDN"

  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600
    }
  }

  # Block known bad IPs
  rule {
    action   = "deny(403)"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [
          "192.0.2.0/24",  # Example bad IP range
          "198.51.100.0/24"
        ]
      }
    }
  }

  # Default allow rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# Apply security policy to backend service
resource "google_compute_backend_service" "api_backend_with_security" {
  name                  = "mychannel-api-backend-secure"
  description           = "Secure backend service for API endpoints"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn            = true
  load_balancing_scheme = "EXTERNAL"
  security_policy       = google_compute_security_policy.cdn_security_policy.id

  backend {
    group = google_compute_instance_group_manager.api_group.instance_group
  }

  health_checks = [google_compute_health_check.api_health_check.id]
}

# DNS Records for CDN
resource "google_dns_record_set" "cdn_a_record" {
  count = var.dns_zone_name != "" ? 1 : 0
  
  name         = "cdn.${var.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.cdn_ip.address]
}

resource "google_dns_record_set" "video_cname_record" {
  count = var.dns_zone_name != "" ? 1 : 0
  
  name         = "video.${var.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["cdn.${var.domain_name}."]
}

resource "google_dns_record_set" "thumbnails_cname_record" {
  count = var.dns_zone_name != "" ? 1 : 0
  
  name         = "thumbnails.${var.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["cdn.${var.domain_name}."]
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "domain_name" {
  description = "Domain name for the CDN"
  type        = string
  default     = "mychannel.com"
}

variable "dns_zone_name" {
  description = "DNS zone name in Cloud DNS"
  type        = string
  default     = ""
}

# Outputs
output "cdn_ip_address" {
  description = "IP address of the CDN"
  value       = google_compute_global_address.cdn_ip.address
}

output "video_storage_bucket" {
  description = "Name of the video storage bucket"
  value       = google_storage_bucket.video_storage.name
}

output "cdn_urls" {
  description = "CDN URLs"
  value = {
    main       = "https://cdn.${var.domain_name}"
    video      = "https://video.${var.domain_name}"
    thumbnails = "https://thumbnails.${var.domain_name}"
  }
}

