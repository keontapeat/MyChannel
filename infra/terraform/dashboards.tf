resource "google_monitoring_dashboard" "cloud_run_overview" {
  dashboard_json = <<EOF
{
  "displayName": "MyChannel - Cloud Run Overview",
  "gridLayout": {
    "columns": 2,
    "widgets": [
      {
        "title": "Requests per second",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\"",
                  "aggregation": { "alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE" }
                }
              },
              "plotType": "LINE"
            }
          ]
        }
      },
      {
        "title": "p95 latency (s)",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\"",
                  "aggregation": { "alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_PERCENTILE_95" }
                }
              },
              "plotType": "LINE"
            }
          ]
        }
      },
      {
        "title": "5xx error rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_count\" metric.label.response_code_class=\"5xx\" resource.type=\"cloud_run_revision\"",
                  "aggregation": { "alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE" }
                }
              },
              "plotType": "LINE"
            }
          ]
        }
      }
    ]
  }
}
EOF
}

resource "google_monitoring_dashboard" "pubsub_overview" {
  dashboard_json = <<EOF
{
  "displayName": "MyChannel - Pub/Sub Overview",
  "gridLayout": {"columns": 2, "widgets": [
    {"title": "Publish rate", "xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {"filter": "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\"", "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE"}}}, "plotType": "LINE"}]}},
    {"title": "Subscription ack latency", "xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {"filter": "metric.type=\"pubsub.googleapis.com/subscription/ack_latency\"", "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_PERCENTILE_95"}}}, "plotType": "LINE"}]}}
  ]}
}
EOF
}

resource "google_monitoring_dashboard" "functions_overview" {
  dashboard_json = <<EOF
{
  "displayName": "MyChannel - Functions Overview",
  "gridLayout": {"columns": 2, "widgets": [
    {"title": "Invocations", "xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {"filter": "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\"", "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE"}}}, "plotType": "LINE"}]}},
    {"title": "Errors", "xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {"filter": "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" metric.label.status=\"error\"", "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE"}}}, "plotType": "LINE"}]}}
  ]}
}
EOF
}

resource "google_monitoring_dashboard" "cdn_overview" {
  dashboard_json = <<EOF
{
  "displayName": "MyChannel - CDN Overview",
  "gridLayout": {"columns": 2, "widgets": [
    {"title": "Bytes served", "xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {"filter": "metric.type=\"cdn.googleapis.com/byte_count\"", "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE"}}}, "plotType": "LINE"}]}},
    {"title": "Cache hit ratio", "xyChart": {"dataSets": [{"timeSeriesQuery": {"timeSeriesFilter": {"filter": "metric.type=\"cdn.googleapis.com/cache_hit_ratio\"", "aggregation": {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_MEAN"}}}, "plotType": "LINE"}]}}
  ]}
}
EOF
}


