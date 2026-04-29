# Web Server VMs in Web2 VPC for NSI traffic inspection demonstration
resource "google_compute_instance" "web2_servers" {
  for_each = {
    "us-central1-a" = "fgt-nsi-web2-us-central1a"
    "us-central1-b" = "fgt-nsi-web2-us-central1b"
    "us-central1-c" = "fgt-nsi-web2-us-central1c"
  }

  name         = each.value
  machine_type = "e2-medium"
  zone         = each.key

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 20
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

  # Startup script to install iperf3 and apache2
  metadata = {
    enable-oslogin = "TRUE"
    startup-script = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y iperf3 apache2

      # Configure iperf3 as a service
      cat > /etc/systemd/system/iperf3.service <<'IPERF_EOF'
      [Unit]
      Description=iPerf3 Server
      After=network.target

      [Service]
      Type=simple
      ExecStart=/usr/bin/iperf3 -s
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
      IPERF_EOF

      # Start and enable services
      systemctl daemon-reload
      systemctl enable iperf3
      systemctl start iperf3
      systemctl enable apache2
      systemctl start apache2

      # Create a simple index page with hostname
      echo "<h1>NSI Test Server Web2 - $(hostname)</h1><p>Zone: ${each.key}</p>" > /var/www/html/index.html
    EOF
  }

  # Allow HTTP/HTTPS and iperf3 traffic
  tags = ["web2-server", "allow-http-https", "allow-iperf3"]

  # Prevent accidental deletion
  lifecycle {
    create_before_destroy = true
  }
}

# Firewall rules for web2 servers
resource "google_compute_firewall" "web2_server_firewall" {
  name        = "${local.prefix}-web2-server-allow"
  network     = google_compute_network.vpc_networks["web2"].id
  description = "Allow HTTP, HTTPS, SSH, and iperf3 to web2 servers"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "5201"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web2-server", "allow-iperf3"]
}
