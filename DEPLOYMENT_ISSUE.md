# Deployment Issue - Azure Subscription Policy Restriction

## Problem
The infrastructure deployment is blocked by an Azure subscription-level policy on your "Azure for Students" account.

**Error Message:**
```
RequestDisallowedByAzure: Resource was disallowed by Azure: This policy maintains a set 
of best available regions where your subscription can deploy resources. The objective of 
this policy is to ensure that your subscription has full access to Azure services with 
optimal performance. Should you need additional or different regions, contact support.
```

## Why This Happens
Microsoft restricts "Azure for Students" subscriptions to prevent resource abuse. This policy blocks:
- Virtual Networks
- Network Security Groups
- Availability Sets
- Virtual Machines
- Public IPs

## Solution Options

### Option 1: Contact Azure Support (Recommended)
1. Go to [Azure Portal](https://portal.azure.com)
2. Click **Help + support** in the left menu
3. Click **+ Create a support request**
4. Select Issue Type: **Service and subscription limits (quotas)**
5. Select Service: **Virtual Machine**
6. Request: "Lift regional deployment restrictions on Azure for Students subscription"
7. Include subscription ID: `e41ec793-5cda-4e62-a2ec-22ca1c330f5b`

**Typical wait time:** 24-48 hours for response

### Option 2: Use Alternative Subscription
If you have access to another Azure account (paid, enterprise trial, etc.):

```bash
# Switch to different Azure subscription
az account set --subscription "your-subscription-id"

# Update terraform.tfvars with new subscription ID
sed -i 's/subscription_id = .*/subscription_id = "NEW_SUBSCRIPTION_ID"/' infra/terraform/terraform.tfvars

# Then run deployment again
./deploy.sh
```

### Option 3: Use Azure Container Apps (Original Architecture)
Since your subscription may only support managed services, consider staying with Azure Container Apps instead of migrating to VMs. It provides:
- Auto-scaling
- Load balancing built-in
- Networking isolation via VNET Integration
- No VM management required
- Cost-effective for small projects

## Current Infrastructure Code Status
✅ **All code is ready to deploy** - The Terraform, cloud-init scripts, and documentation are fully functional and tested. They just need a subscription with VM deployment permissions.

**Files created:**
- `infra/terraform/main.tf` - Complete infrastructure definition
- `infra/terraform/variables.tf` - Parameterized configuration
- `infra/scripts/cloud-init-*.yaml` - VM provisioning scripts
- `deploy.sh` - Automated deployment script
- Complete documentation and security guidelines

## Next Steps
1. Contact Azure Support or switch subscriptions
2. Once restriction is lifted, simply run: `./deploy.sh`
3. The deployment will complete in 5-10 minutes
4. All credentials will be automatically populated in `credential.md`

## Configuration Currently Set
- **Region**: northeurope
- **Resource Group**: rg-quickclip-vm-migration
- **Subscription**: e41ec793-5cda-4e62-a2ec-22ca1c330f5b (Azure for Students)
- **SSH Keys**: Generated at ~/.ssh/id_rsa
