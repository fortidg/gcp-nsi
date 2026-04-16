# Backend Service for FortiGate NSI Load Balancer
resource "google_compute_region_backend_service" "fortigate_backend_service" {
  name                  = "${local.prefix}-fgt-nsi-${var.region}-lb"
  description           = "Backend service for FortiGate NSI load balancer with unmanaged instance groups"
  region                = var.region
  protocol              = "UDP"
  load_balancing_scheme = "INTERNAL"

  # Backends pointing to unmanaged instance groups (one per zone)
  dynamic "backend" {
    for_each = var.zones
    content {
      group          = google_compute_instance_group.fortigate_uig[backend.value].id
      balancing_mode = "CONNECTION"
    }
  }

  # Health check
  health_checks = [google_compute_health_check.fortigate_health_check.id]

  # Session affinity for consistent traffic routing
  session_affinity = "CLIENT_IP"

  # Connection draining timeout
  connection_draining_timeout_sec = 300

  # Enable logging
  enable_cdn = false

  # Timeout settings
  timeout_sec = 30
}