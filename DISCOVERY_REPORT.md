# VM Migration Discovery Report

**Date:** 2026-02-08  
**Resource Group:** `vm-migration`  
**Location:** `centralindia`  
**Status:** Manual infrastructure created; architecture validation and fixes needed

---

## Current State Summary

### VMs Inventory
| Name | Type | Subnet | Private IP | Public IP | Status |
|------|------|--------|-----------|-----------|--------|
| `vm-migartion-virtual-machine-for-app-1` | App | app-subnet | 10.0.0.4 | 20.207.67.82 | ✓ Running |
| `vm-migartion-virtual-machine-for-app-1916_z3` (orphaned) | App | app-subnet | 10.0.0.6 | 20.207.67.85 | ⚠ NO VM |
| `vm-migartion-virtual-machine-for-db-1` | DB | db-subnet | 10.0.1.4 | ✗ None | ✓ Running |
| `vm-migartion-virtual-machine-for-db-2` | DB | db-subnet | 10.0.1.5 | ✗ None | ✓ Running |

### Network Interfaces
| NIC Name | VM | Subnet | Private IP | Public IP | LB Backend |
|----------|-----|--------|-----------|-----------|------------|
| `vm-migartion-virtual-machine-for-app-1172_z2` | app-1 | app-subnet | 10.0.0.4 | 20.207.67.82 | ✓ Yes |
| `vm-migartion-virtual-machine-for-app-1916_z3` | (orphaned) | app-subnet | 10.0.0.6 | 20.207.67.85 | ✓ Yes (orphaned) |
| `vm-migartion-virtual-machine-for-db-1311_z2` | db-1 | db-subnet | 10.0.1.4 | ✗ None | ✓ Yes (incorrect) |
| `vm-migartion-virtual-machine-for-db-1742_z3` | db-2 | db-subnet | 10.0.1.5 | ✗ None | ✓ Yes (incorrect) |

### Load Balancer
- **Name:** `vm-migration-load-balancer`
- **Public IP:** `20.204.249.182` (via `vm-migration-public-ip`)
- **Backend Pool:** `vm-migration-backend-pool`
  - **Members:** 4 NICs (app-1, app-orphaned, db-1, db-2) — **ISSUE: DB VMs should NOT be in LB backend pool**
- **Health Probe:** `vm-migration-load-balancing-health-probe`
  - **Protocol:** TCP (port 80)
  - **Issue:** TCP only, not HTTP /health

### NSG Configuration

#### `network-security-group-app` (App Subnet)
| Rule Name | Direction | Protocol | Port | Source | Access |
|-----------|-----------|----------|------|--------|--------|
| `network-security-group-app-inbound-rules` | Inbound | TCP | * | Internet | Allow |
| `in-bound-security-rule-for-azure-load-balancer` | Inbound | * | * | AzureLoadBalancer | Allow |

#### `network-security-group-db` (DB Subnet)
| Rule Name | Direction | Protocol | Port | Source | Access |
|-----------|-----------|----------|------|--------|--------|
| `network-security-group-db-inbound-rules` | Inbound | TCP | 5432 | **10.0.1.0/24** | Allow | **ISSUE: Should be 10.0.0.0/24 (app subnet) not 10.0.1.0/24 (db subnet itself)**
| `in-bound-security-rule-for-azure-load-balancer` | Inbound | * | * | AzureLoadBalancer | Allow |

---

## Architecture Goals vs. Current State

### Goal 1: App Layer (Exactly 2 VMs behind LB)
- **Desired:** 2 app VMs in `app-subnet`, only 1 public IP (LB), both in LB backend pool
- **Current:** 
  - ✗ Only 1 actual app VM (`vm-migartion-virtual-machine-for-app-1`)
  - ✗ 1 orphaned NIC with public IP (`vm-migartion-virtual-machine-for-app-1916_z3`) — no associated VM
  - ✗ App VM has individual public IP (should only be LB IP)
  - ⚠ Need to create `vm-migartion-virtual-machine-for-app-2`

**Required Fixes:**
1. Delete orphaned NIC `vm-migartion-virtual-machine-for-app-1916_z3` and its public IP
2. Create second app VM `vm-migartion-virtual-machine-for-app-2` with no public IP
3. Remove public IP from app VM 1
4. Add app-2 NIC to LB backend pool

### Goal 2: DB Layer (Exactly 1 VM, no public IP, secured)
- **Desired:** 1 DB VM in `db-subnet`, no public IP, DB port accessible only from app-subnet
- **Current:**
  - ✗ 2 DB VMs exist (should be 1)
  - ✓ Both have no public IP (good)
  - ✗ Both are in LB backend pool (should not be)
  - ✗ DB NSG rule allows from 10.0.1.0/24 (itself) instead of 10.0.0.0/24 (app subnet)

**Required Fixes:**
1. Delete DB VM 2 and its NIC (keep db-1 as primary)
2. Remove both DB NIC ipconfigs from LB backend pool
3. Update DB NSG rule: change source from `10.0.1.0/24` to `10.0.0.0/24`

### Goal 3: Load Balancer Health Probe
- **Desired:** HTTP probe on port 80, path `/health`
- **Current:** TCP probe only (port 80)

**Required Fix:**
1. Update probe to HTTP with request path `/health`

### Goal 4: Security Rules
- **Desired:** App NSG allows inbound from Internet on standard ports (80, 443); DB NSG allows only from app-subnet (10.0.0.0/24)
- **Current:**
  - App NSG: Allows all TCP from Internet (port unspecified — may be too permissive)
  - DB NSG: Wrong source CIDR

**Required Fixes:**
1. Refine app NSG to specify ports 80, 443
2. Fix DB NSG source from `10.0.1.0/24` → `10.0.0.0/24`

---

## Action Plan

### Dry-Run Mode (Script: `fix-and-verify.sh` + `fix-actions.sh --dry-run`)
1. **Display** current state (discovery commands)
2. **List** proposed changes without executing
3. **Exit code:** 0 if PASS, non-zero if mismatches found

### Apply Mode (Script: `fix-actions.sh --apply --force-delete-db-vm`)
1. Delete orphaned NIC and its public IP
2. Delete DB VM 2 and its NIC
3. Remove public IP from app VM 1
4. Remove DB NICs from LB backend pool
5. Update DB NSG rule source CIDR
6. Create app VM 2 (clone of app VM 1, no public IP)
7. Add app VM 2 NIC to LB backend pool
8. Update LB health probe to HTTP /health
9. Verify final state

---

## Summary of Issues Found

| Issue | Severity | Fix Category |
|-------|----------|--------------|
| Orphaned NIC with public IP in app-subnet | High | Delete orphaned resources |
| Only 1 actual app VM (need 2) | High | Create missing VM |
| App VM has public IP (violates LB design) | High | Remove public IP, use LB only |
| DB VMs in LB backend pool | High | Remove from backend pool |
| DB NSG rule allows from wrong subnet (10.0.1.0/24 instead of 10.0.0.0/24) | High | Update NSG rule |
| 2 DB VMs (need exactly 1) | Medium | Delete extra DB VM |
| LB health probe is TCP only (not HTTP /health) | Medium | Update probe configuration |
| App NSG allows all TCP from Internet (should specify ports) | Low | Refine port ranges |

---

## Next Steps

1. Run discovery: `bash infra/scripts/fix-and-verify.sh`
2. Review proposed fixes: `bash infra/scripts/fix-actions.sh --dry-run`
3. Apply fixes (with confirmation): `bash infra/scripts/fix-actions.sh --apply --force-delete-db-vm`
4. Verify final state: `bash infra/scripts/fix-and-verify.sh`

