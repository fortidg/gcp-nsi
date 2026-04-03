locals {
  # Use override machine type if provided, otherwise fall back to what root deployed
  effective_machine_type = var.fortigate_machine_type != "" ? var.fortigate_machine_type : local.machine_type
}

resource "google_compute_instance_template" "fortigate_template" {
  name        = "${local.mig_name}-tpl-${random_string.suffix.result}"
  description = "FortiGate NSI instance template (replacement)"

  machine_type = local.effective_machine_type

  disk {
    auto_delete  = true
    boot         = true
    device_name  = "instance-template-boot"
    mode         = "READ_WRITE"
    source_image = data.google_compute_image.fortigate_image.self_link
    disk_type    = "hyperdisk-balanced"
    disk_size_gb = 50
  }

  # Port 1 - Data/Inspection interface
  network_interface {
    network    = data.google_compute_subnetwork.inspection.network
    subnetwork = data.google_compute_subnetwork.inspection.id
    stack_type = "IPV4_ONLY"
  }

  # Port 2 - Management interface (with external IP)
  network_interface {
    network    = data.google_compute_subnetwork.management.network
    subnetwork = data.google_compute_subnetwork.management.id
    stack_type = "IPV4_ONLY"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
    user-data = templatefile("${path.module}/templates/fortigate-config.tpl", {
      admin_port = local.admin_port
      admin_pass = var.admin_password
      fmg_ip     = var.fmg_ip
      fmg        = var.fmg
      mgmt_gw    = data.google_compute_subnetwork.management.gateway_address
      insp_gw    = data.google_compute_subnetwork.inspection.gateway_address
    })
  }

  tags           = ["fortigate-nsi", "allow-health-check"]
  can_ip_forward = true

  lifecycle {
    create_before_destroy = true
  }
}
