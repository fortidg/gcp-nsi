# update-template

## Why this folder exists

The root Terraform deployment (`/home/ubuntu/gcp-nsi`) creates a FortiGate Managed Instance Group (MIG) bound to a specific instance template. GCP instance templates are **immutable** — you cannot edit them in place. To change the FortiGate configuration (e.g. firmware image, machine type, bootstrap config), you must:

1. Create a new instance template
2. Update the MIG to point at the new template
3. Trigger a rolling replacement so existing instances are recreated from the new template

Because the MIG is owned by the root Terraform state, modifying the template there causes Terraform to destroy and recreate the MIG itself, which would also tear down all associated NSI intercept deployments. This folder solves that problem by creating a **new template in a separate state** and using `gcloud` to perform the rolling update without touching the root state.

---

## How it works

1. Reads `../terraform.tfstate` via `terraform_remote_state` to automatically obtain:
   - `project_id`, `region`, `admin_port`, `machine_type`
   - MIG name
   - Inspection and management subnet names (used to look up gateway addresses)
2. Creates a new `google_compute_instance_template` with a unique name suffix.
3. On `apply`, runs `gcloud compute instance-groups managed set-instance-template` to point the MIG at the new template, then triggers `rolling-action replace` with `max-surge=3, max-unavailable=0` for a zero-downtime rollout.

Re-running `apply` after a subsequent change will create another new template and trigger another rolling replacement automatically.

---

## Prerequisites

- The root deployment (`../`) must have been applied at least once — `../terraform.tfstate` must exist and be current.
- `gcloud` must be authenticated and have sufficient IAM permissions (`compute.instanceTemplates.create`, `compute.instanceGroupManagers.update`).
- Terraform >= 1.0.0

---

## Usage

```bash
cd /home/ubuntu/gcp-nsi/update-template

# 1. Copy the example vars file
cp terraform.tfvars.example terraform.tfvars

# 2. Set your admin password (only required variable)
#    Edit terraform.tfvars and set admin_password

# 3. Initialise
terraform init

# 4. Preview changes
terraform plan

# 5. Apply — creates the new template and triggers the rolling replacement
terraform apply
```

### Monitor the rollout

```bash
gcloud compute instance-groups managed describe <mig-name> \
  --region=us-central1 \
  --project=<project-id>
```

Or watch instance actions in real time:

```bash
gcloud compute instance-groups managed list-instances <mig-name> \
  --region=us-central1 \
  --project=<project-id>
```

---

## Variables

| Variable | Required | Description |
|---|---|---|
| `admin_password` | **Yes** | FortiGate admin password. Sensitive — never stored in state. |
| `fortigate_machine_type` | No | Override the GCP machine type. Defaults to the value used in the root deployment. |
| `fmg` | No | Set to `"true"` to enable FortiManager central management. Default: `"false"`. |
| `fmg_ip` | No | IP address of the FortiManager (required when `fmg = "true"`). |

All other values (`project_id`, `region`, `admin_port`, MIG name, subnet names) are read automatically from `../terraform.tfstate`.

---

## File structure

```
update-template/
├── main.tf                    # Provider, remote state, data sources for image & subnets
├── variables.tf               # Minimal variable set (admin_password + optional overrides)
├── instance_template.tf       # New google_compute_instance_template resource
├── mig_update.tf              # null_resource that updates the MIG and triggers rolling replace
├── terraform.tfvars.example   # Example values — copy to terraform.tfvars
└── templates/
    └── fortigate-config.tpl   # FortiGate bootstrap cloud-init config
```
