# NSI Intercept resources require google-beta provider
# Note: These resources are currently in beta and may need to be created via gcloud CLI
# The following resources serve as placeholders and documentation

# For now, these NSI resources should be created using the gcloud commands:
# Reference the gcp-nsi.txt file for the exact gcloud commands needed

# Placeholder for NSI Intercept Deployment Group
# gcloud beta network-security intercept-deployment-groups create newfgt-nsi-ftnt-dg \
#   --location global \
#   --project <project-id> \
#   --network fgt-nsi-fgt-nsi-ib-new \
#   --no-async

# Placeholder for NSI Intercept Deployments 
# gcloud beta network-security intercept-deployments create fgt-nsi-us-central1a \
#   --location=us-central1-a \
#   --project=<project-id> \
#   --forwarding-rule=fgt-us-central1a \
#   --intercept-deployment-group=projects/<project-id>/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg \
#   --forwarding-rule-location=us-central1 \
#   --no-async

# Similar commands needed for us-central1b and us-central1c

# Placeholder for NSI Intercept Endpoint Group
# gcloud beta network-security intercept-endpoint-groups create newfgt-nsi-ftnt-epg \
#   --intercept-deployment-group newfgt-nsi-ftnt-dg \
#   --project <project-id> \
#   --location global \
#   --no-async

# Placeholder for NSI Intercept Endpoint Group Association  
# gcloud beta network-security intercept-endpoint-group-associations create new-fgt-nsi-ftnt-epg-assoc \
#   --intercept-endpoint-group newfgt-nsi-ftnt-epg \
#   --network fgt-nsi-fgt-nsi-ib-new-web \
#   --project <project-id> \
#   --location global \
#   --no-async

# Output values for reference after manual creation
output "nsi_manual_commands" {
  description = "Manual gcloud commands needed to complete NSI setup"
  value = {
    deployment_group = "gcloud beta network-security intercept-deployment-groups create newfgt-nsi-ftnt-dg --location global --project ${var.project_id} --network ${google_compute_network.vpc_networks["inspection"].name} --no-async"

    intercept_deployments = {
      us_central1a = "gcloud beta network-security intercept-deployments create fgt-nsi-us-central1a --location=us-central1-a --project=${var.project_id} --forwarding-rule=${google_compute_forwarding_rule.fortigate_forwarding_rules["us-central1-a"].name} --intercept-deployment-group=projects/${var.project_id}/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg --forwarding-rule-location=${var.region} --no-async"
      us_central1b = "gcloud beta network-security intercept-deployments create fgt-nsi-us-central1b --location=us-central1-b --project=${var.project_id} --forwarding-rule=${google_compute_forwarding_rule.fortigate_forwarding_rules["us-central1-b"].name} --intercept-deployment-group=projects/${var.project_id}/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg --forwarding-rule-location=${var.region} --no-async"
      us_central1c = "gcloud beta network-security intercept-deployments create fgt-nsi-us-central1c1 --location=us-central1-c --project=${var.project_id} --forwarding-rule=${google_compute_forwarding_rule.fortigate_forwarding_rules["us-central1-c"].name} --intercept-deployment-group=projects/${var.project_id}/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg --forwarding-rule-location=${var.region} --no-async"
    }

    endpoint_group = "gcloud beta network-security intercept-endpoint-groups create newfgt-nsi-ftnt-epg --intercept-deployment-group newfgt-nsi-ftnt-dg --project ${var.project_id} --location global --no-async"

    endpoint_group_association = "gcloud beta network-security intercept-endpoint-group-associations create new-fgt-nsi-ftnt-epg-assoc --intercept-endpoint-group newfgt-nsi-ftnt-epg --network ${google_compute_network.vpc_networks["web"].name} --project ${var.project_id} --location global --no-async"

    security_profile = "gcloud beta network-security security-profiles custom-intercept create newfgt-nsi-ftnt-sp1 --intercept-endpoint-group newfgt-nsi-ftnt-epg --billing-project ${var.project_id} --organization ${var.organization_id} --location global"

    security_profile_group = "gcloud beta network-security security-profile-groups create newfgt-nsi-ftnt-spg1 --custom-intercept-profile newfgt-nsi-ftnt-sp1 --billing-project ${var.project_id} --organization ${var.organization_id} --location global"

    firewall_policy = "gcloud compute network-firewall-policies create newfgt-nsi --project ${var.project_id} --global"

    firewall_policy_rules = {
      ingress = "gcloud beta compute network-firewall-policies rules create 10 --action=APPLY_SECURITY_PROFILE_GROUP --firewall-policy newfgt-nsi --global-firewall-policy --security-profile-group organizations/${var.organization_id}/locations/global/securityProfileGroups/newfgt-nsi-ftnt-spg1 --layer4-configs all --src-ip-ranges 0.0.0.0/0 --dest-ip-ranges 0.0.0.0/0 --direction INGRESS"
      egress  = "gcloud beta compute network-firewall-policies rules create 11 --action=APPLY_SECURITY_PROFILE_GROUP --firewall-policy newfgt-nsi --global-firewall-policy --security-profile-group organizations/${var.organization_id}/locations/global/securityProfileGroups/newfgt-nsi-ftnt-spg1 --layer4-configs all --src-ip-ranges 0.0.0.0/0 --dest-ip-ranges 0.0.0.0/0 --direction EGRESS"
    }

    firewall_policy_association = "gcloud compute network-firewall-policies associations create --name newfgt-nsi-policy-assoc --global-firewall-policy --firewall-policy newfgt-nsi --network ${google_compute_network.vpc_networks["web"].name} --project ${var.project_id}"
  }
}