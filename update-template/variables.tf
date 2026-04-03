# project_id, region, admin_port, machine_type, and mig_name are all read
# automatically from the root deployment's terraform.tfstate.
# Only supply values that are not stored in state.

variable "admin_password" {
  description = "Admin password for FortiGate (sensitive — not stored in root state)"
  type        = string
  sensitive   = true
}

variable "fortigate_machine_type" {
  description = "Override the machine type from root state. Leave empty to use the value from root state."
  type        = string
  default     = ""
}

variable "fmg" {
  description = "Will FortiManager be used? (true/false)"
  type        = string
  default     = "false"
}

variable "fmg_ip" {
  description = "FortiManager IP address (required when fmg = true)"
  type        = string
  default     = ""
}
