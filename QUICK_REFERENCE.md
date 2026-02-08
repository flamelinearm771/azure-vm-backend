# QuickClip VM Migration - Quick Reference

## 🚀 Quick Start (5 minutes)

### 1. Prepare
```bash
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm
az login
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy
```bash
./deploy.sh
# Takes 5-10 minutes
```

### 3. Test
```bash
# Get your public IP from credential.md
LB_IP=<from-credential.md>
curl http://$LB_IP/health
```

---

## 📁 File Structure

```
.
├── infra/
│   ├── terraform/
│   │   ├── main.tf                 # Infrastructure definition
│   │   ├── variables.tf            # Input variables
│   │   ├── outputs.tf              # Outputs (IPs, names, etc.)
│   │   ├── backend.tf              # Remote state config (optional)
│   │   ├── terraform.tfvars.example # Configuration template
│   │   └── terraform.tfvars        # (your config - NOT in git)
│   └── scripts/
│       ├── cloud-init-app.yaml     # App VM setup script
│       └── cloud-init-db.yaml      # Database VM setup script
├── ansible/
│   ├── deploy-app.yml              # Redeployment playbook
│   └── inventory.ini               # Ansible inventory template
├── deploy.sh                        # Main deployment script
├── credential.md                    # Secrets template (NOT in git)
├── README_migration.md              # Full deployment guide
└── QUICK_REFERENCE.md              # This file
```

---

## 🔧 Useful Commands

### Terraform
```bash
cd infra/terraform
terraform plan              # Preview changes
terraform apply             # Apply infrastructure
terraform output            # Show outputs
terraform output -json      # JSON format
terraform destroy           # Delete all resources
terraform state list        # List resources
terraform state show <resource>  # Show resource details
```

### Azure CLI
```bash
# VMs
az vm list -g rg-quickclip-vm-migration --output table
az vm start -n vm-app-1 -g rg-quickclip-vm-migration
az vm stop -n vm-app-1 -g rg-quickclip-vm-migration

# Load Balancer
az network lb show -n lb-app -g rg-quickclip-vm-migration

# Public IPs
az network public-ip show -n pip-lb -g rg-quickclip-vm-migration --query ipAddress -o tsv

# Network Interfaces
az network nic list -g rg-quickclip-vm-migration --output table

# NSG Rules
az network nsg rule list -g rg-quickclip-vm-migration --nsg-name nsg-app
az network nsg rule list -g rg-quickclip-vm-migration --nsg-name nsg-db
```

### SSH
```bash
# To App VM
ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_IP>

# To Database VM
ssh -i ~/.ssh/id_rsa azureuser@<DB_VM_IP>

# Copy file to VM
scp -i ~/.ssh/id_rsa file.txt azureuser@<APP_VM_IP>:/tmp/
```

### Services (on App VM)
```bash
sudo systemctl status upload-api
sudo systemctl status worker
sudo systemctl restart upload-api
sudo journalctl -u upload-api -f
```

### Database (on DB VM)
```bash
sudo systemctl status postgresql
sudo -u postgres psql -l          # List databases
sudo -u postgres psql -d quickclip_db -c "SELECT 1"
```

---

## ✅ Testing Checklist

### Task 1: Network Security
- [ ] DB VM has NO public IP: `az network public-ip list -g rg-quickclip-vm-migration`
- [ ] Cannot connect from public IP: `nc -vz <DB_IP> 5432` (should fail)
- [ ] Can connect from App VM: SSH to App VM, then `nc -vz <DB_IP> 5432` (should succeed)
- [ ] NSG rules in place: `az network nsg rule list -g rg-quickclip-vm-migration --nsg-name nsg-db`

### Task 2: High Availability
- [ ] LB responds: `curl http://<LB_IP>/health` (HTTP 200)
- [ ] Both VMs in backend pool: `az network lb address-pool address list -g rg-quickclip-vm-migration --lb-name lb-app --pool-name app-backend-pool`
- [ ] Health probe active: `az network lb probe show -g rg-quickclip-vm-migration --lb-name lb-app --name app-health-probe`
- [ ] Failover works: Stop VM 1, LB still responds, check health status
- [ ] Services running: SSH to App VMs, check `systemctl status upload-api worker`

---

## 🐛 Troubleshooting

### Can't SSH to VM
```bash
# Check if security group allows SSH from your IP
az network nsg rule list -g rg-quickclip-vm-migration --nsg-name nsg-app | grep -i ssh

# Check if VM is running
az vm get-instance-view -n vm-app-1 -g rg-quickclip-vm-migration --query instanceView.statuses
```

### Services not running
```bash
# SSH to App VM
ssh -i ~/.ssh/id_rsa azureuser@<IP>

# Check cloud-init logs
sudo tail /var/log/cloud-init-output.log

# Check service logs
sudo journalctl -u upload-api -n 50
sudo systemctl status upload-api
```

### Database not accessible
```bash
# Check PostgreSQL is running
ssh -i ~/.ssh/id_rsa azureuser@<DB_IP>
sudo systemctl status postgresql

# Check it's listening
netstat -tlnp | grep 5432

# Try connecting
psql -h <DB_IP> -U postgres
```

### Load Balancer not responding
```bash
# Check health probe
az network lb probe show -g rg-quickclip-vm-migration --lb-name lb-app --name app-health-probe

# Check backend pool
az network lb address-pool address list -g rg-quickclip-vm-migration --lb-name lb-app --pool-name app-backend-pool

# Manually test endpoint on VM
ssh azureuser@<APP_VM_IP>
curl http://localhost:3000/health
```

---

## 🔒 Security Notes

1. **credential.md** - Never commit to git, contains secrets
2. **admin_cidr** - Change from `0.0.0.0/0` to your specific IP
3. **Database** - Not publicly accessible (by design), only reachable from app subnet
4. **SSH Keys** - Store safely, never share
5. **Production** - Use Azure Key Vault for secrets, not plain text files

---

## 💰 Cost Estimation

| Resource | Monthly Cost |
|----------|-------------|
| 2x Standard_B2s VMs | $30-40 |
| 1x Standard_B2s DB VM | $15-20 |
| Load Balancer | $16-22 |
| Data transfer | Varies |
| **Total** | **~$60-80** |

---

## 📋 Variables Summary

| Variable | Default | Purpose |
|----------|---------|---------|
| `rg_name` | `rg-quickclip-vm-migration` | Resource group name |
| `location` | `eastus` | Azure region |
| `admin_cidr` | `0.0.0.0/0` | SSH source IP (CHANGE!) |
| `vm_size` | `Standard_B2s` | VM instance type |
| `db_admin_password` | Set value | PostgreSQL password |
| `git_repo_url` | Your repo | Application repository |

---

## 🔄 Redeployment (Update App Code)

```bash
# Option 1: Using Ansible
cd ansible
ansible-playbook -i inventory.ini deploy-app.yml -u azureuser --private-key ~/.ssh/id_rsa

# Option 2: Manual
ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_IP>
cd /opt/quickclip
git pull origin main
cd upload-api && npm install
cd ../worker && npm install
sudo systemctl restart upload-api worker
```

---

## 📞 Support

1. Check [README_migration.md](README_migration.md) for detailed guide
2. Review [credential.md](credential.md) for environment setup
3. Check cloud-init logs: `sudo tail /var/log/cloud-init-output.log`
4. Check service logs: `sudo journalctl -u upload-api`
5. Check Azure Portal Activity Log for deployment errors

---

## 📖 Related Resources

- [Deployment Guide](README_migration.md)
- [Credentials & Config](credential.md)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Azure Documentation](https://docs.microsoft.com/en-us/azure/)

---

**Last Update:** 2024
**Terraform Version:** >= 1.0
**Azure CLI Version:** >= 2.40
