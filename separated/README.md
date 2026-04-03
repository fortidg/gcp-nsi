# separated

## Why this folder exists

The root Terraform deployment (`/home/ubuntu/gcp-nsi`) deploys everything in a single state: the FortiGate security infrastructure **and** the workloads being protected. This works for a quick demo but does not reflect how NSI is used in production.

In a real GCP Network Security Integration (NSI) deployment, the infrastructure is owned and operated by two distinct teams — often in separate GCP projects:

| Role | Responsibility |
|---|---|
| **Producer** | Deploys and operates the FortiGate security appliances. Owns the inspection VPC, MIG, load balancer, and the NSI intercept deployment group. |
| **Consumer** | Deploys the workloads to be protected. Associates their VPC with the producer's intercept endpoint group to route traffic through FortiGate for inspection. |

This folder provides that separation. Each sub-folder is an **independent Terraform root module** with its own state, owned by the respective team.

---

## Architecture overview

```
Producer project                         Consumer project
─────────────────────────────────        ─────────────────────────────
Inspection VPC                           Web VPC
  └── FortiGate MIG (3 zones)              └── Web servers (Windows)
  └── Internal UDP LB (GENEVE 6081)
  └── NSI Intercept Deployment Group  ──▶  NSI Endpoint Group Association
  └── Intercept Deployments (per zone)
Management VPC
  └── FortiGate port2 (admin access)
```

Traffic from the consumer VPC is intercepted by GCP and tunnelled via GENEVE to the FortiGate MIG for inspection before being forwarded to its destination.

---

## Folder structure

```
separated/
├── producer/                  # Security infrastructure (FortiGate + NSI intercept)
│   ├── instance_template.tf   # FortiGate instance template
│   ├── instance_group.tf      # Regional MIG across 3 zones
│   ├── health_check.tf        # TCP health check on port 8080
│   ├── backend_service.tf     # Internal UDP load balancer backend
│   ├── forwarding_rules.tf    # Per-zone GENEVE (UDP 6081) forwarding rules
│   ├── nsi_intercept.tf       # NSI intercept resources + gcloud output commands
│   └── templates/
│       └── fortigate-config.tpl  # FortiGate bootstrap cloud-init config
│
└── consumer/                  # Workload infrastructure (web servers)
    ├── web_servers.tf         # Windows web server VMs + firewall rules
    └── templates/             # (reserved for future consumer templates)
```

> **Note:** Each sub-folder references shared resources (VPCs, subnets, firewall rules) that are defined in the root deployment. If deploying these modules independently, you will need to add the missing `main.tf`, `variables.tf`, `networks.tf`, and `firewall.tf` files from the root, or reference those resources via `data` sources / `terraform_remote_state`.

---

## Deployment order

NSI resources have strict dependency ordering. Deploy in this sequence:

### 1. Producer — Terraform

```bash
cd separated/producer
terraform init
terraform apply
```

This creates the FortiGate MIG, load balancer, and forwarding rules. The `nsi_intercept.tf` output will print the exact `gcloud` commands needed for the next step.

### 2. Producer — NSI intercept resources (gcloud)

After `terraform apply`, run the printed `gcloud` commands in order:

```
1. intercept-deployment-groups create
2. intercept-deployments create   (one per zone: us-central1-a, b, c)
3. intercept-endpoint-groups create
4. intercept-endpoint-group-associations create
5. security-profiles custom-intercept create
6. security-profile-groups create
7. network-firewall-policies create
8. network-firewall-policies rules create  (INGRESS rule 10, EGRESS rule 11)
9. network-firewall-policies associations create
```

Alternatively, use the `setup-nsi.sh` script in the root folder:

```bash
PROJECT_ID=<project-id> ORGANIZATION_ID=<org-id> ../../setup-nsi.sh
```

### 3. Consumer — Terraform

```bash
cd separated/consumer
terraform init
terraform apply
```

This deploys the web server VMs in the web VPC. The NSI firewall policy association (step 9 above) ensures their traffic is automatically intercepted and inspected by FortiGate.

---

## Teardown order

Teardown must be done in **reverse** order, and NSI intercept resources must be removed before Terraform destroy (they hold references to forwarding rules).

### 1. Remove NSI intercept resources (gcloud)

Use the cleanup script from the root folder:

```bash
PROJECT_ID=<project-id> ORGANIZATION_ID=<org-id> ../../cleanup-nsi.sh
```

### 2. Consumer — Terraform destroy

```bash
cd separated/consumer
terraform destroy --auto-approve
```

### 3. Producer — Terraform destroy

```bash
cd separated/producer
terraform destroy --auto-approve
```