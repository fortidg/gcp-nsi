# Compute Instance Template for FortiGate NSI
resource "google_compute_instance_template" "fortigate_template" {
  name        = "${local.prefix}-fgt-nsi762-v5-${random_string.suffix.result}"
  description = "FortiGate NSI instance template for traffic inspection"

  # Machine configuration based on gcloud command
  machine_type = var.fortigate_machine_type

  # Boot disk configuration
  disk {
    auto_delete  = true
    boot         = true
    device_name  = "instance-template-boot"
    mode         = "READ_WRITE"
    source_image = data.google_compute_image.fortigate_image.self_link
    disk_type    = "hyperdisk-balanced"
    disk_size_gb = 50
  }

  # Network interfaces
  # Port 1 - Data/Inspection interface
  network_interface {
    network    = google_compute_network.vpc_networks["inspection"].id
    subnetwork = google_compute_subnetwork.subnets["inspection_central"].id
    stack_type = "IPV4_ONLY"
    nic_type   = "GVNIC"
  }

  # Port 2 - Management interface
  network_interface {
    network    = google_compute_network.vpc_networks["management"].id
    subnetwork = google_compute_subnetwork.subnets["management_central"].id
    # network_tier       = "PREMIUM"
    stack_type = "IPV4_ONLY"
    nic_type   = "GVNIC"
    # Enable external IP for management access
    access_config {
      network_tier = "PREMIUM"
    }
  }

  # Service account for API access
  service_account {
    scopes = ["cloud-platform"]
  }

  # Instance metadata
  metadata = {
    enable-oslogin = "TRUE"
    user-data = templatefile("${path.module}/templates/fortigate-config.tpl", {
      admin_port        = var.admin_port
      admin_pass        = var.admin_password
      fmg_ip            = var.fmg_ip
      fmg               = var.fmg
      mgmt_gw           = google_compute_subnetwork.subnets["management_central"].gateway_address
      insp_gw           = google_compute_subnetwork.subnets["inspection_central"].gateway_address
      ilb_ip            = google_compute_address.ilb_ip.address
      health_check_port = var.health_check_port
      frontend_ips      = [for k, v in google_compute_address.ilb_frontend_ips : v.address]
    })
  }

  # Tags for firewall rules
  tags = ["fortigate-nsi", "allow-health-check"]

  # Enable IP forwarding for traffic inspection
  can_ip_forward = true

  lifecycle {
    create_before_destroy = true
  }
}