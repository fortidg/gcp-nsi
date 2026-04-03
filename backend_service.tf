# Backend Service for FortiGate NSI Load Balancer
resource "google_compute_region_backend_service" "fortigate_backend_service" {
  name                  = "${local.prefix}-fgt-nsi-${var.region}-lb"
  description           = "Backend service for FortiGate NSI load balancer"
  region                = var.region
  protocol              = "UDP"
  load_balancing_scheme = "INTERNAL"

  # Backend pointing to the FortiGate MIG
  backend {
    group          = google_compute_region_instance_group_manager.fortigate_mig.instance_group
    balancing_mode = "CONNECTION"
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