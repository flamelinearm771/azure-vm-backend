## Terraform Outputs - Infrastructure details for deployment

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Name of the created resource group"
}

output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "Virtual Network ID"
}

output "app_subnet_id" {
  value       = azurerm_subnet.app_subnet.id
  description = "Application subnet ID"
}

output "db_subnet_id" {
  value       = azurerm_subnet.db_subnet.id
  description = "Database subnet ID"
}

output "app_vm_1_id" {
  value       = azurerm_linux_virtual_machine.app_vm_1.id
  description = "App VM 1 resource ID"
}

output "app_vm_1_private_ip" {
  value       = azurerm_network_interface.app_nic_1.private_ip_address
  description = "App VM 1 private IP address"
}

output "app_vm_1_name" {
  value       = azurerm_linux_virtual_machine.app_vm_1.name
  description = "App VM 1 name"
}

output "app_vm_2_id" {
  value       = azurerm_linux_virtual_machine.app_vm_2.id
  description = "App VM 2 resource ID"
}

output "app_vm_2_private_ip" {
  value       = azurerm_network_interface.app_nic_2.private_ip_address
  description = "App VM 2 private IP address"
}

output "app_vm_2_name" {
  value       = azurerm_linux_virtual_machine.app_vm_2.name
  description = "App VM 2 name"
}

output "db_vm_id" {
  value       = azurerm_linux_virtual_machine.db_vm.id
  description = "Database VM resource ID"
}

output "db_vm_private_ip" {
  value       = azurerm_network_interface.db_nic.private_ip_address
  description = "Database VM private IP address"
}

output "db_vm_name" {
  value       = azurerm_linux_virtual_machine.db_vm.name
  description = "Database VM name"
}

output "lb_public_ip" {
  value       = azurerm_public_ip.lb_public_ip.ip_address
  description = "Load Balancer public IP address"
}

output "lb_id" {
  value       = azurerm_lb.app_lb.id
  description = "Load Balancer resource ID"
}

output "nsg_app_id" {
  value       = azurerm_network_security_group.nsg_app.id
  description = "Application subnet NSG ID"
}

output "nsg_db_id" {
  value       = azurerm_network_security_group.nsg_db.id
  description = "Database subnet NSG ID"
}

output "admin_username" {
  value       = var.admin_username
  description = "Admin username for SSH access"
}

output "ssh_connect_app_1" {
  value       = "ssh -i <your-key> ${var.admin_username}@<LB_PUBLIC_IP> (via Load Balancer or directly via private IP from bastion)"
  description = "SSH connection example for App VM 1"
}

output "ssh_connect_db" {
  value       = "ssh -i <your-key> ${var.admin_username}@${azurerm_network_interface.db_nic.private_ip_address}"
  description = "SSH connection example for Database VM (from within VNet or bastion)"
}
