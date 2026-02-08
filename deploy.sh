#!/bin/bash
###############################################################################
# Azure QuickClip VM Migration - Deployment Script
# Do not run this against existing resource groups — change var.rg_name first.
#
# This script:
# 1. Initializes Terraform
# 2. Applies Terraform configuration
# 3. Retrieves outputs and populates credential.md
# 4. Performs post-provisioning setup (copy app code, configure services)
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="./infra/terraform"
SCRIPTS_DIR="./infra/scripts"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in the right directory
if [ ! -d "$TERRAFORM_DIR" ]; then
  echo -e "${RED}Error: Terraform directory not found at $TERRAFORM_DIR${NC}"
  exit 1
fi

# Log function
log() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

###############################################################################
# Step 1: Check prerequisites
###############################################################################
log "Checking prerequisites..."

# Check Azure CLI
if ! command -v az &> /dev/null; then
  error "Azure CLI is not installed. Install it: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
  error "Terraform is not installed. Install it: https://www.terraform.io/downloads"
  exit 1
fi

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
  error "Not logged in to Azure. Run: az login"
  exit 1
fi

# Check SSH key exists
SSH_KEY_PATH="${HOME}/.ssh/id_rsa.pub"
if [ ! -f "$SSH_KEY_PATH" ]; then
  warning "SSH public key not found at $SSH_KEY_PATH"
  warning "Generate one with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
  exit 1
fi

# Check terraform.tfvars exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
  error "terraform.tfvars not found. Copy from terraform.tfvars.example and configure:"
  echo "  cp $TERRAFORM_DIR/terraform.tfvars.example $TERRAFORM_DIR/terraform.tfvars"
  echo "  # Edit and set your values"
  exit 1
fi

log "All prerequisites met."

###############################################################################
# Step 2: Initialize Terraform
###############################################################################
log "Initializing Terraform..."
cd "$TERRAFORM_DIR"
terraform init -upgrade

###############################################################################
# Step 3: Validate and plan
###############################################################################
log "Validating Terraform configuration..."
terraform validate

log "Creating Terraform plan..."
terraform plan -out=tfplan

###############################################################################
# Step 4: Apply Terraform
###############################################################################
log "Applying Terraform configuration (this may take 5-10 minutes)..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

###############################################################################
# Step 5: Get Terraform outputs
###############################################################################
log "Retrieving Terraform outputs..."

RG=$(terraform output -raw resource_group_name)
LB_PUBLIC_IP=$(terraform output -raw lb_public_ip)
APP_VM_1_IP=$(terraform output -raw app_vm_1_private_ip)
APP_VM_2_IP=$(terraform output -raw app_vm_2_private_ip)
DB_VM_IP=$(terraform output -raw db_vm_private_ip)
APP_VM_1_NAME=$(terraform output -raw app_vm_1_name)
APP_VM_2_NAME=$(terraform output -raw app_vm_2_name)
DB_VM_NAME=$(terraform output -raw db_vm_name)
ADMIN_USER=$(terraform output -raw admin_username)

log "Resource Group: $RG"
log "Load Balancer Public IP: $LB_PUBLIC_IP"
log "App VM 1 Private IP: $APP_VM_1_IP"
log "App VM 2 Private IP: $APP_VM_2_IP"
log "Database VM Private IP: $DB_VM_IP"

###############################################################################
# Step 6: Create/update credential.md
###############################################################################
log "Creating credential.md with deployment details..."

CRED_FILE="$REPO_ROOT/credential.md"
cat > "$CRED_FILE" << EOF
# QuickClip VM Migration - Credentials & Configuration

## DO NOT COMMIT THIS FILE TO GIT
Add to .gitignore: \`credential.md\`

**Security Note:** This file contains sensitive information. In production, use Azure Key Vault and Managed Identity instead.

---

## Deployment Output (from Terraform)

### Infrastructure Details
\`\`\`
AZURE_SUBSCRIPTION=$(az account show --query id -o tsv)
AZURE_RG=$RG
LB_PUBLIC_IP=$LB_PUBLIC_IP
LOCATION=$(terraform output -raw resource_group_name | grep -o '[a-z]*$')
\`\`\`

### Application VMs
\`\`\`
APP_VM_1_NAME=$APP_VM_1_NAME
APP_VM_1_PRIVATE_IP=$APP_VM_1_IP
APP_VM_2_NAME=$APP_VM_2_NAME
APP_VM_2_PRIVATE_IP=$APP_VM_2_IP
ADMIN_USERNAME=$ADMIN_USER
\`\`\`

### Database VM
\`\`\`
DB_VM_NAME=$DB_VM_NAME
DB_VM_PRIVATE_IP=$DB_VM_IP
DB_PORT=5432
\`\`\`

### Connection Strings (FILL THESE IN)
Replace placeholders with actual values from your existing deployment or Azure resources.

\`\`\`bash
# From Azure Storage Account
AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=..;AccountKey=..;EndpointSuffix=core.windows.net"

# From Azure Service Bus
SERVICE_BUS_CONNECTION_STRING="Endpoint=sb://..servicebus.windows.net/;SharedAccessKeyName=..;SharedAccessKey=..;EntityPath=.."

# PostgreSQL Database Connection
DB_USER=quickclip_user
DB_PASSWORD=<generated-during-provisioning>
DB_NAME=quickclip_db
DB_HOST=$DB_VM_IP
DB_CONNECTION_STRING="postgresql://quickclip_user:PASSWORD@$DB_VM_IP:5432/quickclip_db"
\`\`\`

### SSH Access

#### Public Key Location
\`\`\`
SSH_PRIVATE_KEY_PATH=~/.ssh/id_rsa
SSH_PUBLIC_KEY_PATH=~/.ssh/id_rsa.pub
\`\`\`

#### Connect to App VM (via Load Balancer public IP)
\`\`\`bash
# Direct via Load Balancer (Load Balancer forwards to one of the VMs)
# Note: This requires an SSH rule in the Load Balancer, which is not configured by default.
# Use bastion host or direct private IP instead.

# Option 1: SSH to App VM 1 directly (requires private IP and VNet access)
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_1_IP

# Option 2: SSH to App VM 2 directly
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_2_IP

# Option 3: Use Azure Bastion (if you set one up separately)
az network bastion ssh --name <bastion-name> --resource-group $RG --target-resource-id <vm-resource-id>
\`\`\`

#### Connect to Database VM
\`\`\`bash
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$DB_VM_IP
\`\`\`

#### Connect to PostgreSQL from App VM
\`\`\`bash
# SSH to App VM first
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_1_IP

# Then connect to PostgreSQL
psql -h $DB_VM_IP -U quickclip_user -d quickclip_db
\`\`\`

---

## Load Balancer Details

**Public IP:** $LB_PUBLIC_IP

### Health Check
- **Protocol:** HTTP
- **Port:** 3000 (Node.js backend)
- **Path:** /health
- **Interval:** 15 seconds
- **Unhealthy threshold:** 2 probes

### Routing Rules
- **HTTP (Port 80)** → Backend Port 3000
- **HTTPS (Port 443)** → Backend Port 3001 (if configured)

### Test Load Balancer
\`\`\`bash
curl http://$LB_PUBLIC_IP/health
curl http://$LB_PUBLIC_IP/jobs

# Or use your frontend to connect to http://$LB_PUBLIC_IP
\`\`\`

---

## Post-Provisioning Checklist

### 1. Verify Services Are Running
\`\`\`bash
# SSH to App VM 1
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_1_IP

# Check service status
systemctl status upload-api
systemctl status worker
journalctl -u upload-api -f
\`\`\`

### 2. Populate Environment Variables

On each App VM, edit \`/etc/myapp/.env\`:
\`\`\`bash
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_1_IP
sudo nano /etc/myapp/.env
\`\`\`

Fill in:
\`\`\`
AZURE_STORAGE_CONNECTION_STRING=<from-above>
SERVICE_BUS_CONNECTION_STRING=<from-above>
DB_HOST=$DB_VM_IP
DB_PASSWORD=<use-same-as-terraform>
\`\`\`

Restart services:
\`\`\`bash
sudo systemctl restart upload-api worker
\`\`\`

### 3. Configure Database (if not auto-created by cloud-init)
\`\`\`bash
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$DB_VM_IP
sudo -u postgres psql -d quickclip_db
# Then run SQL setup commands as needed
\`\`\`

---

## Testing & Validation Commands

### Task 1: Secure Network & Private Database

#### Test 1.1: Database is NOT publicly accessible
\`\`\`bash
# From your workstation (should FAIL - no public IP on DB VM)
nc -vz $DB_VM_IP 5432
# Expected: Connection refused or timeout (no public IP)
\`\`\`

#### Test 1.2: Database IS accessible from App VM
\`\`\`bash
# SSH to App VM
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_1_IP

# Test connectivity to DB
nc -vz $DB_VM_IP 5432
# Expected: Connected to $DB_VM_IP 5432

# Or test with psql
psql -h $DB_VM_IP -U quickclip_user -d quickclip_db -c "SELECT version();"
\`\`\`

#### Test 1.3: Verify NSG Rules
\`\`\`bash
# Check NSG rules
az network nsg rule list --resource-group $RG --nsg-name nsg-db --query "[].{Name:name, Access:access, Direction:direction, Priority:priority}"
\`\`\`

### Task 2: Scalability & High Availability

#### Test 2.1: Load Balancer Health Probe
\`\`\`bash
# Should return HTTP 200
curl -v http://$LB_PUBLIC_IP/health
\`\`\`

#### Test 2.2: Stop One VM and Verify Failover
\`\`\`bash
# Stop App VM 1
az vm stop --resource-group $RG --name $APP_VM_1_NAME --no-wait

# Wait 30 seconds for health probe to detect the failure
sleep 30

# Traffic should now route to App VM 2
curl http://$LB_PUBLIC_IP/health
curl http://$LB_PUBLIC_IP/  # or test your actual endpoints

# Start App VM 1 again
az vm start --resource-group $RG --name $APP_VM_1_NAME --no-wait
\`\`\`

#### Test 2.3: Check Load Balancer Backend Pool
\`\`\`bash
# List backend pool members
az network lb address-pool address list \\
  --resource-group $RG \\
  --lb-name lb-app \\
  --pool-name app-backend-pool
\`\`\`

---

## Useful Commands

### View Resource Group
\`\`\`bash
az group show -n $RG
\`\`\`

### View VMs
\`\`\`bash
az vm list --resource-group $RG --output table
\`\`\`

### View Network Interfaces
\`\`\`bash
az network nic list --resource-group $RG --output table
\`\`\`

### View NSG Rules
\`\`\`bash
az network nsg rule list --resource-group $RG --nsg-name nsg-app --output table
az network nsg rule list --resource-group $RG --nsg-name nsg-db --output table
\`\`\`

### View Load Balancer
\`\`\`bash
az network lb show --resource-group $RG --name lb-app
\`\`\`

### Get VM Details
\`\`\`bash
az vm show --resource-group $RG --name $APP_VM_1_NAME
az vm show --resource-group $RG --name $DB_VM_NAME
\`\`\`

### SSH to VM (via Azure CLI)
\`\`\`bash
az vm run-command invoke \\
  --resource-group $RG \\
  --name $APP_VM_1_NAME \\
  --command-id RunShellScript \\
  --scripts "echo 'Hello from App VM 1'"
\`\`\`

---

## Cost Monitoring

Check estimated costs (Standard_B2s VM ~\$30-40/month):
\`\`\`bash
az vm image pricing list --location eastus
\`\`\`

View actual costs in Azure Portal:
1. Go to Cost Management + Billing
2. Filter by resource group: $RG
3. Set time range and view daily/monthly breakdown

---

## Cleanup (When Done Testing)

**WARNING:** This will delete all resources in the resource group.

\`\`\`bash
cd $TERRAFORM_DIR
terraform destroy
\`\`\`

Or use Azure CLI:
\`\`\`bash
az group delete --name $RG --yes --no-wait
\`\`\`

---

## Troubleshooting

### Services Not Starting
\`\`\`bash
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$APP_VM_1_IP
journalctl -u upload-api -n 50
journalctl -u worker -n 50
\`\`\`

### Database Connection Failing
\`\`\`bash
# Check if PostgreSQL is running
ssh -i ~/.ssh/id_rsa $ADMIN_USER@$DB_VM_IP
systemctl status postgresql
netstat -tlnp | grep 5432
\`\`\`

### Load Balancer Not Routing Traffic
\`\`\`bash
# Check health probe status
az network lb probe show --resource-group $RG --lb-name lb-app --name app-health-probe

# Check backend pool status
az network lb address-pool address list --resource-group $RG --lb-name lb-app --pool-name app-backend-pool
\`\`\`

---

## Production Checklist

- [ ] Store secrets in Azure Key Vault (not credential.md)
- [ ] Use Managed Identity for VM authentication
- [ ] Configure Azure Firewall or WAF in front of Load Balancer
- [ ] Set up Azure Monitor and Log Analytics
- [ ] Enable Azure Backup for VMs
- [ ] Restrict admin_cidr to specific IP ranges
- [ ] Use https://letsencrypt.org certificates for HTTPS
- [ ] Implement CI/CD pipeline for deployments
- [ ] Set up centralized logging and monitoring
- [ ] Test disaster recovery procedures

EOF

log "Credential file created at $CRED_FILE"
log "IMPORTANT: Edit $CRED_FILE and fill in the connection strings from your Azure resources"

###############################################################################
# Step 7: Wait for VMs to be ready
###############################################################################
log "Waiting for cloud-init to complete on VMs (this takes 3-5 minutes)..."
sleep 60

# Try to connect to check if VMs are ready
max_attempts=10
attempt=0

while [ $attempt -lt $max_attempts ]; do
  if curl -s http://$LB_PUBLIC_IP/health &> /dev/null; then
    log "Load Balancer is responding!"
    break
  fi
  attempt=$((attempt + 1))
  log "Waiting for Load Balancer... (attempt $attempt/$max_attempts)"
  sleep 30
done

###############################################################################
# Step 8: Display summary
###############################################################################
cd "$REPO_ROOT"

log "=========================================="
log "✓ Deployment Complete!"
log "=========================================="
echo ""
echo "Resource Group: $RG"
echo "Load Balancer Public IP: $LB_PUBLIC_IP"
echo ""
echo "Application VMs:"
echo "  - $APP_VM_1_NAME ($APP_VM_1_IP)"
echo "  - $APP_VM_2_NAME ($APP_VM_2_IP)"
echo ""
echo "Database VM:"
echo "  - $DB_VM_NAME ($DB_VM_IP)"
echo ""
echo "Next steps:"
echo "  1. Edit credential.md with your Service Bus and Storage connection strings"
echo "  2. SSH to App VMs and verify /etc/myapp/.env is configured"
echo "  3. Run: curl http://$LB_PUBLIC_IP/health"
echo "  4. See credential.md for testing commands"
echo ""
echo "=========================================="
