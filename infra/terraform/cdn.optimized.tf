# Cloud CDN Configuration for Global Content Delivery
# Reduces latency to <100ms worldwide

resource "google_compute_backend_bucket" "media_cdn" {
  name        = "mychannel-media-cdn"
  bucket_name = google_storage_bucket.media.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    client_ttl        = 3600
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400

    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = false
    }

    negative_caching_policy {
      code = 404
      ttl  = 120
    }

    negative_caching_policy {
      code = 410
      ttl  = 120
    }
  }

  compression_mode = "AUTOMATIC"
}

resource "google_compute_url_map" "cdn_url_map" {
  name            = "mychannel-cdn-url-map"
  default_service = google_compute_backend_bucket.media_cdn.id

  host_rule {
    hosts        = ["cdn.mychannel.live"]
    path_matcher = "media"
  }

  path_matcher {
    name            = "media"
    default_service = google_compute_backend_bucket.media_cdn.id

    path_rule {
      paths   = ["/videos/*"]
      service = google_compute_backend_bucket.media_cdn.id
    }

    path_rule {
      paths   = ["/images/*"]
      service = google_compute_backend_bucket.media_cdn.id
    }

    path_rule {
      paths   = ["/streams/*"]
      service = google_compute_backend_bucket.media_cdn.id
    }
  }
}

resource "google_compute_target_https_proxy" "cdn_proxy" {
  name             = "mychannel-cdn-proxy"
  url_map          = google_compute_url_map.cdn_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cdn_cert.id]
}

resource "google_compute_managed_ssl_certificate" "cdn_cert" {
  name = "mychannel-cdn-cert"

  managed {
    domains = ["cdn.mychannel.live"]
  }
}

resource "google_compute_global_forwarding_rule" "cdn_forwarding_rule" {
  name       = "mychannel-cdn-forwarding-rule"
  target     = google_compute_target_https_proxy.cdn_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.cdn_ip.address
}

resource "google_compute_global_address" "cdn_ip" {
  name = "mychannel-cdn-ip"
}

# Output CDN URL
output "cdn_url" {
  value = "https://cdn.mychannel.live"
}

output "cdn_ip" {
  value = google_compute_global_address.cdn_ip.address
}
