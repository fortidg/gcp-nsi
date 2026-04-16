# NSI Script Compatibility with Unmanaged Instance Groups

## TL;DR

✅ **No changes needed to setup-nsi.sh or cleanup-nsi.sh**

The scripts work identically with both Managed Instance Groups (MIG) and Unmanaged Instance Groups (UIG).

## Why No Changes Are Required

### Script Dependencies

Both `setup-nsi.sh` and `cleanup-nsi.sh` only depend on:

1. **VPC Networks** - Retrieved from Terraform output
2. **Forwarding Rules** - Retrieved from Terraform output

Neither script directly references or depends on:
- ❌ Instance templates
- ❌ Managed instance groups
- ❌ Individual FortiGate instances
- ❌ Unmanaged instance groups

### What the Scripts Actually Do

#### setup-nsi.sh
```bash
# Gets these values from Terraform outputs:
INSPECTION_NETWORK=$(terraform output -json vpc_networks | jq -r '.inspection_vpc.name')
WEB_NETWORK=$(terraform output -json vpc_networks | jq -r '.web_vpc.name')
WEB2_NETWORK=$(terraform output -json vpc_networks | jq -r '.web2_vpc.name')
FORWARDING_RULE_A=$(terraform output -json forwarding_rules | jq -r '."us-central1-a".name')
FORWARDING_RULE_B=$(terraform output -json forwarding_rules | jq -r '."us-central1-b".name')
FORWARDING_RULE_C=$(terraform output -json forwarding_rules | jq -r '."us-central1-c".name')

# Then creates NSI resources using these values:
# 1. Creates intercept deployment group (references INSPECTION_NETWORK)
# 2. Creates intercept deployments (references FORWARDING_RULEs)
# 3. Creates intercept endpoint group
# 4. Associates endpoint groups with WEB_NETWORK and WEB2_NETWORK
# 5. Creates security profiles and policies
```

#### cleanup-nsi.sh
```bash
# Deletes NSI resources in reverse order
# Does NOT reference any compute instances or instance groups
# Only needs PROJECT_ID and ORGANIZATION_ID environment variables
```

### Architecture Independence

The NSI setup is **abstracted from the compute layer**:

```
┌────────────────────────────────────────────────────┐
│          NSI Layer (Scripts Operate Here)          │
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐  │
│  │ Intercept        │      │ Forwarding       │  │
│  │ Deployment Group │──────│ Rules            │  │
│  └──────────────────┘      └──────────────────┘  │
│                                     │              │
└─────────────────────────────────────┼──────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │      Backend Service              │
                    │   (Abstraction Layer)             │
                    └─────────────────┬─────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
              ▼                       ▼                       ▼
    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
    │ MIG              │    │ UIG (Zone A)     │    │ UIG (Zone A)     │
    │ (Old Arch)       │ OR │ UIG (Zone B)     │ OR │ + Custom Setup   │
    │                  │    │ UIG (Zone C)     │    │ + ...            │
    └──────────────────┘    └──────────────────┘    └──────────────────┘
```

**Key Point:** NSI intercept deployments reference **forwarding rules**, not instance groups directly. The forwarding rules point to the backend service, which can have any backend configuration (MIG, UIG, or even a mix).

## Verification

### Before Running Scripts

Verify the required outputs exist:

```bash
# Check VPC networks output
terraform output vpc_networks

# Expected output:
# {
#   "inspection_vpc" = { name = "fgt-nsi-fgt-nsi-ib-new" ... }
#   "management_vpc" = { name = "fgt-nsi-fgt-nsi-ib-new-mgmt" ... }
#   "web_vpc" = { name = "fgt-nsi-fgt-nsi-ib-new-web" ... }
#   "web2_vpc" = { name = "fgt-nsi-fgt-nsi-ib-new-web2" ... }
# }

# Check forwarding rules output
terraform output forwarding_rules

# Expected output:
# {
#   "us-central1-a" = { name = "fgt-us-central1a" ... }
#   "us-central1-b" = { name = "fgt-us-central1b" ... }
#   "us-central1-c" = { name = "fgt-us-central1c1" ... }
# }
```

### Testing the Scripts

```bash
# 1. Deploy infrastructure (UIG-based)
terraform apply

# 2. Verify outputs are available
terraform output vpc_networks
terraform output forwarding_rules

# 3. Run NSI setup (should work identically)
export PROJECT_ID="your-project-id"
export ORGANIZATION_ID="your-org-id"
./setup-nsi.sh

# Expected: All NSI resources created successfully

# 4. Verify NSI configuration
gcloud beta network-security intercept-deployment-groups list
gcloud beta network-security intercept-deployments list --location=us-central1-a
gcloud beta network-security intercept-endpoint-group-associations list

# 5. Test traffic between Web and Web2 VPCs

# 6. Clean up NSI (should work identically)
./cleanup-nsi.sh

# Expected: All NSI resources deleted successfully

# 7. Destroy infrastructure
terraform destroy
```

## Outputs Comparison

### MIG-based Deployment (Old)
```json
{
  "fortigate_instance_group": {
    "id": "projects/.../regionInstanceGroupManagers/fgt-nsi-fgt-nsi-us-central1-multi-ig",
    "name": "fgt-nsi-fgt-nsi-us-central1-multi-ig",
    "instance_group": "https://www.googleapis.com/.../instanceGroups/fgt-nsi-fgt-nsi-us-central1-multi-ig"
  },
  "vpc_networks": { ... },
  "forwarding_rules": { ... }
}
```

### UIG-based Deployment (New)
```json
{
  "fortigate_instances": {
    "us-central1-a": { "name": "fgt-nsi-fgt-nsi-us-central1-a", ... },
    "us-central1-b": { "name": "fgt-nsi-fgt-nsi-us-central1-b", ... },
    "us-central1-c": { "name": "fgt-nsi-fgt-nsi-us-central1-c", ... }
  },
  "fortigate_instance_groups": {
    "us-central1-a": { "name": "fgt-nsi-fgt-nsi-uig-us-central1-a", ... },
    "us-central1-b": { "name": "fgt-nsi-fgt-nsi-uig-us-central1-b", ... },
    "us-central1-c": { "name": "fgt-nsi-fgt-nsi-uig-us-central1-c", ... }
  },
  "vpc_networks": { ... },         # ← Scripts use this (unchanged)
  "forwarding_rules": { ... }      # ← Scripts use this (unchanged)
}
```

**Scripts only use `vpc_networks` and `forwarding_rules` - both unchanged!**

## Common Questions

### Q: Do I need to update the gcloud commands in the scripts?
**A:** No. The gcloud commands reference forwarding rules and networks, not instance groups.

### Q: Will NSI traffic inspection work with UIGs?
**A:** Yes, identically to MIGs. NSI doesn't care about the backend implementation.

### Q: Can I mix MIG and UIG in the same deployment?
**A:** Technically yes (backend service can have mixed backends), but not recommended. Choose one approach.

### Q: What if I want to go back to MIG?
**A:** 
1. Delete UIG resources via Terraform
2. Restore MIG configuration (from git history or `separated/` folder)
3. Run `terraform apply`
4. Scripts still work - no changes needed

### Q: Do I need to modify NSI commands for UIGs?
**A:** No. NSI intercept deployments reference forwarding rules, which are the same regardless of backend type.

## Script Execution Flow

Both scripts follow the same flow with UIGs:

### setup-nsi.sh Flow
```
1. Check environment variables (PROJECT_ID, ORGANIZATION_ID)
   ↓
2. Get Terraform outputs (vpc_networks, forwarding_rules)
   ↓
3. Create NSI Intercept Deployment Group
   ├─ References: INSPECTION_NETWORK (from VPC output)
   ↓
4. Create NSI Intercept Deployments (3 zones)
   ├─ References: FORWARDING_RULEs (from forwarding_rules output)
   ├─ Note: Forwarding rules → Backend Service → UIGs → FortiGate instances
   ↓
5. Create NSI Intercept Endpoint Group
   ↓
6. Associate Endpoint Group with Web VPCs
   ├─ References: WEB_NETWORK, WEB2_NETWORK (from VPC output)
   ↓
7. Create Security Profile & Profile Group
   ↓
8. Create & Apply Firewall Policy
   ↓
9. Done! NSI is active
```

### cleanup-nsi.sh Flow
```
1. Check environment variables (PROJECT_ID, ORGANIZATION_ID)
   ↓
2. Delete firewall policy associations (both Web VPCs)
   ↓
3. Delete firewall policy rules
   ↓
4. Delete firewall policy
   ↓
5. Delete security profile group
   ↓
6. Delete security profile
   ↓
7. Delete intercept endpoint group associations (both VPCs)
   ↓
8. Delete intercept endpoint group
   ↓
9. Delete intercept deployments (3 zones)
   ↓
10. Delete intercept deployment group
    ↓
11. Done! NSI resources removed, safe to run terraform destroy
```

## Summary

✅ **setup-nsi.sh** - No changes needed
✅ **cleanup-nsi.sh** - No changes needed
✅ **NSI functionality** - Identical to MIG deployment
✅ **Traffic inspection** - Works the same way
✅ **Scripts are architecture-agnostic** - Work with MIG, UIG, or custom setups

The conversion from MIG to UIG is **completely transparent** to the NSI setup and cleanup scripts!
