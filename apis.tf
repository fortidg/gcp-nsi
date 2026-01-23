# Required APIs for NSI deployment
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "networksecurity.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}