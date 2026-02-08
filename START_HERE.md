# 🚀 START HERE - QuickClip VM Migration Deployment Guide

**Status:** ✅ COMPLETE & READY TO DEPLOY  
**Created:** February 7, 2024  
**Time to Deploy:** ~30 minutes total

---

## ⚡ Quick Start (5 Steps)

### Step 1: Prepare Configuration (5 min)
```bash
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
nano infra/terraform/terraform.tfvars  # Edit with your values
```

**Must change:**
- `subscription_id` (from `az account show`)
- `admin_cidr` (your IP, not 0.0.0.0/0)
- `db_admin_password` (PostgreSQL password)

### Step 2: Login to Azure (1 min)
```bash
az login
```

### Step 3: Deploy (10-15 min)
```bash
./deploy.sh
```

### Step 4: Validate (2 min)
```bash
./validate-deployment.sh
```

### Step 5: Test (5 min)
```bash
# Get IP from credential.md
curl http://<LB_PUBLIC_IP>/health
```

✅ **Done!** You now have a secure, highly-available infrastructure.

---

## 📚 Documentation Files

| File | Read This If... | Time |
|------|-----------------|------|
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | You want quick commands & troubleshooting | 5 min |
| [README_migration.md](README_migration.md) | You want the complete guide with testing | 20 min |
| [DELIVERABLES.md](DELIVERABLES.md) | You want to know exactly what was created | 15 min |

---

## 🎯 What Gets Deployed

### Architecture
```
Internet
    ↓
Load Balancer (Public IP)
    ↓
┌─ VM App 1 (Private Subnet)
└─ VM App 2 (Private Subnet)
    ↓
DB VM (Private Subnet, NOT Public)
    ↓
PostgreSQL
```

### Resources
- ✅ Virtual Network (10.0.0.0/16)
- ✅ 2 Private Subnets (App & Database)
- ✅ Network Security Groups (firewall rules)
- ✅ 2 Application VMs (Availability Set)
- ✅ 1 Database VM (private IP only)
- ✅ Load Balancer (public endpoint)
- ✅ Health Probes & Auto-failover

---

## ✅ Task 1 & Task 2 Met

**Task 1: Network Security**
- Database is private (not publicly accessible)
- NSG rules enforce: App ↔ DB only
- SSH restricted to admin_cidr

**Task 2: High Availability**  
- 2 VMs in Availability Set
- Load Balancer distributes traffic
- Health probes detect failures
- Auto-failover to healthy VM

---

## 🔑 Configuration Keys

From `terraform.tfvars`:

| Variable | Default | Must Change? |
|----------|---------|--------------|
| subscription_id | empty | YES |
| rg_name | rg-quickclip-vm-migration | Optional |
| location | eastus | Optional |
| admin_cidr | 0.0.0.0/0 | YES (your IP) |
| db_admin_password | ChangeMe!2024@QuickClip | YES |
| vm_size | Standard_B2s | Optional |

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| `az login` fails | Install Azure CLI |
| `terraform init` fails | Run `az login` first |
| SSH key missing | `ssh-keygen -t rsa -b 4096` |
| Deployment hangs | Wait 10 min (VMs initializing) |
| Health check fails | SSH to VM, check services |

Full guide: [README_migration.md#troubleshooting](README_migration.md#troubleshooting)

---

## 📋 Pre-Deployment Checklist

- [ ] Azure CLI installed & logged in (`az login`)
- [ ] Terraform installed (v1.0+)
- [ ] SSH keys generated (`ssh-keygen -t rsa -b 4096`)
- [ ] `terraform.tfvars` configured
- [ ] Subscription ID filled in
- [ ] admin_cidr set to YOUR IP
- [ ] Database password changed

---

## 🚀 Deploy Now

```bash
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm
./deploy.sh
```

**What it does:**
1. Checks prerequisites
2. Validates Terraform config
3. Creates all resources (5-10 min)
4. Retrieves outputs
5. Creates credential.md
6. Displays summary

---

## ✨ After Deployment

1. **Edit credential.md** - Add Service Bus/Storage connection strings
2. **SSH to App VMs** - Configure `/etc/myapp/.env`
3. **Restart services** - `sudo systemctl restart upload-api worker`
4. **Test endpoints** - `curl http://<LB_IP>/health`

Detailed steps: [README_migration.md#step-4-configure](README_migration.md#step-4-configure)

---

## 🧪 Quick Test

```bash
# Get LB IP from credential.md
LB_IP=<paste-here>

# Test health check
curl http://$LB_IP/health
# Should return HTTP 200 ✓

# Stop one VM
az vm stop -n vm-app-1 -g rg-quickclip-vm-migration --no-wait

# Wait 30 seconds
sleep 30

# Test again - should still work
curl http://$LB_IP/health
# Still HTTP 200 ✓ (failover worked!)
```

---

## 📁 Important Files

```
infra/terraform/
├── main.tf              ← All infrastructure
├── variables.tf         ← Input variables
├── terraform.tfvars     ← Your configuration (create from .example)
└── terraform.tfvars.example  ← Template

infra/scripts/
├── cloud-init-app.yaml  ← App VM setup
└── cloud-init-db.yaml   ← DB VM setup

Root:
├── deploy.sh            ← Run this to deploy
├── validate-deployment.sh ← Run this to verify
└── credential.md        ← Secrets (auto-generated)
```

---

## 🔒 Security Notes

⚠️ **Important:**

1. **credential.md** never goes to git (already in .gitignore)
2. **admin_cidr** change from 0.0.0.0/0 to your IP
3. **Passwords** change all defaults before production
4. **Production** use Azure Key Vault for secrets

---

## 💰 Cost

Monthly estimate:
- 2x Standard_B2s VMs: $30-40
- 1x DB VM: $15-20
- Load Balancer: $16-22
- **Total: ~$60-85**

---

## ❓ Quick Questions

**Q: How long does deployment take?**  
A: 5-10 minutes for infrastructure + cloud-init VMs take 2-3 more minutes.

**Q: Can I change VM size?**  
A: Yes, edit `terraform.tfvars` before running deploy.sh.

**Q: Can I use Availability Zones?**  
A: Yes, set `use_zones = true` in terraform.tfvars (must be supported region).

**Q: How do I update the application?**  
A: Use Ansible playbook or SSH and git pull.

**Q: How do I delete everything?**  
A: `cd infra/terraform && terraform destroy`.

More Q&A: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

---

## 📞 Need More Help?

- **Quick commands** → [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Full guide** → [README_migration.md](README_migration.md)
- **What was created** → [DELIVERABLES.md](DELIVERABLES.md)
- **Troubleshooting** → [README_migration.md#troubleshooting](README_migration.md#troubleshooting)

---

## 🎉 Ready?

1. Copy and customize `terraform.tfvars`
2. Run `./deploy.sh`
3. Run `./validate-deployment.sh`
4. Test with curl
5. Follow [README_migration.md#step-4-configure](README_migration.md#step-4-configure) for post-deployment setup

**Let's go! 🚀**
