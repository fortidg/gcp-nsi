# Update the MIG to use the new template and trigger a rolling replacement.
# A null_resource is used because the MIG is managed by the parent Terraform state;
# importing it here would conflict with that state.
resource "null_resource" "mig_template_update" {
  triggers = {
    # Re-run whenever the template changes
    template_self_link = google_compute_instance_template.fortigate_template.self_link
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "Updating MIG '${local.mig_name}' to template '${google_compute_instance_template.fortigate_template.self_link}'..."
      gcloud compute instance-groups managed set-instance-template "${local.mig_name}" \
        --template="${google_compute_instance_template.fortigate_template.self_link}" \
        --region="${local.region}" \
        --project="${local.project_id}"

      echo "Triggering rolling replacement (max-surge=3, max-unavailable=0)..."
      gcloud compute instance-groups managed rolling-action replace "${local.mig_name}" \
        --region="${local.region}" \
        --project="${local.project_id}" \
        --max-surge=3 \
        --max-unavailable=0

      echo "Done. Monitor progress with:"
      echo "  gcloud compute instance-groups managed describe ${local.mig_name} --region=${local.region} --project=${local.project_id}"
    EOT
  }
}
