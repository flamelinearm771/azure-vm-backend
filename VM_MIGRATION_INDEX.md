# VM Migration - Complete Discovery & Fix Package

**Status:** ✓ Ready for Execution  
**Resource Group:** `vm-migration` (centralindia)  
**Generated:** 2026-02-08  
**Model:** GitHub Copilot (Claude Haiku 4.5)

---

## 📋 Quick Navigation

### For Immediate Action
1. **[EXECUTION_SUMMARY.md](EXECUTION_SUMMARY.md)** ← START HERE
   - 5-minute quick start guide
   - Step-by-step commands
   - Safety guarantees

2. **[infra/scripts/fix-and-verify.sh](infra/scripts/fix-and-verify.sh)**
   - Run discovery: `bash infra/scripts/fix-and-verify.sh`
   - Shows current vs. desired state

3. **[infra/scripts/fix-actions.sh](infra/scripts/fix-actions.sh)**
   - Preview: `bash infra/scripts/fix-actions.sh --dry-run`
   - Apply: `bash infra/scripts/fix-actions.sh --apply`

### For Understanding Architecture
- **[DISCOVERY_REPORT.md](DISCOVERY_REPORT.md)** — Detailed findings & comparison
- **[README_fix.md](README_fix.md)** — Full operations manual

### For Reference
- **[AZURE_CLI_COMMANDS_REFERENCE.md](AZURE_CLI_COMMANDS_REFERENCE.md)** — All `az` commands used
- **[credential.md](credential.md)** — Credentials template (⚠️ not in git)

---

## 🎯 What Was Done

### Discovery Phase
✓ Ran 11 discovery commands against `vm-migration` resource group  
✓ Analyzed 4 VMs, 4 NICs, 3 public IPs, load balancer, 2 NSGs  
✓ Identified 7 architectural mismatches  
✓ Created comprehensive report  

### Fix Preparation Phase
✓ Created 2 safe, idempotent bash scripts  
✓ Generated cloud-init provisioning script  
✓ Created credentials template  
✓ Wrote 3 guides (execution, CLI reference, operations)  
✓ Updated .gitignore  
✓ Made scripts executable  

### Output Files
| File | Purpose | Status |
|------|---------|--------|
| 📄 EXECUTION_SUMMARY.md | Quick start guide | ✓ Ready |
| 📄 DISCOVERY_REPORT.md | Detailed findings | ✓ Ready |
| 📄 README_fix.md | Operations manual | ✓ Ready |
| 📄 AZURE_CLI_COMMANDS_REFERENCE.md | CLI reference | ✓ Ready |
| 📄 credential.md | Secrets template | ✓ Ready (.gitignore) |
| 🔧 infra/scripts/fix-and-verify.sh | Discovery script | ✓ Executable |
| 🔧 infra/scripts/fix-actions.sh | Fix script | ✓ Executable |
| 📦 infra/cloud-init/app-cloud-init.yaml | App provisioning | ✓ Ready |
| 🔒 .gitignore | Secret exclusion | ✓ Updated |

---

## 🚀 Getting Started (3 Steps)

### Step 1: Understand Current State
```bash
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm
bash infra/scripts/fix-and-verify.sh
```
**Time:** ~30 seconds  
**Output:** PASS/FAIL report for each architectural requirement

### Step 2: Preview Fixes (No Changes)
```bash
bash infra/scripts/fix-actions.sh --dry-run
```
**Time:** ~10 seconds  
**Output:** Exact `az` commands that will execute

### Step 3: Apply Fixes
```bash
bash infra/scripts/fix-actions.sh --apply
```
**Time:** ~2 minutes  
**Output:** Fixes applied, then re-run discovery to verify

---

## 📊 Issues Found & Fixes

| # | Issue | Severity | Auto-Fix? |
|---|-------|----------|-----------|
| 1 | Orphaned NIC in app-subnet | High | Yes |
| 2 | Missing App VM 2 | High | No* |
| 3 | App VM 1 has public IP | High | Yes |
| 4 | DB VMs in LB backend pool | High | Yes |
| 5 | 2 DB VMs (need 1) | Medium | Yes |
| 6 | **DB NSG rule source wrong** | **Critical** | **Yes** |
| 7 | LB probe is TCP, not HTTP | Medium | Yes |

*App VM 2 requires manual Terraform or `az vm create` command (see README_fix.md)

---

## ✅ Verification Checklist

After running fixes, confirm:

- [ ] **Discovery shows all PASS:** `bash infra/scripts/fix-and-verify.sh`
- [ ] **Health endpoint responds:** `curl http://[LB_IP]/health` → HTTP 200
- [ ] **No DB public IP:** `az network public-ip list` shows only LB IP
- [ ] **DB NSG rule correct:** Source is `10.0.0.0/24` (not `10.0.1.0/24`)
- [ ] **App VMs in LB pool:** Backend pool shows 2 app VM NICs (not DB)
- [ ] **Single DB VM:** `az vm list -g vm-migration` shows exactly 3 VMs

---

## 🔒 Security Notes

### Credentials
- **File:** credential.md (⚠️ **NOT in git**)
- **Location:** `.gitignore` entry present
- **Contents:** Plaintext passwords (for manual setup only)
- **Production:** Use Azure Key Vault, Managed Identity

### Network Access
- **App VMs:** No public IPs (access via LB only)
- **DB VM:** Private IP only (app-subnet access only)
- **NSG Rules:** Least-privilege by design

### Secrets in Git
✓ `.gitignore` includes:
- `credential.md`
- `*.tfvars` (except example)
- SSH keys
- `.env` files

---

## 📝 Important Notes

### Why Scripts Are Safe
- Default mode: `--dry-run` (preview only, no changes)
- Destructive actions: Require `--apply` flag and user confirmation
- Idempotent: Safe to run multiple times
- Scoped: Only touch `vm-migration` resource group

### Prerequisites Met
✓ Azure CLI installed and authenticated  
✓ `vm-migration` resource group exists  
✓ All resources in place (manually created)  
✓ Scripts executable (`chmod +x`)  

### What Scripts Do NOT Do
✗ Modify resources outside `vm-migration` RG  
✗ Run without explicit `--apply` flag  
✗ Create App VM 2 (requires manual Terraform or `az vm create`)  
✗ Change application code or configuration  

---

## 🔧 Manual Execution Reference

If you prefer to run commands manually:

### Discover Current State
```bash
az group show -n vm-migration -o json
az vm list -g vm-migration --query "[].name" -o tsv
az network public-ip list -g vm-migration -o table
az network nsg rule list -g vm-migration --nsg-name network-security-group-db -o table
```

### Apply Fixes Manually
```bash
# Remove orphaned NIC
az network nic delete -g vm-migration -n vm-migartion-virtual-machine-for-app-1916_z3

# Remove public IPs
az network public-ip delete -g vm-migration -n vm-migartion-virtual-machine-for-app-1-ip
az network public-ip delete -g vm-migration -n vm-migartion-virtual-machine-for-app-2-ip

# Remove DB NICs from LB
az network nic ip-config address-pool remove -g vm-migration \
  -n vm-migartion-virtual-machine-for-db-1311_z2 --ip-config-name ipconfig1 \
  --lb-address-pool /subscriptions/*/resourceGroups/vm-migration/providers/*/loadBalancers/vm-migration-load-balancer/backendAddressPools/vm-migration-backend-pool

# Update DB NSG rule
az network nsg rule update -g vm-migration --nsg-name network-security-group-db \
  --name network-security-group-db-inbound-rules \
  --source-address-prefixes 10.0.0.0/24

# Update LB probe
az network lb probe update -g vm-migration --lb-name vm-migration-load-balancer \
  --name vm-migration-load-balancing-health-probe \
  --protocol Http --path /health

# Delete DB VM 2
az vm delete -g vm-migration -n vm-migartion-virtual-machine-for-db-2 --yes
```

### Verify Final State
```bash
bash infra/scripts/fix-and-verify.sh
```

---

## 📞 Troubleshooting

### Script Won't Run
```bash
# Make executable
chmod +x infra/scripts/fix-and-verify.sh
chmod +x infra/scripts/fix-actions.sh

# Check path
ls -la infra/scripts/fix-*.sh
```

### Azure CLI Errors
```bash
# Verify authentication
az account show

# Check resource group
az group exists -n vm-migration

# Set subscription if needed
az account set --subscription "e41ec793-5cda-4e62-a2ec-22ca1c330f5b"
```

### Fix Script Hangs
```bash
# Press Ctrl+C to cancel
# Rerun with --dry-run to check what's happening
bash infra/scripts/fix-actions.sh --dry-run
```

---

## 📚 Documentation Files

### EXECUTION_SUMMARY.md
- **When:** First time running fixes
- **Read:** 5-10 minutes
- **Contains:** Quick start, architecture summary, exact commands

### DISCOVERY_REPORT.md
- **When:** Need detailed findings
- **Read:** 10-15 minutes
- **Contains:** Current vs. desired comparison, issue descriptions

### README_fix.md
- **When:** Full operations guide needed
- **Read:** 20-30 minutes
- **Contains:** Troubleshooting, manual steps, verification checklist

### AZURE_CLI_COMMANDS_REFERENCE.md
- **When:** Need specific `az` command reference
- **Read:** As needed
- **Contains:** All discovery commands, filtering examples, aliases

---

## 🎓 Learning Path

1. **First 5 min:** Read [EXECUTION_SUMMARY.md](EXECUTION_SUMMARY.md)
2. **Next 30 sec:** Run `bash infra/scripts/fix-and-verify.sh`
3. **Next 30 sec:** Run `bash infra/scripts/fix-actions.sh --dry-run`
4. **Next 2 min:** Run `bash infra/scripts/fix-actions.sh --apply`
5. **Next 30 sec:** Run `bash infra/scripts/fix-and-verify.sh` again
6. **Optional:** Read [README_fix.md](README_fix.md) for deeper understanding

**Total time:** ~10 minutes

---

## 📞 Support Resources

| Issue | Resource |
|-------|----------|
| Want quick start? | [EXECUTION_SUMMARY.md](EXECUTION_SUMMARY.md) |
| Want detailed findings? | [DISCOVERY_REPORT.md](DISCOVERY_REPORT.md) |
| Want operations manual? | [README_fix.md](README_fix.md) |
| Want Azure CLI help? | [AZURE_CLI_COMMANDS_REFERENCE.md](AZURE_CLI_COMMANDS_REFERENCE.md) |
| Want to understand fixes? | `bash infra/scripts/fix-actions.sh --dry-run` |
| Want to verify state? | `bash infra/scripts/fix-and-verify.sh` |

---

## ✨ Next Phase

After fixes are applied and verified:

1. **Create App VM 2** (if not created by fix script)
   - See README_fix.md for manual steps
   - Or re-apply Terraform with full module

2. **Populate credential.md** with actual IPs
   ```bash
   az vm list -g vm-migration --show-details \
     --query "[].{name:name, ip:privateIps}" -o table
   ```

3. **Deploy application** to app VMs
   - Upload code via git clone (cloud-init does this)
   - Start services via systemd

4. **Initialize database** on db-1
   - Create schema and tables
   - Seed initial data

5. **Test end-to-end**
   - Curl LB health endpoint
   - Test app functionality
   - Test DB connectivity

---

## 📄 Files Included

```
/home/rafi/PH-EG-QuickClip/azure-backend-vm/
├── EXECUTION_SUMMARY.md                    (this summary)
├── DISCOVERY_REPORT.md                     (detailed findings)
├── README_fix.md                           (operations manual)
├── AZURE_CLI_COMMANDS_REFERENCE.md         (CLI commands)
├── credential.md                           (secrets template, in .gitignore)
├── .gitignore                              (updated)
├── infra/
│   ├── scripts/
│   │   ├── fix-and-verify.sh              (discovery & verification)
│   │   ├── fix-actions.sh                 (apply fixes)
│   │   └── (other existing scripts...)
│   ├── cloud-init/
│   │   ├── app-cloud-init.yaml            (app VM provisioning)
│   │   └── (other existing scripts...)
│   ├── terraform/
│   │   └── (existing Terraform files)
│   └── (other existing files)
└── (other project files...)
```

---

## 🎯 Summary

**Problem:** Manual Azure resources in `vm-migration` RG need alignment with desired architecture

**Solution:** Two idempotent scripts with dry-run mode

**Time to fix:** 5-10 minutes

**Risk level:** Very low (defaults to dry-run, destructive actions prompt for confirmation)

**Next step:** [Read EXECUTION_SUMMARY.md](EXECUTION_SUMMARY.md) and run `bash infra/scripts/fix-and-verify.sh`

---

**Generated:** 2026-02-08  
**Model:** GitHub Copilot (Claude Haiku 4.5)  
**Status:** ✓ Complete and Ready

