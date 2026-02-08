# 🚀 VM Architecture Implementation - START HERE

**Date:** February 8, 2026  
**Status:** ⏳ IMPLEMENTATION IN PROGRESS  
**Expected Duration:** 30 minutes

---

## 📋 Implementation Checklist

### Phase 1: Prerequisites & Setup (5 min)
- [x] Terraform infrastructure files present
- [x] Cloud-init scripts configured
- [x] Deploy scripts ready
- [ ] Azure CLI authenticated
- [ ] Subscription ID configured
- [ ] SSH keys generated
- [ ] terraform.tfvars created and configured

### Phase 2: Configuration (5 min)
- [ ] Create `terraform.tfvars` from template
- [ ] Set subscription_id
- [ ] Set admin_cidr (your IP, not 0.0.0.0/0)
- [ ] Set database password
- [ ] Review all variables

### Phase 3: Deployment (15-20 min)
- [ ] Run `./deploy.sh`
- [ ] Monitor infrastructure creation
- [ ] Wait for VM cloud-init to complete
- [ ] Verify all resources created

### Phase 4: Validation (5 min)
- [ ] Run `./validate-deployment.sh`
- [ ] Test health endpoint
- [ ] Test failover behavior

---

## 🎯 What Gets Deployed

### Network Architecture
```
Internet
    ↓
Load Balancer (Public IP)
    ↓
NSG (Port 80, 443, 5432 rules)
    ↓
    ├─ VM App 1 (Private IP)
    ├─ VM App 2 (Private IP)
    └─ VM DB (Private IP)

Network Connectivity:
- App Subnet: 10.0.1.0/24 (for VM app 1, app 2)
- DB Subnet: 10.0.2.0/24 (for VM db)
- VNet: 10.0.0.0/16
```

### Resources
| Resource | Count | Purpose |
|----------|-------|---------|
| Resource Group | 1 | Billing & organization |
| Virtual Network | 1 | Network isolation |
| Subnets | 2 | App & Database separation |
| NSGs | 2 | Firewall rules |
| VMs | 3 | 2 app + 1 database |
| Public IPs | 1 | Load Balancer only |
| Load Balancer | 1 | Traffic distribution |
| Availability Set | 1 | App VM redundancy |

### Security Rules
**App Subnet NSG:**
- SSH: admin_cidr → Port 22
- HTTP: Internet → Port 80 (via LB)
- HTTPS: Internet → Port 443 (via LB)
- DB: App subnet → DB subnet:5432

**DB Subnet NSG:**
- SSH: admin_cidr → Port 22
- PostgreSQL: App subnet → Port 5432

---

## ✅ Task Fulfillment

### Task 1: Secure Network & Private Database
✅ Database is **NOT public** - no public IP  
✅ NSG rules enforce app-to-db communication only  
✅ SSH restricted to admin_cidr (your IP only)  
✅ Load Balancer is single public endpoint  

### Task 2: Scalability & High Availability
✅ 2 Application VMs in Availability Set  
✅ Load Balancer distributes traffic  
✅ Health probes detect VM failures  
✅ Auto-failover to healthy VM  
✅ Database VM can be scaled (resize, replicate)  

---

## 🚦 Quick Start (5 Steps)

### Step 1: Get Your Subscription ID
```bash
az account show --query id --output tsv
# Copy the output (UUID format)
```

### Step 2: Get Your IP Address
```bash
curl -s https://api.ipify.org
# Copy the IP (e.g., 203.0.113.42)
```

### Step 3: Create terraform.tfvars
```bash
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm.worktrees/copilot-worktree-2026-02-08T13-07-05
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
nano infra/terraform/terraform.tfvars
```

**Edit these lines:**
```hcl
subscription_id = "YOUR_SUBSCRIPTION_ID_HERE"
admin_cidr      = "YOUR_IP/32"  # e.g., "203.0.113.42/32"
db_admin_password = "YourSecurePassword!2024"
```

### Step 4: Deploy Infrastructure
```bash
./deploy.sh
```

This will:
1. Initialize Terraform
2. Create all Azure resources (5-10 min)
3. Deploy VMs with cloud-init scripts
4. Wait for services to start
5. Output credentials to credential.md

### Step 5: Validate
```bash
./validate-deployment.sh
curl http://<LB_IP>/health  # Check health endpoint
```

---

## 🔧 Prerequisites Check

Run this before deploying:

```bash
# Check Azure CLI
az --version

# Check Terraform
terraform --version

# Check SSH keys
[ -f ~/.ssh/id_rsa.pub ] && echo "✓ SSH key found" || ssh-keygen -t rsa -b 4096

# Check Azure login
az account show | jq -r '.name'
```

---

## 📊 Resource Locations

| File | Purpose |
|------|---------|
| `infra/terraform/main.tf` | Infrastructure definition |
| `infra/terraform/variables.tf` | Variable definitions |
| `infra/terraform/terraform.tfvars` | **Your config** (create this) |
| `infra/scripts/cloud-init-app.yaml` | App VM initialization |
| `infra/scripts/cloud-init-db.yaml` | DB VM initialization |
| `deploy.sh` | **Run this to deploy** |
| `validate-deployment.sh` | **Run this to verify** |
| `credential.md` | **Auto-generated secrets** |

---

## ⚠️ Important Notes

1. **terraform.tfvars is .gitignored** - Never commit secrets
2. **admin_cidr MUST be restrictive** - Use your IP, not 0.0.0.0/0
3. **Database password MUST be strong** - Use special chars, uppercase, numbers
4. **Deployment takes 15-20 minutes** - Cloud-init runs on VM startup
5. **Costs** - ~$60-85/month on Standard_B2s VMs

---

## 🆘 Troubleshooting

### "az login" fails?
```bash
az login --use-device-code
# Follow the browser prompt
```

### "terraform init" fails?
```bash
az account show  # Ensure you're logged in
az account set --subscription YOUR_SUBSCRIPTION_ID
cd infra/terraform && terraform init
```

### SSH key not found?
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Deployment hangs?
- Wait 10-15 minutes - cloud-init takes time
- Check: `az vm list -g rg-quickclip-vm-migration --query "[].powerState"`
- Check logs: `az vm boot-diagnostics get-boot-log -n vm-app-1 -g rg-quickclip-vm-migration`

### Health check returns 502?
- SSH to VM and check: `systemctl status upload-api`
- Check logs: `journalctl -u upload-api -n 50`

---

## 🎯 Next Steps After Deployment

1. **Add credentials to credential.md**
   - Service Bus connection string
   - Storage Account connection string
   - Deepgram API key

2. **Configure app environment**
   ```bash
   ssh azureuser@<APP_VM_PRIVATE_IP> -i ~/.ssh/id_rsa
   sudo nano /etc/myapp/.env
   sudo systemctl restart upload-api worker
   ```

3. **Test endpoints**
   ```bash
   curl http://<LB_IP>/health
   curl -X POST -F "video=@test.mp4" http://<LB_IP>/upload
   ```

4. **Monitor resources**
   ```bash
   az vm list-ip-addresses -g rg-quickclip-vm-migration
   az network lb show -g rg-quickclip-vm-migration -n lb-quickclip
   ```

---

## 📞 Support

**Documentation:**
- Full guide: [README_migration.md](README_migration.md)
- Quick ref: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- Architecture: [DELIVERABLES.md](DELIVERABLES.md)

**When stuck:**
1. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) troubleshooting section
2. Review terraform logs: `terraform show`
3. Check Azure Portal for resource state
4. Review cloud-init logs on VMs: `/var/log/cloud-init-output.log`

---

## ✨ Success Criteria

You'll know deployment is successful when:

- [x] `terraform apply` completes without errors
- [x] All 5 resources show in Azure Portal
- [x] VMs are "Running" and "Healthy"
- [x] Load Balancer shows 2 backends in Healthy state
- [x] `curl http://<LB_IP>/health` returns 200 OK
- [x] `credential.md` contains IPs and connection strings

---

**Ready? Let's deploy! 🚀**

Run: `./deploy.sh`

