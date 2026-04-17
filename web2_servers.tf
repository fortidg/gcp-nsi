# Web Server VMs in Web2 VPC for NSI traffic inspection demonstration
resource "google_compute_instance" "web2_servers" {
  for_each = { for zone in var.zones : zone => "fgt-nsi-web2-${replace(zone, "-", "")}" }

  name         = each.value
  machine_type = "e2-medium"
  zone         = each.key

  boot_disk {
    initialize_params {
      image = "projects/windows-cloud/global/images/family/windows-2025"
      size  = 50
      type  = "pd-balanced"
    }
    auto_delete = true
  }

  network_interface {
    network    = google_compute_network.vpc_networks["web2"].id
    subnetwork = google_compute_subnetwork.subnets["web2_central"].id

    access_config {
      network_tier = "PREMIUM"
    }
  }

  # Windows license and metadata
  metadata = {
    enable-oslogin = "FALSE"
    # Add your Windows license key here if needed
    # windows-keys = "your-windows-key-here"
  }

  # Allow HTTP/HTTPS traffic
  tags = ["web2-server", "allow-http-https"]

  # Prevent accidental deletion
  lifecycle {
    create_before_destroy = true
  }
}

# Firewall rules for web2 servers
resource "google_compute_firewall" "web2_server_firewall" {
  name        = "${local.prefix}-web2-server-allow"
  network     = google_compute_network.vpc_networks["web2"].id
  description = "Allow HTTP, HTTPS, and RDP to web2 servers"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3389"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web2-server"]
}
