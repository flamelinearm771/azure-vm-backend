# QuickClip VM Migration Guide - Task 1 & Task 2

This guide documents the migration from Azure Container Apps to a VM-based architecture with proper networking, security, and high availability.

## Overview

This migration implements:
- **Task 1: Secure Network & Private Database Deployment** - VNet with private subnets, NSGs, and database-only accessible from app subnet
- **Task 2: Scalability & High Availability** - Load Balancer, Availability Set, and failure simulation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Azure VNet (10.0.0.0/16)               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Application Subnet (10.0.1.0/24)          │ │
│  │  ┌──────────────────┐  ┌──────────────────┐            │ │
│  │  │   App VM 1       │  │   App VM 2       │            │ │
│  │  │  (Availability   │  │  (Availability   │            │ │
│  │  │     Set)         │  │     Set)         │            │ │
│  │  │ - upload-api     │  │ - upload-api     │            │ │
│  │  │ - worker         │  │ - worker         │            │ │
│  │  └──────────────────┘  └──────────────────┘            │ │
│  │          │                       │                      │ │
│  │          └───────────┬───────────┘                      │ │
│  │                      │                                  │ │
│  │              NSG Rules:                                 │ │
│  │              ✓ HTTP/HTTPS (80, 443)                     │ │
│  │              ✓ SSH (22) from admin_cidr                 │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            Database Subnet (10.0.2.0/24)               │ │
│  │  ┌──────────────────────────────────┐                  │ │
│  │  │      Database VM (PostgreSQL)     │                 │ │
│  │  │      Private IP Only (no public) │                 │ │
│  │  │      - Port 5432 (PostgreSQL)     │                 │ │
│  │  └──────────────────────────────────┘                  │ │
│  │   NSG Rules:                                            │ │
│  │   ✓ PostgreSQL (5432) from app subnet                   │ │
│  │   ✗ All public inbound DENIED                           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
          │
          │ Public endpoint
          ▼
┌─────────────────────────┐
│   Load Balancer         │
│   - Public IP           │
│   - Health Probe        │
│   - Backend Pool        │
│   - Rules (HTTP/HTTPS)  │
└─────────────────────────┘
```

## Prerequisites

Before running the deployment, ensure you have:

1. **Azure CLI** installed: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
2. **Terraform** installed: https://www.terraform.io/downloads
3. **SSH key pair** generated: `ssh-keygen -t rsa -b 4096`
4. **Azure subscription** with appropriate permissions
5. **Git** installed on your machine

## Quick Start

### Step 1: Prepare Configuration

```bash
# Clone/navigate to the repo
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm

# Copy Terraform variables template
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars

# Edit the configuration
nano infra/terraform/terraform.tfvars
```

**Important variables to configure:**

```hcl
subscription_id     = "your-subscription-id"  # Get from `az account show --query id`
rg_name             = "rg-quickclip-vm-migration"  # Change this to something unique
location            = "eastus"  # or your preferred region
admin_cidr          = "0.0.0.0/0"  # CHANGE THIS to your IP (e.g., "203.0.113.42/32")
db_admin_password   = "ChangeMe!2024@QuickClip"  # Change this
git_repo_url        = "https://github.com/your-org/PH-EG-QuickClip.git"
```

### Step 2: Authenticate with Azure

```bash
# Login to Azure
az login

# Set subscription (if you have multiple)
az account set --subscription <subscription-id>

# Verify subscription
az account show
```

### Step 3: Run the Deployment

```bash
# Make deploy script executable (if not already)
chmod +x deploy.sh

# Run the deployment
./deploy.sh
```

The deployment will:
1. Initialize Terraform
2. Validate configuration
3. Create Terraform plan
4. Apply infrastructure (5-10 minutes)
5. Retrieve outputs and create `credential.md`
6. Display deployment summary

### Step 4: Configure Environment Variables

After deployment, edit the credentials file:

```bash
# Edit credential.md and fill in the connection strings
nano credential.md
```

Then copy the environment to each App VM:

```bash
# SSH to App VM 1 and configure
ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_1_IP>

# Edit environment file
sudo nano /etc/myapp/.env

# Fill in:
# AZURE_STORAGE_CONNECTION_STRING=...
# SERVICE_BUS_CONNECTION_STRING=...
# DB_HOST=<DB_VM_IP>
# DB_PASSWORD=...

# Restart services
sudo systemctl restart upload-api worker

# Check status
systemctl status upload-api worker
journalctl -u upload-api -f
```

## Testing & Validation

### Task 1: Secure Network & Private Database

#### Test 1.1: Verify Database VM has No Public IP

```bash
# List all public IPs in resource group
az network public-ip list --resource-group rg-quickclip-vm-migration --output table

# Database VM should NOT have a public IP
# Only the Load Balancer and possibly app VMs should have public IPs
```

#### Test 1.2: Database Access from Public Internet FAILS

```bash
# From your workstation (with public IP), attempt to connect to database
# Get the DB VM IP from credential.md
DB_IP="10.0.2.x"  # Replace with actual IP

# This should FAIL (timeout or connection refused)
nc -vz $DB_IP 5432

# Or using telnet (if installed)
telnet $DB_IP 5432
```

**Expected result:** Connection refused or timeout (database is private)

#### Test 1.3: Database Access from App VM SUCCEEDS

```bash
# Get Load Balancer public IP
LB_IP=$(az network public-ip show --resource-group rg-quickclip-vm-migration --name pip-lb --query ipAddress -o tsv)

# Or from credential.md
LB_IP="<LB_PUBLIC_IP>"

# SSH to App VM via Load Balancer (if SSH is configured in LB rules)
# OR: ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_1_PRIVATE_IP> (from within VNet or bastion)

# Once on the App VM:
ssh -i ~/.ssh/id_rsa azureuser@10.0.1.x

# Now test database connectivity (should SUCCEED)
nc -vz 10.0.2.x 5432
# Or with psql
psql -h 10.0.2.x -U quickclip_user -d quickclip_db -c "SELECT version();"
```

**Expected result:** Connected successfully, database responds

#### Test 1.4: Verify NSG Rules

```bash
# Check Application Subnet NSG
az network nsg rule list \
  --resource-group rg-quickclip-vm-migration \
  --nsg-name nsg-app \
  --query "[?name=='Allow*'].{Name:name, Action:access, Protocol:protocol, DestPort:destinationPortRange, Source:sourceAddressPrefix}"

# Check Database Subnet NSG
az network nsg rule list \
  --resource-group rg-quickclip-vm-migration \
  --nsg-name nsg-db \
  --query "[].{Name:name, Action:access, Direction:direction, Priority:priority, Protocol:protocol, DestPort:destinationPortRange, Source:sourceAddressPrefix}"
```

**Expected NSG rules:**
- **nsg-app:** Allow HTTP (80), HTTPS (443), SSH (22)
- **nsg-db:** Allow PostgreSQL (5432) only from 10.0.1.0/24, Deny all other inbound

### Task 2: Scalability & High Availability

#### Test 2.1: Load Balancer Health Probe

```bash
# Get Load Balancer public IP
LB_IP=$(az network public-ip show --resource-group rg-quickclip-vm-migration --name pip-lb --query ipAddress -o tsv)

# Test health endpoint (should return HTTP 200)
curl -v http://$LB_IP/health

# Test application endpoint
curl -v http://$LB_IP/

# If you're running the backend, test actual endpoints
curl http://$LB_IP/jobs
curl -X POST http://$LB_IP/upload -F "video=@sample.mp4"
```

**Expected result:** HTTP 200 OK responses

#### Test 2.2: Simulate Failure - Stop One VM

```bash
# Get App VM names
APP_VM_1="vm-app-1"
APP_VM_2="vm-app-2"
RG="rg-quickclip-vm-migration"

# Verify both VMs are running
az vm get-instance-view --resource-group $RG --name $APP_VM_1 --query instanceView.statuses -o table
az vm get-instance-view --resource-group $RG --name $APP_VM_2 --query instanceView.statuses -o table

# Stop VM 1
echo "Stopping $APP_VM_1..."
az vm stop --resource-group $RG --name $APP_VM_1 --no-wait

# Wait for health probe to detect failure (15-30 seconds)
echo "Waiting 30 seconds for health probe..."
sleep 30

# Test Load Balancer - should still work (routed to VM 2)
LB_IP=$(az network public-ip show --resource-group $RG --name pip-lb --query ipAddress -o tsv)
echo "Testing Load Balancer while VM 1 is stopped..."
curl -v http://$LB_IP/health

# Check backend pool health
echo "Checking backend pool status..."
az network lb address-pool address list \
  --resource-group $RG \
  --lb-name lb-app \
  --pool-name app-backend-pool \
  --query "[].{Name:name, IpAddress:ipAddress}" \
  -o table

# Restart VM 1
echo "Restarting $APP_VM_1..."
az vm start --resource-group $RG --name $APP_VM_1 --no-wait

# Wait for VM and health probe to recover
echo "Waiting 60 seconds for VM to start..."
sleep 60

# Test again - now both VMs should be healthy
echo "Testing after restart..."
curl -v http://$LB_IP/health
```

**Expected results:**
1. Health check succeeds while VM 1 is stopped (VM 2 serving traffic)
2. Load Balancer backend pool shows VM 1 as "unhealthy" or "degraded"
3. After restart, both VMs are healthy and Load Balancer distributes traffic

#### Test 2.3: Verify Availability Set

```bash
# Check Availability Set configuration
RG="rg-quickclip-vm-migration"
az vm availability-set show \
  --resource-group $RG \
  --name avset-app \
  --query "{FaultDomains:platformFaultDomainCount, UpdateDomains:platformUpdateDomainCount, VMs:virtualMachines[].id}"

# VMs should be spread across different fault domains
```

### Test 2.4: Monitor Health Probe

```bash
# Watch health probe activity in real-time
az monitor metrics list-definitions \
  --resource /subscriptions/{subscription}/resourceGroups/{RG}/providers/Microsoft.Network/loadBalancers/lb-app \
  --query "[].name" -o table

# Get specific health probe metric
az monitor metrics list \
  --resource /subscriptions/{subscription}/resourceGroups/rg-quickclip-vm-migration/providers/Microsoft.Network/loadBalancers/lb-app \
  --metric HealthProbeStatus \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --interval PT1M
```

## Useful Commands

### View Resources

```bash
# List all resources in resource group
RG="rg-quickclip-vm-migration"
az resource list --resource-group $RG --output table

# List VMs
az vm list --resource-group $RG --output table

# List Network Interfaces
az network nic list --resource-group $RG --output table

# List Public IPs
az network public-ip list --resource-group $RG --output table

# View Load Balancer
az network lb show --resource-group $RG --name lb-app -o json | jq .

# View NSG Rules
az network nsg rule list --resource-group $RG --nsg-name nsg-app
az network nsg rule list --resource-group $RG --nsg-name nsg-db
```

### SSH Access

```bash
# SSH to App VM 1
APP_VM_IP="10.0.1.x"  # From credential.md
ssh -i ~/.ssh/id_rsa azureuser@$APP_VM_IP

# SSH to Database VM
DB_VM_IP="10.0.2.x"  # From credential.md
ssh -i ~/.ssh/id_rsa azureuser@$DB_VM_IP

# Using Azure CLI (if VM is in a specific state)
az vm run-command invoke \
  --resource-group rg-quickclip-vm-migration \
  --name vm-app-1 \
  --command-id RunShellScript \
  --scripts "systemctl status upload-api"
```

### Service Management

```bash
# SSH to App VM, then:

# Check service status
systemctl status upload-api
systemctl status worker

# View logs
journalctl -u upload-api -f
journalctl -u worker -f

# Restart services
sudo systemctl restart upload-api
sudo systemctl restart worker

# Reload environment
sudo systemctl daemon-reload

# View environment variables
cat /etc/myapp/.env
```

### Database Management

```bash
# SSH to Database VM, then:

# Check PostgreSQL status
systemctl status postgresql

# Connect to PostgreSQL
sudo -u postgres psql

# List databases
\l

# Connect to quickclip_db
\c quickclip_db

# List tables
\dt

# View listening ports
netstat -tlnp | grep postgres
# or
ss -tlnp | grep postgres
```

## Troubleshooting

### Services Not Starting

```bash
# Check cloud-init logs
ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_IP>
sudo tail -100 /var/log/cloud-init-output.log

# Check service logs
journalctl -u upload-api -n 50
journalctl -u worker -n 50

# Check if directories/files exist
ls -la /etc/myapp/
ls -la /opt/quickclip/

# Check npm installation
npm list -g pm2
node --version
```

### Database Connection Failing

```bash
# Check PostgreSQL service
ssh -i ~/.ssh/id_rsa azureuser@<DB_VM_IP>
systemctl status postgresql

# Check PostgreSQL is listening
netstat -tlnp | grep 5432

# Check PostgreSQL logs
sudo -u postgres psql -l

# Test connection from app VM
psql -h <DB_VM_IP> -U quickclip_user -d quickclip_db -c "SELECT 1"
```

### Load Balancer Not Routing Traffic

```bash
# Check health probe status
az network lb probe show \
  --resource-group rg-quickclip-vm-migration \
  --lb-name lb-app \
  --name app-health-probe

# Check if health endpoint exists on backend
ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_IP>
curl http://localhost:3000/health

# Check backend pool membership
az network lb address-pool address list \
  --resource-group rg-quickclip-vm-migration \
  --lb-name lb-app \
  --pool-name app-backend-pool

# Check Load Balancer rules
az network lb rule list --resource-group rg-quickclip-vm-migration --lb-name lb-app
```

### Connectivity Issues

```bash
# From app VM, test connectivity to database
ssh -i ~/.ssh/id_rsa azureuser@<APP_VM_IP>

# Check route to database
route -n | grep 10.0.2

# Test with nc
nc -vz <DB_VM_IP> 5432

# Check NSG is not blocking
# (review NSG rules with `az network nsg rule list`)

# Check firewall on database VM
sudo iptables -L -n
```

## Cleanup

When you're done testing, clean up the resources to avoid charges:

```bash
# Option 1: Using deploy script location
cd /home/rafi/PH-EG-QuickClip/azure-backend-vm
cd infra/terraform
terraform destroy --auto-approve

# Option 2: Using Azure CLI
RG="rg-quickclip-vm-migration"
az group delete --name $RG --yes --no-wait
```

**Warning:** This will delete all resources in the resource group, including VMs, VNet, Storage, etc.

## Production Considerations

### Security Best Practices

1. **Restrict admin_cidr:** Change from `0.0.0.0/0` to your specific IP range
2. **Use Azure Key Vault:** Store secrets instead of plain text in `credential.md`
3. **Enable Managed Identity:** Allow VMs to authenticate without storing keys
4. **Configure Azure Firewall:** Add WAF in front of Load Balancer
5. **Use SSL/TLS:** Configure HTTPS with proper certificates
6. **Enable Azure Policy:** Enforce governance and compliance

### High Availability Enhancements

1. **Use Availability Zones** instead of Availability Sets (set `use_zones = true`)
2. **Add Azure Application Gateway** for advanced routing
3. **Enable Application Insights** for monitoring
4. **Configure Auto-scaling** with VM Scale Sets
5. **Setup Disaster Recovery** with Azure Site Recovery

### Monitoring & Logging

1. Create **Log Analytics Workspace** for centralized logging
2. Configure **Azure Monitor Alerts** for health checks
3. Enable **Application Insights** for application-level monitoring
4. Setup **Azure Backup** for VM snapshots
5. Configure **Cost Alerts** to monitor spending

### Cost Optimization

- **Rightsize VMs** based on actual usage
- **Use Spot VMs** for non-critical workloads
- **Configure Auto-shutdown** for dev/test environments
- **Monitor bandwidth** for egress charges
- **Use Reserved Instances** for production workloads

## Additional Resources

- [Azure Virtual Network Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/)
- [Azure Load Balancer Documentation](https://docs.microsoft.com/en-us/azure/load-balancer/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/)
- [Cloud-init Documentation](https://cloud-init.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Support

For issues or questions:

1. Check the **Troubleshooting** section above
2. Review **Terraform logs**: `terraform show`
3. Check **Azure Activity Log** in Azure Portal
4. Review **cloud-init logs** on VMs: `/var/log/cloud-init-output.log`
5. Check **service logs**: `journalctl -u upload-api`

## Summary

You've successfully migrated your QuickClip application to:
- ✅ A private, secure network with separate subnets
- ✅ A database VM with private IP (not publicly accessible)
- ✅ Application VMs in an Availability Set for HA
- ✅ A public Load Balancer distributing traffic
- ✅ NSG rules enforcing security policies
- ✅ Health probes ensuring failover capability

The application now meets the requirements for **Task 1 (Secure Network)** and **Task 2 (Scalability & HA)**.
