## Azure QuickClip VM Migration - Terraform Main Configuration
## Do not run this against existing resource groups — change var.rg_name first.

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = false
  subscription_id            = var.subscription_id != "" ? var.subscription_id : null
}

# Create new resource group (never touch existing ones)
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Application Subnet (Private)
resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.app_subnet_cidr]
}

# Database Subnet (Private)
resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_cidr]
}

# ============================================================================
# Network Security Groups
# ============================================================================

# NSG for Application Subnet
resource "azurerm_network_security_group" "nsg_app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  # Allow HTTP from internet (to Load Balancer)
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS from internet (to Load Balancer)
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow SSH from admin CIDR only
  security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }

  # Allow outbound to anywhere (default behavior)
  security_rule {
    name                       = "AllowOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for Database Subnet
resource "azurerm_network_security_group" "nsg_db" {
  name                = "nsg-db"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  # Allow PostgreSQL (5432) only from application subnet
  security_rule {
    name                       = "AllowPostgreSQLFromApp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.app_subnet_cidr
    destination_address_prefix = "*"
  }

  # Allow SSH from admin CIDR (for DB maintenance)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }

  # Deny all other inbound (implicit, but explicit for clarity)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound to anywhere
  security_rule {
    name                       = "AllowOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
}

resource "azurerm_subnet_network_security_group_association" "db_subnet_nsg" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg_db.id
}

# ============================================================================
# Availability Set for High Availability (Task 2)
# ============================================================================

resource "azurerm_availability_set" "app_avset" {
  name                        = "avset-app"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
  managed                     = true
  tags                        = var.tags
}

# ============================================================================
# Application VMs (2 instances for HA)
# ============================================================================

# Network Interface for App VM 1
resource "azurerm_network_interface" "app_nic_1" {
  name                = "nic-app-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    # No public IP on VM (Load Balancer is the public endpoint)
  }
}

# Network Interface for App VM 2
resource "azurerm_network_interface" "app_nic_2" {
  name                = "nic-app-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# App VM 1
resource "azurerm_linux_virtual_machine" "app_vm_1" {
  name                = "vm-app-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size

  availability_set_id = azurerm_availability_set.app_avset.id

  disable_password_authentication = true

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  network_interface_ids = [
    azurerm_network_interface.app_nic_1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  custom_data = base64encode(file("${path.module}/../scripts/cloud-init-app.yaml"))

  tags = var.tags
}

# App VM 2
resource "azurerm_linux_virtual_machine" "app_vm_2" {
  name                = "vm-app-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size

  availability_set_id = azurerm_availability_set.app_avset.id

  disable_password_authentication = true

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  network_interface_ids = [
    azurerm_network_interface.app_nic_2.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  custom_data = base64encode(file("${path.module}/../scripts/cloud-init-app.yaml"))

  tags = var.tags
}

# ============================================================================
# Database VM (PostgreSQL)
# ============================================================================

resource "azurerm_network_interface" "db_nic" {
  name                = "nic-db"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
    # No public IP on database VM (private only)
  }
}

resource "azurerm_linux_virtual_machine" "db_vm" {
  name                = "vm-db"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.db_vm_size

  disable_password_authentication = true

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  network_interface_ids = [
    azurerm_network_interface.db_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  custom_data = base64encode(templatefile("${path.module}/../scripts/cloud-init-db.yaml", {
    db_password = var.db_admin_password
    db_name     = var.db_name
  }))

  tags = var.tags
}

# ============================================================================
# Load Balancer (Public) - Task 2 / Scalability
# ============================================================================

resource "azurerm_public_ip" "lb_public_ip" {
  name                = "pip-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "app_lb" {
  name                = "lb-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  tags = var.tags
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "app_backend_pool" {
  loadbalancer_id = azurerm_lb.app_lb.id
  name            = "app-backend-pool"
}

# Associate NICs with backend pool
resource "azurerm_network_interface_backend_address_pool_association" "app_nic_1_assoc" {
  network_interface_id    = azurerm_network_interface.app_nic_1.id
  ip_configuration_name   = "testConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "app_nic_2_assoc" {
  network_interface_id    = azurerm_network_interface.app_nic_2.id
  ip_configuration_name   = "testConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_backend_pool.id
}

# Health Probe (HTTP on port 80, or 3000 for Node.js app)
resource "azurerm_lb_probe" "app_health_probe" {
  loadbalancer_id     = azurerm_lb.app_lb.id
  name                = "app-health-probe"
  protocol            = "Http"
  port                = 3000  # Node.js backend port
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# Load Balancing Rule (HTTP)
resource "azurerm_lb_rule" "app_lb_rule_http" {
  loadbalancer_id            = azurerm_lb.app_lb.id
  name                       = "http-rule"
  protocol                   = "Tcp"
  frontend_port              = 80
  backend_port               = 3000  # Forward to Node.js on 3000
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids   = [azurerm_lb_backend_address_pool.app_backend_pool.id]
  probe_id                   = azurerm_lb_probe.app_health_probe.id
  enable_floating_ip         = false
}

# Load Balancing Rule (HTTPS - optional, for future use)
resource "azurerm_lb_rule" "app_lb_rule_https" {
  loadbalancer_id            = azurerm_lb.app_lb.id
  name                       = "https-rule"
  protocol                   = "Tcp"
  frontend_port              = 443
  backend_port               = 3001  # Or your HTTPS port if configured
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids   = [azurerm_lb_backend_address_pool.app_backend_pool.id]
  probe_id                   = azurerm_lb_probe.app_health_probe.id
  enable_floating_ip         = false
}
