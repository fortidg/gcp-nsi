# Unmanaged Instance Group Configuration

## Overview

This deployment uses **Unmanaged Instance Groups (UIG)** instead of Managed Instance Groups (MIG) for the FortiGate NSI deployment. This provides more control over individual instances while maintaining compatibility with GCP load balancers and NSI.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Backend Service (Regional ILB)                 │
│           (fgt-nsi-fgt-nsi-us-central1-lb)                 │
└────────────────────┬────────────────────────────────────────┘
                     │
     ┌───────────────┼───────────────┐
     │               │               │
     ▼               ▼               ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│  UIG    │    │  UIG    │    │  UIG    │
│ Zone A  │    │ Zone B  │    │ Zone C  │
└────┬────┘    └────┬────┘    └────┬────┘
     │              │              │
     ▼              ▼              ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│FortiGate│    │FortiGate│    │FortiGate│
│Instance │    │Instance │    │Instance │
│  (A)    │    │  (B)    │    │  (C)    │
└─────────┘    └─────────┘    └─────────┘
```

## Key Differences from MIG

### Unmanaged Instance Group (Current)

**Structure:**
- 3 individual FortiGate instances (manually created)
- 3 unmanaged instance groups (one per zone, containing one instance each)
- Backend service references all 3 unmanaged groups

**Management:**
- ✅ Full control over each instance
- ✅ Instances are NOT auto-replaced if unhealthy
- ✅ Can manually modify instance configurations
- ✅ Each instance maintains persistent identity
- ✅ Can SSH/RDP directly to specific instances for troubleshooting

**Features Removed:**
- ❌ No auto-healing (unhealthy instances stay unhealthy)
- ❌ No auto-scaling (fixed at 3 instances)
- ❌ No rolling updates (must update instances manually)
- ❌ No automatic redistribution across zones

**Features Retained:**
- ✅ Internal load balancer distribution
- ✅ Health checks (for load balancer backend health)
- ✅ NSI intercept deployment per zone
- ✅ Multi-zone deployment for HA

### Managed Instance Group (Previous)

**Structure:**
- 1 regional managed instance group
- Instance template defines configuration
- MIG creates/manages instances automatically

**Management:**
- ✅ Auto-healing replaces unhealthy instances
- ✅ Auto-scaling based on load (if configured)
- ✅ Rolling updates via template changes
- ✅ Automatic distribution and rebalancing

## Resources Created

### Individual Instances
```hcl
resource "google_compute_instance" "fortigate_instances" {
  for_each = toset(var.zones)
  # Creates: fgt-nsi-fgt-nsi-us-central1-a
  #          fgt-nsi-fgt-nsi-us-central1-b
  #          fgt-nsi-fgt-nsi-us-central1-c
}
```

**Each instance has:**
- Port 1: Inspection VPC interface (internal, no external IP)
- Port 2: Management VPC interface (internal + external IP)
- Tags: `fortigate-nsi`, `allow-health-check`
- IP forwarding: Enabled
- User-data: FortiGate bootstrap configuration

### Unmanaged Instance Groups
```hcl
resource "google_compute_instance_group" "fortigate_uig" {
  for_each = toset(var.zones)
  # Creates: fgt-nsi-fgt-nsi-uig-us-central1-a
  #          fgt-nsi-fgt-nsi-uig-us-central1-b
  #          fgt-nsi-fgt-nsi-uig-us-central1-c
}
```

**Each group:**
- Contains exactly 1 FortiGate instance
- Named port "geneve" on port 6081
- Used as backend for regional backend service

### Backend Service
```hcl
resource "google_compute_region_backend_service" "fortigate_backend_service" {
  # 3 backends (one per zone/UIG)
  dynamic "backend" {
    for_each = var.zones
    content {
      group = google_compute_instance_group.fortigate_uig[backend.value].id
    }
  }
}
```

## Management Operations

### View Instances
```bash
# List all FortiGate instances
gcloud compute instances list --filter="name~'fgt-nsi-fgt-nsi-us-central1'"

# Get details of specific instance
gcloud compute instances describe fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a

# Get external IPs for management access
terraform output fortigate_instances
```

### Access FortiGate Management
```bash
# Get management IPs
MGMT_IP=$(terraform output -json fortigate_instances | jq -r '.["us-central1-a"].management_ext_ip')

# Access FortiGate GUI
echo "https://${MGMT_IP}:8443"

# SSH to FortiGate
gcloud compute ssh fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a
```

### Start/Stop Instances
```bash
# Stop an instance (for maintenance)
gcloud compute instances stop fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a

# Start an instance
gcloud compute instances start fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a

# Restart an instance
gcloud compute instances reset fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a
```

### Update Instance Configuration
```bash
# Update instance metadata (e.g., change FortiGate config)
gcloud compute instances add-metadata fgt-nsi-fgt-nsi-us-central1-a \
    --zone=us-central1-a \
    --metadata-from-file user-data=templates/fortigate-config.tpl

# After updating, restart the instance
gcloud compute instances reset fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a
```

### Check Instance Health
```bash
# Check backend service health
gcloud compute backend-services get-health fgt-nsi-fgt-nsi-us-central1-lb \
    --region=us-central1

# Check instance logs
gcloud compute instances get-serial-port-output fgt-nsi-fgt-nsi-us-central1-a \
    --zone=us-central1-a
```

## NSI Compatibility

The unmanaged instance group configuration is **fully compatible** with NSI:

### Forwarding Rules
Each zone has a forwarding rule pointing to the backend service:
- `fgt-us-central1a` → Backend Service → UIG Zone A → FortiGate Instance A
- `fgt-us-central1b` → Backend Service → UIG Zone B → FortiGate Instance B
- `fgt-us-central1c` → Backend Service → UIG Zone C → FortiGate Instance C

### NSI Intercept Deployments
```bash
# NSI creates intercept deployment per zone, referencing forwarding rules
gcloud beta network-security intercept-deployments create fgt-nsi-us-central1a \
    --location=us-central1-a \
    --forwarding-rule=fgt-us-central1a \
    --intercept-deployment-group=newfgt-nsi-ftnt-dg
```

### Traffic Flow
1. Traffic from Web/Web2 VPCs hits NSI intercept point
2. NSI sends GENEVE-encapsulated traffic to forwarding rule
3. Forwarding rule distributes to backend service
4. Backend service selects healthy backend (UIG)
5. Traffic reaches FortiGate instance for inspection
6. FortiGate inspects and returns verdict to NSI
7. NSI forwards traffic to destination

## When to Use Unmanaged vs. Managed

### Use Unmanaged Instance Groups When:
- ✅ Running demos or PoCs
- ✅ Need predictable, stable instances
- ✅ Want to manually control updates
- ✅ Need to troubleshoot specific instances
- ✅ Testing FortiGate configurations
- ✅ Small, fixed-size deployments (3-5 instances)

### Use Managed Instance Groups When:
- ✅ Production deployments
- ✅ Need auto-healing capability
- ✅ Want auto-scaling
- ✅ Large deployments (>5 instances)
- ✅ Frequent template updates
- ✅ Require automated failover

## Troubleshooting

### Issue: Instance not receiving traffic

**Check:**
```bash
# 1. Verify instance is healthy
gcloud compute backend-services get-health fgt-nsi-fgt-nsi-us-central1-lb --region=us-central1

# 2. Check health check from instance
# SSH to FortiGate and verify port 8080 responds

# 3. Verify instance is in the UIG
gcloud compute instance-groups unmanaged list-instances fgt-nsi-fgt-nsi-uig-us-central1-a \
    --zone=us-central1-a
```

### Issue: Need to replace an instance

**Steps:**
```bash
# 1. Remove instance from UIG (optional, prevents traffic)
gcloud compute instance-groups unmanaged remove-instances fgt-nsi-fgt-nsi-uig-us-central1-a \
    --zone=us-central1-a \
    --instances=fgt-nsi-fgt-nsi-us-central1-a

# 2. Delete the instance
terraform destroy -target=google_compute_instance.fortigate_instances[\"us-central1-a\"]

# 3. Recreate the instance
terraform apply -target=google_compute_instance.fortigate_instances[\"us-central1-a\"]

# 4. Recreate the UIG (automatically includes new instance)
terraform apply -target=google_compute_instance_group.fortigate_uig[\"us-central1-a\"]
```

### Issue: Want to update FortiGate configuration

**Option 1: Update via Terraform**
```bash
# 1. Edit templates/fortigate-config.tpl
# 2. Apply changes
terraform apply

# 3. Restart instances to pick up new config
gcloud compute instances reset fgt-nsi-fgt-nsi-us-central1-a --zone=us-central1-a
gcloud compute instances reset fgt-nsi-fgt-nsi-us-central1-b --zone=us-central1-b
gcloud compute instances reset fgt-nsi-fgt-nsi-us-central1-c --zone=us-central1-c
```

**Option 2: Update via FortiGate GUI**
```bash
# 1. Access FortiGate management interface
# 2. Make changes via GUI
# 3. Changes persist on instance disk
# Note: Changes will be lost if instance is recreated via Terraform
```

## Migration Path

### To Convert Back to MIG:

1. Delete the unmanaged instance group resources
2. Uncomment the MIG configuration in a separate branch
3. Use the `update-template/` directory for MIG-based deployment
4. Update backend service to point to MIG

### To Convert from MIG to UIG:

Already done! The current configuration uses UIG.

## Performance Considerations

**Unmanaged Instance Groups:**
- Load balancing works the same as MIG
- No performance difference for NSI traffic inspection
- Slightly simpler architecture (no MIG overhead)
- Easier to debug performance issues per instance

**Capacity Planning:**
- Each FortiGate instance handles ~5-10 Gbps (depends on inspection depth)
- 3 instances = ~15-30 Gbps total capacity
- Scale by adding more instances and UIGs manually
- Update backend service to include new UIGs

## Best Practices

1. **Documentation**: Document manual changes to instances
2. **Backups**: Export FortiGate configs regularly
3. **Monitoring**: Set up Cloud Monitoring alerts for instance health
4. **Updates**: Test updates on one instance before applying to all
5. **Disaster Recovery**: Keep Terraform state backed up

## Terraform Commands

```bash
# View FortiGate instances
terraform state list | grep fortigate_instances

# View specific instance
terraform state show 'google_compute_instance.fortigate_instances["us-central1-a"]'

# Recreate specific instance
terraform taint 'google_compute_instance.fortigate_instances["us-central1-a"]'
terraform apply

# View all unmanaged instance groups
terraform state list | grep fortigate_uig

# Get all FortiGate outputs
terraform output fortigate_instances
terraform output fortigate_instance_groups
```

## Summary

The unmanaged instance group configuration provides:
- ✅ Full control over FortiGate instances
- ✅ Predictable behavior for demos and testing
- ✅ Compatible with NSI traffic inspection
- ✅ Easy troubleshooting and debugging
- ✅ Manual but deliberate scaling

Perfect for NSI demonstrations, testing, and environments where manual control is preferred over automation.
