# Firewall Rules
resource "google_compute_firewall" "firewall_rules" {
  for_each = local.firewall_rules

  name        = each.value.name
  network     = google_compute_network.vpc_networks[each.value.network].id
  direction   = each.value.direction
  priority    = each.value.priority
  description = each.value.description

  # Source ranges for ingress rules
  source_ranges = try(each.value.source_ranges, null)

  # Destination ranges for egress rules
  destination_ranges = try(each.value.destination_ranges, null)

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = try(allow.value.ports, null)
    }
  }
}