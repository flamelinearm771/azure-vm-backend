# Azure CLI Discovery Commands Reference

This document lists all exact `az` commands used during the discovery process.

---

## Resource Group

```bash
az group show -n vm-migration -o json
```

**Output:** Resource group metadata, location (centralindia), provisioning state

---

## Virtual Machines

### List All VMs
```bash
az vm list -g vm-migration --query "[].{name:name, powerState:powerState}" -o table
```

**Output:**
```
vm-migartion-virtual-machine-for-app-1
vm-migartion-virtual-machine-for-db-1
vm-migartion-virtual-machine-for-db-2
```

### VM Details (App VM 1)
```bash
az vm show -g vm-migration -n vm-migartion-virtual-machine-for-app-1 --show-details -o json
```

**Key fields:**
- `vmId`: Unique VM identifier
- `networkProfile.networkInterfaces[]`: Attached NICs
- `privateIps`: "10.0.0.4"
- `publicIps`: "20.207.67.82"

### VM Details (DB VM 1 & 2)
```bash
az vm show -g vm-migration -n vm-migartion-virtual-machine-for-db-1 --show-details -o json
az vm show -g vm-migration -n vm-migartion-virtual-machine-for-db-2 --show-details -o json
```

---

## Network Interfaces (NICs)

### List All NICs
```bash
az network nic list -g vm-migration -o json
```

**Returns:** All 4 NICs:
- `vm-migartion-virtual-machine-for-app-1172_z2` (app-1)
- `vm-migartion-virtual-machine-for-app-1916_z3` (orphaned, no VM)
- `vm-migartion-virtual-machine-for-db-1311_z2` (db-1)
- `vm-migartion-virtual-machine-for-db-1742_z3` (db-2)

### List with Table Format
```bash
az network nic list -g vm-migration -o table
```

---

## Public IP Addresses

### List All Public IPs
```bash
az network public-ip list -g vm-migration -o table
```

**Returns:**
- `vm-migartion-virtual-machine-for-app-1-ip`: 20.207.67.82
- `vm-migartion-virtual-machine-for-app-2-ip`: 20.207.67.85 (orphaned)
- `vm-migration-public-ip`: 20.204.249.182 (LB public IP)

### Get LB Public IP
```bash
az network public-ip list -g vm-migration \
  --query "[?name=='vm-migration-public-ip'].ipAddress" -o tsv
```

**Output:** `20.204.249.182`

---

## Virtual Network & Subnets

### Check VNet Exists
```bash
az network vnet show -g vm-migration -n vm-migration-virtual-network -o json
```

### Check App Subnet
```bash
az network vnet subnet show -g vm-migration \
  --vnet-name vm-migration-virtual-network \
  -n app-subnet -o json
```

**Expected:** CIDR 10.0.0.0/24

### Check DB Subnet
```bash
az network vnet subnet show -g vm-migration \
  --vnet-name vm-migration-virtual-network \
  -n db-subnet -o json
```

**Expected:** CIDR 10.0.1.0/24

---

## Load Balancer

### Show LB Details
```bash
az network lb show -g vm-migration -n vm-migration-load-balancer -o json
```

**Key fields:**
- `backendAddressPools`: Backend pool resources
- `probes`: Health probes
- `loadBalancingRules`: LB rules

### List Backend Pools
```bash
az network lb address-pool list -g vm-migration \
  --lb-name vm-migration-load-balancer -o json
```

**Returns:** Pool `vm-migration-backend-pool` with 4 backendIPConfigurations:
- 2 app VM NICs (correct)
- 2 DB VM NICs (incorrect, should be removed)

### List Health Probes
```bash
az network lb probe list -g vm-migration \
  --lb-name vm-migration-load-balancer -o json
```

**Current:**
- Name: `vm-migration-load-balancing-health-probe`
- Protocol: TCP (should be HTTP)
- Port: 80
- Path: null (should be /health)

---

## Network Security Groups (NSGs)

### Check App NSG Exists
```bash
az network nsg show -g vm-migration -n network-security-group-app -o json
```

### List App NSG Rules
```bash
az network nsg rule list -g vm-migration --nsg-name network-security-group-app -o json
```

**Current rules:**
- `network-security-group-app-inbound-rules`: TCP from Internet (all ports)
- `in-bound-security-rule-for-azure-load-balancer`: Allow from AzureLoadBalancer

### Check DB NSG Exists
```bash
az network nsg show -g vm-migration -n network-security-group-db -o json
```

### List DB NSG Rules
```bash
az network nsg rule list -g vm-migration --nsg-name network-security-group-db -o json
```

**Current rules:**
- `network-security-group-db-inbound-rules`: TCP port 5432 from 10.0.1.0/24 (WRONG)
- `in-bound-security-rule-for-azure-load-balancer`: Allow from AzureLoadBalancer

### Show Specific DB Rule
```bash
az network nsg rule show -g vm-migration --nsg-name network-security-group-db \
  --name network-security-group-db-inbound-rules -o json
```

**Fields:**
- `protocol`: TCP
- `destinationPortRange`: 5432
- `sourceAddressPrefix`: 10.0.1.0/24 (should be 10.0.0.0/24)

---

## Combined Discovery Command

Run all discovery in one command:

```bash
echo "=== RG ===" && \
az group show -n vm-migration --query "name" -o tsv && \
echo "=== VMs ===" && \
az vm list -g vm-migration --query "[].name" -o tsv && \
echo "=== PUB IPs ===" && \
az network public-ip list -g vm-migration --query "[].{name:name, ip:ipAddress}" -o tsv && \
echo "=== DB NSG RULE ===" && \
az network nsg rule show -g vm-migration --nsg-name network-security-group-db \
  --name network-security-group-db-inbound-rules --query "sourceAddressPrefix" -o tsv && \
echo "=== LB PROBE ===" && \
az network lb probe list -g vm-migration --lb-name vm-migration-load-balancer \
  --query "[0].{protocol:protocol, port:port, path:requestPath}" -o json
```

---

## Filtering Examples

### Get Only App VMs
```bash
az vm list -g vm-migration \
  --query "[?contains(name, 'app')].name" -o tsv
```

### Get Only DB VMs
```bash
az vm list -g vm-migration \
  --query "[?contains(name, 'db')].name" -o tsv
```

### Get VMs with Private IPs
```bash
az vm list -g vm-migration --show-details \
  --query "[].{name:name, privateIps:privateIps}" -o table
```

### Get VMs with Public IPs
```bash
az vm list -g vm-migration --show-details \
  --query "[].{name:name, publicIps:publicIps}" -o table
```

### Get NICs in App Subnet
```bash
az network nic list -g vm-migration \
  --query "[?contains(name, 'app')].name" -o tsv
```

---

## Count Resources

### Count VMs
```bash
az vm list -g vm-migration --query "length([].name)" -o tsv
```

### Count Public IPs
```bash
az network public-ip list -g vm-migration --query "length([].name)" -o tsv
```

### Count NICs
```bash
az network nic list -g vm-migration --query "length([].name)" -o tsv
```

### Count LB Backend Members
```bash
az network lb address-pool list -g vm-migration --lb-name vm-migration-load-balancer \
  --query "[0] | length(backendIPConfigurations)" -o tsv
```

---

## Comparison Queries

### Find Orphaned NICs (NIC exists but no VM)
```bash
# Get all NICs
az network nic list -g vm-migration --query "[].name" -o tsv > /tmp/nics.txt

# Get NICs with VMs
az vm list -g vm-migration --query "[].networkProfile.networkInterfaces[0].id" \
  --show-details -o tsv | sed 's|.*/||' > /tmp/nics_with_vms.txt

# Diff
comm -23 <(sort /tmp/nics.txt) <(sort /tmp/nics_with_vms.txt)
```

Result: `vm-migartion-virtual-machine-for-app-1916_z3` (orphaned)

---

## Fix Commands (For Reference)

### Remove NIC from LB Backend Pool
```bash
az network nic ip-config address-pool remove \
  --resource-group vm-migration \
  --nic-name [NIC_NAME] \
  --ip-config-name ipconfig1 \
  --lb-address-pool /subscriptions/*/resourceGroups/vm-migration/providers/Microsoft.Network/loadBalancers/vm-migration-load-balancer/backendAddressPools/vm-migration-backend-pool
```

### Update NSG Rule
```bash
az network nsg rule update \
  --resource-group vm-migration \
  --nsg-name network-security-group-db \
  --name network-security-group-db-inbound-rules \
  --source-address-prefixes 10.0.0.0/24 \
  --protocol Tcp \
  --destination-port-ranges 5432 \
  --access Allow \
  --priority 100
```

### Update LB Probe
```bash
az network lb probe update \
  --resource-group vm-migration \
  --lb-name vm-migration-load-balancer \
  --name vm-migration-load-balancing-health-probe \
  --protocol Http \
  --port 80 \
  --path /health
```

### Delete Public IP
```bash
az network public-ip delete \
  --resource-group vm-migration \
  --name [PIP_NAME]
```

### Delete NIC
```bash
az network nic delete \
  --resource-group vm-migration \
  --name [NIC_NAME]
```

### Delete VM
```bash
az vm delete \
  --resource-group vm-migration \
  --name [VM_NAME] \
  --yes
```

---

## Output Parsing Tips

### Get JSON and Filter with jq
```bash
az vm list -g vm-migration -o json | \
  jq '.[] | {name: .name, id: .vmId}'
```

### Convert Query Results to CSV
```bash
az vm list -g vm-migration \
  --query "[].{Name:name, PID:vmId, Type:osProfile.osType}" \
  -o csv > /tmp/vms.csv
```

### Count and Group
```bash
az vm list -g vm-migration --query "[].name" -o tsv | \
  grep -o 'app\|db' | sort | uniq -c
```

Output:
```
  1 app
  2 db
```

---

## Useful Aliases

Add to `~/.bashrc` for convenience:

```bash
# Show VM status in vm-migration RG
alias vmstatus='az vm list -g vm-migration --query "[].{name:name, powerState:powerState}" -o table'

# Show LB health
alias lbhealth='az network lb probe list -g vm-migration --lb-name vm-migration-load-balancer -o json | jq ".[] | {name, protocol, port, path:requestPath}"'

# Show DB NSG rule
alias nsgdb='az network nsg rule show -g vm-migration --nsg-name network-security-group-db --name network-security-group-db-inbound-rules -o json | jq "{src:.sourceAddressPrefix, port:.destinationPortRange, access:.access}"'

# Show VM details
alias vmdetails='az vm list -g vm-migration --show-details --query "[].{name:name, private:privateIps, public:publicIps}" -o table'
```

---

## Error Handling

### If Command Fails
```bash
# Check subscription
az account show --query "{id:id, name:name}" -o json

# Check RG exists
az group exists -n vm-migration

# Check auth
az account list --output table
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Resource not found | RG/resource doesn't exist | Check RG name: `vm-migration` |
| Unauthorized | Not logged in or wrong subscription | `az login` and `az account set` |
| Invalid syntax | Bad JQ or query | Use `--debug` flag |
| Timeout | Large query result set | Add `--query` filter |

---

**Generated:** 2026-02-08  
**Resource Group:** vm-migration

