terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Read outputs from the root (parent) Terraform deployment
data "terraform_remote_state" "root" {
  backend = "local"
  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  # Convenience aliases into root state outputs
  project_id   = data.terraform_remote_state.root.outputs.project_summary.project_id
  region       = data.terraform_remote_state.root.outputs.project_summary.region
  admin_port   = data.terraform_remote_state.root.outputs.project_summary.admin_port
  machine_type = data.terraform_remote_state.root.outputs.project_summary.fortigate_machine_type
  mig_name     = data.terraform_remote_state.root.outputs.fortigate_instance_group.name

  inspection_subnet_name = data.terraform_remote_state.root.outputs.subnets.inspection_subnet.name
  management_subnet_name = data.terraform_remote_state.root.outputs.subnets.management_subnet.name
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# FortiGate public image
data "google_compute_image" "fortigate_image" {
  family  = "fortigate-76-payg"
  project = "fortigcp-project-001"
}

# Reference existing subnets by name from root state
data "google_compute_subnetwork" "inspection" {
  name   = local.inspection_subnet_name
  region = local.region
}

data "google_compute_subnetwork" "management" {
  name   = local.management_subnet_name
  region = local.region
}

# Unique suffix so the new template name doesn't collide with the existing one
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}
