# Managed Instance Group for FortiGate NSI
resource "google_compute_region_instance_group_manager" "fortigate_mig" {
  name               = "${local.prefix}-fgt-nsi-${var.region}-multi-ig"
  base_instance_name = "${local.prefix}-fgt-nsi"
  region             = var.region
  target_size        = var.fortigate_instance_count

  version {
    instance_template = google_compute_instance_template.fortigate_template.id
  }

  # Distribution across zones
  distribution_policy_zones = var.zones

  # Auto healing policy
  auto_healing_policies {
    health_check      = google_compute_health_check.fortigate_health_check.id
    initial_delay_sec = 600
  }

  # Update policy
  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 3
    max_unavailable_fixed        = 0
  }

  # Named ports for load balancer
  named_port {
    name = "geneve"
    port = 6081
  }

  lifecycle {
    create_before_destroy = true
  }
}