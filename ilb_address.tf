# Reserved static IP address for FortiGate loopback interface
# This IP is used as the loopback interface IP on FortiGate instances to receive health probes
# Note: This is NOT assigned to the forwarding rules - they get their own ephemeral IPs
resource "google_compute_address" "ilb_ip" {
  name         = "${local.prefix}-loopback-ip"
  description  = "Static IP for FortiGate loopback interface to receive health probes"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.subnets["inspection_central"].id
  region       = var.region
}
