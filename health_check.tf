# Health Check for FortiGate instances
resource "google_compute_health_check" "fortigate_health_check" {
  name                = "${local.prefix}-doc-nsi-hc"
  description         = "Health check for FortiGate NSI instances"
  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

# Alternative HTTP health check for backward compatibility with reference
resource "google_compute_http_health_check" "fortigate_legacy_health_check" {
  name                = "${local.prefix}-doc-nsi-hc-legacy"
  description         = "Legacy HTTP health check for FortiGate NSI instances"
  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
  port                = 8080
  request_path        = "/"
}