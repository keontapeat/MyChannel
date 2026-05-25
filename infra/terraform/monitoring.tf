resource "google_monitoring_alert_policy" "run_5xx_ratio" {
  display_name = "Cloud Run 5xx ratio > 1% (5m)"
  combiner     = "OR"

  conditions {
    display_name = "5xx_ratio_gt_1pct"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch run_revision
        | metric 'run.googleapis.com/request_count'
        | filter metric.response_code_class == 5
        | align rate(60s)
        | group_by [resource.service_name], [sum(value.request_count)]
        | join (
            fetch run_revision
            | metric 'run.googleapis.com/request_count'
            | align rate(60s)
            | group_by [resource.service_name], [sum(value.request_count)]
          )
        | value val(0) / val(1)
        | condition gt(0.01)
      EOT
      duration = "300s"
      trigger { count = 1 }
    }
  }
  notification_channels = []
  enabled               = true
}

resource "google_monitoring_alert_policy" "run_p95_latency" {
  display_name = "Cloud Run p95 latency > 800ms (5m)"
  combiner     = "OR"

  conditions {
    display_name = "p95_latency_gt_800ms"
    condition_threshold {
      filter = "resource.type=\"cloud_run_revision\" metric.type=\"run.googleapis.com/request_latencies\""
      duration   = "300s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.8
      trigger { count = 1 }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields    = ["resource.service_name"]
      }
    }
  }
  notification_channels = []
  enabled               = true
}




