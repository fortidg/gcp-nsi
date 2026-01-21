# Network Outputs
output "vpc_networks" {
  description = "Created VPC networks"
  value = {
    inspection_vpc = {
      id   = google_compute_network.vpc_networks["inspection"].id
      name = google_compute_network.vpc_networks["inspection"].name
    }
    management_vpc = {
      id   = google_compute_network.vpc_networks["management"].id
      name = google_compute_network.vpc_networks["management"].name
    }
    web_vpc = {
      id   = google_compute_network.vpc_networks["web"].id
      name = google_compute_network.vpc_networks["web"].name
    }
  }
}

output "subnets" {
  description = "Created subnets"
  value = {
    inspection_subnet = {
      id         = google_compute_subnetwork.subnets["inspection_west"].id
      name       = google_compute_subnetwork.subnets["inspection_west"].name
      cidr_range = google_compute_subnetwork.subnets["inspection_west"].ip_cidr_range
    }
    management_subnet = {
      id         = google_compute_subnetwork.subnets["management_west"].id
      name       = google_compute_subnetwork.subnets["management_west"].name
      cidr_range = google_compute_subnetwork.subnets["management_west"].ip_cidr_range
    }
    web_subnet = {
      id         = google_compute_subnetwork.subnets["web_west"].id
      name       = google_compute_subnetwork.subnets["web_west"].name
      cidr_range = google_compute_subnetwork.subnets["web_west"].ip_cidr_range
    }
  }
}

# FortiGate Outputs
output "fortigate_instance_template" {
  description = "FortiGate instance template details"
  value = {
    id   = google_compute_instance_template.fortigate_template.id
    name = google_compute_instance_template.fortigate_template.name
  }
}

output "fortigate_instance_group" {
  description = "FortiGate managed instance group details"
  value = {
    id            = google_compute_region_instance_group_manager.fortigate_mig.id
    name          = google_compute_region_instance_group_manager.fortigate_mig.name
    instance_group = google_compute_region_instance_group_manager.fortigate_mig.instance_group
  }
}

# Load Balancer Outputs
output "backend_service" {
  description = "Backend service details"
  value = {
    id   = google_compute_region_backend_service.fortigate_backend_service.id
    name = google_compute_region_backend_service.fortigate_backend_service.name
  }
}

output "health_check" {
  description = "Health check details"
  value = {
    id   = google_compute_health_check.fortigate_health_check.id
    name = google_compute_health_check.fortigate_health_check.name
  }
}

output "forwarding_rules" {
  description = "Internal load balancer forwarding rules"
  value = {
    for k, v in google_compute_forwarding_rule.fortigate_forwarding_rules : k => {
      id         = v.id
      name       = v.name
      ip_address = v.ip_address
    }
  }
}

# Firewall Rules Output
output "firewall_rules" {
  description = "Created firewall rules"
  value = {
    for k, v in google_compute_firewall.firewall_rules : k => {
      id   = v.id
      name = v.name
    }
  }
}

# Instructions for NSI Deployment
output "nsi_deployment_instructions" {
  description = "Instructions for setting up NSI deployment groups"
  value = <<-EOT
To complete the NSI deployment, create deployment groups that reference these forwarding rules:

Forwarding Rules for NSI deployment groups:
%{for k, v in google_compute_forwarding_rule.fortigate_forwarding_rules}
- Zone ${k}: ${v.name} (IP: ${v.ip_address})
%{endfor}

Use these forwarding rules when configuring your NSI deployment group in the GCP Console.
The FortiGate instances are now ready to inspect traffic routed through the NSI.

Management access will be available through the FortiGate instances' public IP addresses on port ${var.admin_port}.
EOT
}

output "project_summary" {
  description = "Summary of the deployed resources"
  value = {
    project_id             = var.project_id
    region                = var.region
    fortigate_machine_type = var.fortigate_machine_type
    instance_count        = var.fortigate_instance_count
    zones                 = var.zones
    admin_port           = var.admin_port
  }
}