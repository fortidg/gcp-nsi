# VPC Peering between Web VPC and Web2 VPC
# This enables NSI traffic inspection demonstration between two VPCs

# Peering from Web VPC to Web2 VPC
resource "google_compute_network_peering" "web_to_web2" {
  name         = "${local.prefix}-web-to-web2-peering"
  network      = google_compute_network.vpc_networks["web"].id
  peer_network = google_compute_network.vpc_networks["web2"].id

  # Export custom routes to peer network
  export_custom_routes = true
  import_custom_routes = true

  # Export subnet routes with public IP
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}

# Peering from Web2 VPC to Web VPC (bidirectional peering required)
resource "google_compute_network_peering" "web2_to_web" {
  name         = "${local.prefix}-web2-to-web-peering"
  network      = google_compute_network.vpc_networks["web2"].id
  peer_network = google_compute_network.vpc_networks["web"].id

  # Export custom routes to peer network
  export_custom_routes = true
  import_custom_routes = true

  # Export subnet routes with public IP
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true

  # Ensure the first peering is created before this one
  depends_on = [google_compute_network_peering.web_to_web2]
}
