# Reserved static IP addresses for ILB forwarding rules frontend IPs
# These IPs are used as frontend IPs for each forwarding rule
# and configured as secondary IPs on FortiGate loopback interface
resource "google_compute_address" "ilb_frontend_ips" {
  for_each = {
    "us-central1-a" = {
      name = "${local.prefix}-frontend-us-central1a"
      zone = "${var.region}-a"
    }
    "us-central1-b" = {
      name = "${local.prefix}-frontend-us-central1b"
      zone = "${var.region}-b"
    }
    "us-central1-c" = {
      name = "${local.prefix}-frontend-us-central1c"
      zone = "${var.region}-c"
    }
  }

  name         = each.value.name
  description  = "Static frontend IP for ILB forwarding rule in ${each.key}"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.subnets["inspection_central"].id
  region       = var.region
}
