#!/bin/bash
# WARNING: run only against resource group vm-migration.
#
# fix-and-verify.sh: Discovery and verification script for vm-migration resource group.
# This script runs discovery commands and validates the current state against the desired
# architecture. It reports mismatches and exits with non-zero status if fixes are needed.
#
# Usage:
#   bash infra/scripts/fix-and-verify.sh

set -e

RG_NAME="vm-migration"
LOG_FILE="${RG_NAME}-discovery-$(date +%s).log"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  VM Migration Discovery & Verification for: ${RG_NAME}          ║"
echo "║  $(date)                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

# Helper function to check resource
check_result() {
  local name=$1
  local result=$2
  if [ $result -eq 0 ]; then
    echo -e "${GREEN}✓${NC} $name"
    ((PASS_COUNT++))
  else
    echo -e "${RED}✗${NC} $name"
    ((FAIL_COUNT++))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Resource Group Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if az group show -n "$RG_NAME" -o json > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} Resource group '$RG_NAME' exists"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} Resource group '$RG_NAME' not found"
  ((FAIL_COUNT++))
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: VM Inventory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

VM_LIST=$(az vm list -g "$RG_NAME" --query "[].name" -o tsv 2>/dev/null || echo "")
VM_COUNT=$(echo "$VM_LIST" | grep -c "vm-migartion" || echo "0")

echo "VMs found: $VM_COUNT"
echo "$VM_LIST" | while read vm; do
  [ -z "$vm" ] && continue
  echo "  - $vm"
done

# Check for expected VMs
echo ""
echo "Checking expected VM names:"

APP_VM_1="vm-migartion-virtual-machine-for-app-1"
APP_VM_2="vm-migartion-virtual-machine-for-app-2"
DB_VM_1="vm-migartion-virtual-machine-for-db-1"
DB_VM_2="vm-migartion-virtual-machine-for-db-2"

az vm show -g "$RG_NAME" -n "$APP_VM_1" -o json > /dev/null 2>&1
check_result "App VM 1 exists: $APP_VM_1" $?

az vm show -g "$RG_NAME" -n "$APP_VM_2" -o json > /dev/null 2>&1
check_result "App VM 2 exists: $APP_VM_2" $?

az vm show -g "$RG_NAME" -n "$DB_VM_1" -o json > /dev/null 2>&1
check_result "DB VM 1 exists: $DB_VM_1" $?

az vm show -g "$RG_NAME" -n "$DB_VM_2" -o json > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo -e "${YELLOW}⚠${NC} Extra DB VM exists (should be 1): $DB_VM_2 — needs removal"
  ((FAIL_COUNT++))
else
  echo -e "${GREEN}✓${NC} No extra DB VM (correct: only 1 needed)"
  ((PASS_COUNT++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Public IP Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Checking public IPs:"
PIP_LIST=$(az network public-ip list -g "$RG_NAME" --query "[].{name:name, ipAddress:ipAddress}" -o json)

# Check if app VM 1 has public IP (should not)
APP_VM_1_PIP=$(echo "$PIP_LIST" | jq -r '.[] | select(.name | contains("app-1")) | .ipAddress' 2>/dev/null || echo "")
if [ -n "$APP_VM_1_PIP" ]; then
  echo -e "${RED}✗${NC} App VM 1 has public IP: $APP_VM_1_PIP (should use LB only)"
  ((FAIL_COUNT++))
else
  echo -e "${GREEN}✓${NC} App VM 1 has no public IP (correct)"
  ((PASS_COUNT++))
fi

# Check if LB has public IP
LB_PIP=$(echo "$PIP_LIST" | jq -r '.[] | select(.name == "vm-migration-public-ip") | .ipAddress' 2>/dev/null || echo "")
if [ -n "$LB_PIP" ]; then
  echo -e "${GREEN}✓${NC} Load Balancer has public IP: $LB_PIP (correct)"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} Load Balancer missing public IP"
  ((FAIL_COUNT++))
fi

# Check if DB VMs have public IP (should not)
DB_PIPS=$(echo "$PIP_LIST" | jq -r '.[] | select(.name | contains("db")) | .ipAddress' 2>/dev/null || echo "")
if [ -n "$DB_PIPS" ]; then
  echo -e "${RED}✗${NC} DB VMs have public IPs (should not): $DB_PIPS"
  ((FAIL_COUNT++))
else
  echo -e "${GREEN}✓${NC} DB VMs have no public IPs (correct)"
  ((PASS_COUNT++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Network Interface & Subnet Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NIC_LIST=$(az network nic list -g "$RG_NAME" --query "[].{name:name}" -o json)
NIC_COUNT=$(echo "$NIC_LIST" | jq 'length')
echo "Network Interfaces found: $NIC_COUNT"

# Check subnets
VNET_CHECK=$(az network vnet show -g "$RG_NAME" -n "vm-migration-virtual-network" -o json > /dev/null 2>&1 && echo "1" || echo "0")
if [ "$VNET_CHECK" -eq 1 ]; then
  echo -e "${GREEN}✓${NC} Virtual Network exists: vm-migration-virtual-network"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} Virtual Network not found"
  ((FAIL_COUNT++))
fi

APP_SUBNET_CHECK=$(az network vnet subnet show -g "$RG_NAME" --vnet-name "vm-migration-virtual-network" -n "app-subnet" -o json > /dev/null 2>&1 && echo "1" || echo "0")
if [ "$APP_SUBNET_CHECK" -eq 1 ]; then
  echo -e "${GREEN}✓${NC} App subnet exists: app-subnet (10.0.0.0/24)"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} App subnet not found"
  ((FAIL_COUNT++))
fi

DB_SUBNET_CHECK=$(az network vnet subnet show -g "$RG_NAME" --vnet-name "vm-migration-virtual-network" -n "db-subnet" -o json > /dev/null 2>&1 && echo "1" || echo "0")
if [ "$DB_SUBNET_CHECK" -eq 1 ]; then
  echo -e "${GREEN}✓${NC} DB subnet exists: db-subnet (10.0.1.0/24)"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} DB subnet not found"
  ((FAIL_COUNT++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Load Balancer Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LB_CHECK=$(az network lb show -g "$RG_NAME" -n "vm-migration-load-balancer" -o json > /dev/null 2>&1 && echo "1" || echo "0")
if [ "$LB_CHECK" -eq 1 ]; then
  echo -e "${GREEN}✓${NC} Load Balancer exists: vm-migration-load-balancer"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} Load Balancer not found"
  ((FAIL_COUNT++))
fi

# Check backend pool
BACKEND_POOL=$(az network lb address-pool list -g "$RG_NAME" --lb-name "vm-migration-load-balancer" -o json 2>/dev/null)
BACKEND_COUNT=$(echo "$BACKEND_POOL" | jq '.[0].backendIPConfigurations | length' 2>/dev/null || echo "0")
echo "Backend pool members: $BACKEND_COUNT (should be 2 for app VMs only)"

if [ "$BACKEND_COUNT" -eq 2 ]; then
  echo -e "${GREEN}✓${NC} Backend pool has 2 members"
  ((PASS_COUNT++))
elif [ "$BACKEND_COUNT" -gt 2 ]; then
  echo -e "${YELLOW}⚠${NC} Backend pool has $BACKEND_COUNT members (includes DB NICs — should be 2)"
  ((FAIL_COUNT++))
else
  echo -e "${RED}✗${NC} Backend pool has $BACKEND_COUNT members (need 2)"
  ((FAIL_COUNT++))
fi

# Check health probe
PROBE=$(az network lb probe list -g "$RG_NAME" --lb-name "vm-migration-load-balancer" -o json 2>/dev/null)
PROBE_PROTOCOL=$(echo "$PROBE" | jq -r '.[0].protocol' 2>/dev/null || echo "")
PROBE_PORT=$(echo "$PROBE" | jq -r '.[0].port' 2>/dev/null || echo "")
PROBE_PATH=$(echo "$PROBE" | jq -r '.[0].requestPath' 2>/dev/null || echo "")

echo "Health probe: protocol=$PROBE_PROTOCOL, port=$PROBE_PORT, path=$PROBE_PATH"

if [ "$PROBE_PROTOCOL" = "Http" ] && [ "$PROBE_PATH" = "/health" ]; then
  echo -e "${GREEN}✓${NC} Health probe configured correctly (HTTP /health)"
  ((PASS_COUNT++))
else
  echo -e "${YELLOW}⚠${NC} Health probe should be HTTP with /health path (current: $PROBE_PROTOCOL on port $PROBE_PORT)"
  ((FAIL_COUNT++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Network Security Groups"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check app NSG
APP_NSG=$(az network nsg show -g "$RG_NAME" -n "network-security-group-app" -o json 2>/dev/null)
if [ -n "$APP_NSG" ]; then
  echo -e "${GREEN}✓${NC} App NSG exists: network-security-group-app"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} App NSG not found"
  ((FAIL_COUNT++))
fi

# Check DB NSG
DB_NSG=$(az network nsg show -g "$RG_NAME" -n "network-security-group-db" -o json 2>/dev/null)
if [ -n "$DB_NSG" ]; then
  echo -e "${GREEN}✓${NC} DB NSG exists: network-security-group-db"
  ((PASS_COUNT++))
else
  echo -e "${RED}✗${NC} DB NSG not found"
  ((FAIL_COUNT++))
fi

# Check DB NSG rule source
echo ""
echo "Checking DB NSG inbound rules:"
DB_RULES=$(az network nsg rule list -g "$RG_NAME" --nsg-name "network-security-group-db" -o json 2>/dev/null)
DB_RULE_SOURCE=$(echo "$DB_RULES" | jq -r '.[] | select(.destinationPortRange == "5432") | .sourceAddressPrefix' 2>/dev/null || echo "")

if [ "$DB_RULE_SOURCE" = "10.0.0.0/24" ]; then
  echo -e "${GREEN}✓${NC} DB NSG rule allows from app subnet: 10.0.0.0/24 (correct)"
  ((PASS_COUNT++))
elif [ "$DB_RULE_SOURCE" = "10.0.1.0/24" ]; then
  echo -e "${RED}✗${NC} DB NSG rule allows from wrong subnet: 10.0.1.0/24 (should be 10.0.0.0/24)"
  ((FAIL_COUNT++))
else
  echo -e "${YELLOW}⚠${NC} DB NSG rule source is: $DB_RULE_SOURCE (expected 10.0.0.0/24)"
  ((FAIL_COUNT++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Passed: $PASS_COUNT${NC}"
echo -e "${RED}✗ Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed. Architecture is compliant.${NC}"
  echo ""
  echo "Status: PASS"
  exit 0
else
  echo -e "${RED}✗ $FAIL_COUNT issue(s) found. Run fix-actions.sh to remediate.${NC}"
  echo ""
  echo "To fix issues, run:"
  echo "  bash infra/scripts/fix-actions.sh --dry-run     # Preview changes"
  echo "  bash infra/scripts/fix-actions.sh --apply       # Apply fixes"
  echo ""
  echo "Status: FAIL"
  exit 1
fi
