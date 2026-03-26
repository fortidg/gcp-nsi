# Web Server VMs for testing NSI functionality
resource "google_compute_instance" "web_servers" {
  for_each = {
    "us-central1-a" = "fgt-nsi-web-us-central1a"
    "us-central1-b" = "fgt-nsi-web-us-central1b"
    "us-central1-c" = "fgt-nsi-web-us-central1c"
  }

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
    network    = google_compute_network.vpc_networks["web"].id
    subnetwork = google_compute_subnetwork.subnets["web_central"].id

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
  tags = ["web-server", "allow-http-https"]

  # Prevent accidental deletion
  lifecycle {
    create_before_destroy = true
  }
}

# Additional firewall rules for web servers
resource "google_compute_firewall" "web_server_firewall" {
  name        = "${local.prefix}-web-server-allow"
  network     = google_compute_network.vpc_networks["web"].id
  description = "Allow HTTP, HTTPS, and RDP to web servers"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3389"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}