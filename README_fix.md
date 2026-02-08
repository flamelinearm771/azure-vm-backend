# VM Migration Fix & Verification Guide

**Resource Group:** `vm-migration`  
**Status:** Manual infrastructure created; awaiting verification and fixes  
**Date:** 2026-02-08

---

## Overview

Previously, deployment via Terraform failed due to Azure Student subscription policies. You manually created Azure resources in the `vm-migration` resource group. This guide helps you verify the current state and apply safe, idempotent fixes to align with the desired architecture.

---

## Quick Start

### 1. Run Discovery (Read-Only)
Check the current state of all resources and identify mismatches:

```bash
bash infra/scripts/fix-and-verify.sh
```

**Output:** A comprehensive report showing:
- VM inventory (expected vs. actual)
- Public IP assignments
- Load Balancer configuration
- NSG rules
- Pass/Fail status for each architectural requirement

**Exit Code:** 0 if PASS, non-zero if issues found

---

### 2. Preview Proposed Fixes (Dry-Run)
See exactly what commands will be executed before applying changes:

```bash
bash infra/scripts/fix-actions.sh --dry-run
```

**Output:** List of all Azure CLI commands that will run in `--apply` mode.

**No changes made in this mode.**

---

### 3. Apply Fixes (Interactive)
Execute the fixes with interactive confirmpts for destructive actions:

```bash
bash infra/scripts/fix-actions.sh --apply
```

**Prompts for:**
- Deletion of extra DB VM (if it exists)
- Other confirmation-required operations

**Destructive actions:** Only with explicit user confirmation

---

### 4. Auto-Apply All Fixes (Non-Interactive)
Skip prompts and apply all fixes including automatic deletion of extra DB VM:

```bash
bash infra/scripts/fix-actions.sh --apply --force-delete-db-vm
```

⚠️  **WARNING:** This deletes extra DB VM without confirmation. Use with caution.

---

### 5. Verify Final State
After applying fixes, re-run discovery to confirm all issues are resolved:

```bash
bash infra/scripts/fix-and-verify.sh
```

**Expected output:** All checks PASS

---

## Architectural Goals

### Goal 1: Application Layer
- **Expected:** 2 identical app VMs in `app-subnet` (10.0.0.0/24)
- **Access:** Both behind load balancer (single public IP)
- **No direct public IPs** on individual VMs
- **LB Backend:** Both app VMs registered
- **HA:** Availability Set or Zone distribution

### Goal 2: Database Layer
- **Expected:** 1 DB VM in `db-subnet` (10.0.1.0/24)
- **Access:** Private IP only (no public IP)
- **Isolation:** Accessible only from app-subnet (10.0.0.0/24) on port 5432
- **NSG Rule:** Source must be `10.0.0.0/24` (not `10.0.1.0/24`)

### Goal 3: Load Balancer
- **Public Endpoint:** Single public IP address
- **Backend Pool:** Both app VMs (app NICs)
- **Health Probe:** HTTP on port 80, path `/health`
- **Rules:** Port 80/443 from Internet → app VMs

### Goal 4: Security
- **App NSG:** Allow HTTP/HTTPS from Internet, all from LB
- **DB NSG:** Allow TCP 5432 only from app-subnet (10.0.0.0/24)
- **Public IPs:** Only on LB (not on individual VMs)

---

## Issues & Fixes

### Issue 1: Orphaned NIC with Public IP
**Symptom:** NIC `vm-migartion-virtual-machine-for-app-1916_z3` exists but no associated VM  
**Fix:** Delete orphaned NIC and its public IP resource

### Issue 2: Missing App VM 2
**Symptom:** Only 1 actual app VM exists; need 2 for HA  
**Fix:** Create second app VM (template clone from app-1)  
**Note:** Requires manual steps or Terraform re-apply (see below)

### Issue 3: App VM 1 Has Public IP
**Symptom:** App VM 1 has individual public IP (should use LB only)  
**Fix:** Delete public IP from app VM 1 NIC

### Issue 4: DB VMs in LB Backend Pool
**Symptom:** DB VM NICs registered in LB backend pool (should be app only)  
**Fix:** Remove DB VM NICs from backend pool

### Issue 5: Extra DB VM
**Symptom:** 2 DB VMs exist (db-1, db-2); need exactly 1  
**Fix:** Delete DB VM 2 (keep db-1 as primary)

### Issue 6: Wrong NSG Rule Source
**Symptom:** DB NSG rule allows from `10.0.1.0/24` (DB subnet itself)  
**Fix:** Update source to `10.0.0.0/24` (app subnet)

### Issue 7: Health Probe Not HTTP
**Symptom:** LB health probe is TCP only (not HTTP /health)  
**Fix:** Update probe protocol to HTTP with request path `/health`

---

## Creating App VM 2 (If Needed)

If `fix-and-verify.sh` shows "App VM 2 missing," you have two options:

### Option A: Use Terraform (Recommended)
```bash
cd infra/terraform

# Edit main.tf and ensure azurerm_linux_virtual_machine.app_vm_2 resource exists
# Also ensure the NIC (azurerm_network_interface.app_nic_2) is configured

# Then:
terraform init
terraform plan
terraform apply
```

### Option B: Manual Azure CLI
```bash
# Get App VM 1 details
az vm show -g vm-migration -n vm-migartion-virtual-machine-for-app-1 -o json \
  | jq '{imageReference, hardwareProfile, osProfile}'

# Create network interface for App VM 2
az network nic create \
  --resource-group vm-migration \
  --name vm-migartion-virtual-machine-for-app-2172_z2 \
  --vnet-name vm-migration-virtual-network \
  --subnet app-subnet \
  --no-wait

# Create the VM
az vm create \
  --resource-group vm-migration \
  --name vm-migartion-virtual-machine-for-app-2 \
  --nics vm-migartion-virtual-machine-for-app-2172_z2 \
  --image UbuntuLTS \
  --admin-username vm-app \
  --admin-password 'Virtual-Machine-App-1' \
  --size Standard_B2s \
  --custom-data infra/cloud-init/app-cloud-init.yaml

# Add NIC to LB backend pool
az network nic ip-config address-pool add \
  --resource-group vm-migration \
  --nic-name vm-migartion-virtual-machine-for-app-2172_z2 \
  --ip-config-name ipconfig1 \
  --lb-address-pool /subscriptions/e41ec793-5cda-4e62-a2ec-22ca1c330f5b/resourceGroups/vm-migration/providers/Microsoft.Network/loadBalancers/vm-migration-load-balancer/backendAddressPools/vm-migration-backend-pool
```

---

## Script Details

### fix-and-verify.sh
**Purpose:** Discovery and validation  
**What it does:**
1. Lists all VMs and their properties
2. Checks public IP assignments
3. Validates NSG rules
4. Confirms LB backend pool membership
5. Reports pass/fail for each requirement

**Output:** Color-coded status report  
**Side effects:** None (read-only)

### fix-actions.sh
**Purpose:** Apply architectural fixes  
**Modes:**
- `--dry-run` (default): Print commands without executing
- `--apply`: Execute commands with interactive prompts
- `--apply --force-delete-db-vm`: Execute all including auto-delete

**What it does:**
1. Discovers current resource names (NIC, IP, subnet names)
2. Removes orphaned NICs and PIPs
3. Removes PIPs from app VM NICs
4. Removes DB VM NICs from LB backend pool
5. Updates DB NSG rule source CIDR
6. Deletes extra DB VM (with or without prompt)
7. Updates LB health probe
8. (Optional) Creates App VM 2 (note in output)

**Safety:**
- Scoped to `vm-migration` RG only
- Default mode is --dry-run (no changes)
- Destructive actions prompt for confirmation
- All commands printed before execution

---

## Verification Checklist

After applying fixes, manually verify:

### ✓ Load Balancer Health
```bash
curl http://[LB_PUBLIC_IP]/health
# Expected: HTTP 200 OK
```

### ✓ VM Count
```bash
az vm list -g vm-migration --query "[].name" -o tsv
# Expected: 2 app VMs + 1 DB VM = 3 total
```

### ✓ Public IPs
```bash
az network public-ip list -g vm-migration --query "[].{name:name, ipAddress:ipAddress}" -o table
# Expected: Only LB public IP (not on app or DB VMs)
```

### ✓ NSG Rules
```bash
# Check DB NSG source is app-subnet
az network nsg rule show -g vm-migration --nsg-name network-security-group-db \
  --name network-security-group-db-inbound-rules -o json | jq '.sourceAddressPrefix'
# Expected: 10.0.0.0/24
```

### ✓ LB Backend Pool
```bash
az network lb address-pool list -g vm-migration --lb-name vm-migration-load-balancer \
  --query "[0].backendIPConfigurations[].id" -o json | jq length
# Expected: 2 (only app VMs)
```

### ✓ App VM Connectivity
```bash
# SSH into app VM via LB or bastion, then test:
curl http://localhost:80/health
# Expected: HTTP 200 OK
```

### ✓ DB VM Isolation
```bash
# From app VM, test DB connectivity:
psql -h [DB_PRIVATE_IP] -U quickclip_user -d quickclip_db -c "SELECT 1;"
# Expected: Connection successful

# From your local machine, DB should NOT be accessible:
# (TCP port 5432 should be blocked by NSG and no public IP)
```

---

## Troubleshooting

### LB Health Probe Failing

1. **Check app VM is running:**
   ```bash
   az vm get-instance-view -g vm-migration -n vm-migartion-virtual-machine-for-app-1 \
     --query "instanceView.statuses[].message" -o table
   ```

2. **Check health endpoint responds:**
   ```bash
   # SSH to app VM, then:
   curl http://localhost:80/health
   ```

3. **Check NSG allows port 80:**
   ```bash
   az network nsg rule list -g vm-migration --nsg-name network-security-group-app \
     --query "[?destinationPortRange=='80' || destinationPortRange=='*'].{name:name, access:access}" -o table
   ```

### Cannot SSH to App VM

**Root cause:** App VMs have no public IP (by design)

**Solutions:**
1. Use Azure Bastion (if configured)
2. Use `az vm run-command invoke` for commands:
   ```bash
   az vm run-command invoke \
     --resource-group vm-migration \
     --name vm-migartion-virtual-machine-for-app-1 \
     --command-id RunShellScript \
     --scripts "systemctl status quickclip-app.service"
   ```
3. Use Jump Box in same VNet

### Database Connection from App Fails

1. **Check DB NSG rule source:**
   ```bash
   az network nsg rule show -g vm-migration --nsg-name network-security-group-db \
     --name network-security-group-db-inbound-rules -o json | jq '.sourceAddressPrefix'
   # Must be: 10.0.0.0/24
   ```

2. **Check DB is listening:**
   ```bash
   # SSH to DB VM (from app VM or bastion)
   sudo systemctl status postgresql
   sudo ss -tlnp | grep 5432
   ```

3. **Test from app VM:**
   ```bash
   # Run from app VM
   telnet [DB_PRIVATE_IP] 5432
   ```

---

## Rollback

### Full Rollback (Delete All Resources)
```bash
az group delete -n vm-migration --yes
```

### Partial Rollback (Individual VM)
```bash
az vm delete -g vm-migration -n vm-migartion-virtual-machine-for-app-1 --yes
```

---

## Next Steps

1. **Run verification:** `bash infra/scripts/fix-and-verify.sh`
2. **Preview fixes:** `bash infra/scripts/fix-actions.sh --dry-run`
3. **Apply fixes:** `bash infra/scripts/fix-actions.sh --apply`
4. **Verify again:** `bash infra/scripts/fix-and-verify.sh`
5. **Test connectivity:** Curl LB health endpoint
6. **Update credentials.md** with actual IPs from `az vm list --show-details`

---

## Support

For issues:
1. Check `fix-and-verify.sh` output for specific failures
2. Review NSG rules: `az network nsg rule list -g vm-migration --nsg-name [NSG_NAME] -o table`
3. Check VM status: `az vm list -g vm-migration --show-details --query "[].{name:name, powerState:powerState}" -o table`
4. Review Azure Activity Log: `az monitor activity-log list -g vm-migration --output table`

