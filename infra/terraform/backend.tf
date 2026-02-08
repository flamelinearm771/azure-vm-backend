## Terraform Backend Configuration
## Uncomment and configure for remote state storage (recommended for production)
## For local development, .terraform/ directory is sufficient

# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-terraform-state"
#     storage_account_name = "tfstate123456"
#     container_name       = "quickclip-tfstate"
#     key                  = "quickclip-vm.tfstate"
#
#     # Optional: use subscription ID for multi-subscription setups
#     # subscription_id     = "xxxx-xxxx-xxxx-xxxx"
#   }
# }

## To use Azure remote state:
## 1. Create a storage account for Terraform state
##    az storage account create -n tfstate123456 -g rg-terraform-state -l eastus --sku Standard_LRS
## 2. Create a container
##    az storage container create -n quickclip-tfstate --account-name tfstate123456
## 3. Uncomment the backend block above
## 4. Run: terraform init
##
## For local development, Terraform will use:
## - .terraform/terraform.tfstate (local state file)
## - DO NOT commit .terraform to git
