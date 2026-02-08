## Azure QuickClip VM Migration - Terraform Variables
## Do not run this against existing resource groups — change var.rg_name first.

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""  # Set via environment variable or .tfvars
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "rg_name" {
  description = "NEW resource group name (never touch existing RGs)"
  type        = string
  default     = "rg-quickclip-vm-migration"
}

variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
  default     = "vnet-quickclip"
}

variable "vnet_cidr" {
  description = "VNet CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_subnet_cidr" {
  description = "Application subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "db_subnet_cidr" {
  description = "Database subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "admin_cidr" {
  description = "Admin workstation CIDR for SSH access (restrict in production)"
  type        = string
  default     = "0.0.0.0/0"  # CHANGE THIS: set to your IP for security
}

variable "vm_size" {
  description = "VM size for application instances"
  type        = string
  default     = "Standard_B2s"
}

variable "db_vm_size" {
  description = "VM size for database instance"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_image_publisher" {
  description = "VM image publisher"
  type        = string
  default     = "Canonical"
}

variable "vm_image_offer" {
  description = "VM image offer"
  type        = string
  default     = "0001-com-ubuntu-server-focal"
}

variable "vm_image_sku" {
  description = "VM image SKU"
  type        = string
  default     = "20_04-lts-gen2"
}

variable "vm_image_version" {
  description = "VM image version"
  type        = string
  default     = "latest"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "db_admin_password" {
  description = "PostgreSQL admin password (CHANGE THIS)"
  type        = string
  sensitive   = true
  default     = "ChangeMe!2024@QuickClip"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "quickclip_db"
}

variable "git_repo_url" {
  description = "Git repository URL (backend code)"
  type        = string
  default     = "https://github.com/your-org/PH-EG-QuickClip.git"
}

variable "git_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

variable "use_zones" {
  description = "Use Availability Zones instead of Availability Set (if supported in region)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "QuickClip"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Purpose     = "VM-Migration-Task1-Task2"
  }
}
