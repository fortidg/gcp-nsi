# Forwarding Rules for Internal Load Balancer
resource "google_compute_forwarding_rule" "fortigate_forwarding_rules" {
  for_each = {
    "us-central1-a" = {
      name   = "fgt-us-central1a"
      zone   = "${var.region}-a"
    }
    "us-central1-b" = {
      name   = "fgt-us-central1b"
      zone   = "${var.region}-b"
    }
    "us-central1-c" = {
      name   = "fgt-us-central1c1"
      zone   = "${var.region}-c"
    }
  }

  name                  = each.value.name
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  ip_protocol           = "UDP"
  ports                 = ["6081"]
  network_tier          = "PREMIUM"
  
  # Reference the backend service
  backend_service = google_compute_region_backend_service.fortigate_backend_service.id
  
  # Use the inspection subnet
  subnetwork = google_compute_subnetwork.subnets["inspection_central"].id

  # Note: allow_global_access must be false (default) for NSI intercept deployments
  # allow_global_access = false

  depends_on = [google_compute_region_backend_service.fortigate_backend_service]
}