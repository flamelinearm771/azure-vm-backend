#!/bin/bash
# WARNING: run only against resource group vm-migration.
#
# fix-actions.sh: Safe idempotent fix script for vm-migration resource group.
# This script proposes and applies fixes to align the current state with the desired architecture.
#
# Usage:
#   bash infra/scripts/fix-actions.sh --dry-run                    # Preview changes (default)
#   bash infra/scripts/fix-actions.sh --apply                      # Apply with interactive prompts
#   bash infra/scripts/fix-actions.sh --apply --force-delete-db-vm # Apply with auto-delete of extra DB VM

set -e

RG_NAME="vm-migration"
DRY_RUN=true
FORCE_DELETE=false
APPLY_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --apply)
      APPLY_MODE=true
      DRY_RUN=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      APPLY_MODE=false
      shift
      ;;
    --force-delete-db-vm)
      FORCE_DELETE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  VM Migration Fix Script for: ${RG_NAME}                       ║"
if [ "$DRY_RUN" = true ]; then
  echo "║  Mode: DRY-RUN (no changes)                                    ║"
else
  echo "║  Mode: APPLY (DESTRUCTIVE)                                    ║"
fi
echo "║  $(date)                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Helper to run az commands
run_command() {
  local desc=$1
  local cmd=$2
  echo ""
  echo -e "${BLUE}→${NC} $desc"
  echo "  Command: $cmd"
  
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY-RUN: not executing]"
  else
    if eval "$cmd"; then
      echo -e "  ${GREEN}✓ Success${NC}"
    else
      echo -e "  ${RED}✗ Failed${NC}"
      return 1
    fi
  fi
}

# Helper for confirmations
confirm() {
  if [ "$APPLY_MODE" = false ]; then
    return 0
  fi
  
  local prompt=$1
  local response
  
  echo ""
  echo -e "${YELLOW}⚠  $prompt${NC}"
  echo -n "  Type 'yes' to confirm: "
  read -r response
  
  if [ "$response" != "yes" ]; then
    echo "  Skipped."
    return 1
  fi
  return 0
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DISCOVERING RESOURCES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Discover NICs
echo "Discovering network interfaces..."
NIC_LIST=$(az network nic list -g "$RG_NAME" -o json)

APP_NIC_1=$(echo "$NIC_LIST" | jq -r '.[] | select(.name == "vm-migartion-virtual-machine-for-app-1172_z2") | .name' 2>/dev/null || echo "")
APP_NIC_2=$(echo "$NIC_LIST" | jq -r '.[] | select(.name == "vm-migartion-virtual-machine-for-app-1916_z3") | .name' 2>/dev/null || echo "")
DB_NIC_1=$(echo "$NIC_LIST" | jq -r '.[] | select(.name == "vm-migartion-virtual-machine-for-db-1311_z2") | .name' 2>/dev/null || echo "")
DB_NIC_2=$(echo "$NIC_LIST" | jq -r '.[] | select(.name == "vm-migartion-virtual-machine-for-db-1742_z3") | .name' 2>/dev/null || echo "")

echo "  App NIC 1: ${APP_NIC_1:-"not found"}"
echo "  App NIC 2 (orphaned): ${APP_NIC_2:-"not found"}"
echo "  DB NIC 1: ${DB_NIC_1:-"not found"}"
echo "  DB NIC 2: ${DB_NIC_2:-"not found"}"

# Discover public IPs
echo ""
echo "Discovering public IPs..."
PIP_LIST=$(az network public-ip list -g "$RG_NAME" -o json)

APP_1_PIP=$(echo "$PIP_LIST" | jq -r '.[] | select(.name == "vm-migartion-virtual-machine-for-app-1-ip") | .name' 2>/dev/null || echo "")
APP_2_PIP=$(echo "$PIP_LIST" | jq -r '.[] | select(.name == "vm-migartion-virtual-machine-for-app-2-ip") | .name' 2>/dev/null || echo "")
LB_PIP=$(echo "$PIP_LIST" | jq -r '.[] | select(.name == "vm-migration-public-ip") | .name' 2>/dev/null || echo "")

echo "  App VM 1 Public IP: ${APP_1_PIP:-"not found"}"
echo "  App VM 2 Public IP (orphaned): ${APP_2_PIP:-"not found"}"
echo "  LB Public IP: ${LB_PIP:-"not found"}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 1: Remove Orphaned NIC (app-1916_z3) and its Public IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$APP_NIC_2" ]; then
  if [ -n "$APP_2_PIP" ]; then
    run_command "Disassociate public IP from orphaned NIC" \
      "az network nic ip-config address-pool remove \
         --resource-group $RG_NAME \
         --nic-name $APP_NIC_2 \
         --ip-config-name ipconfig1 \
         --lb-address-pool /subscriptions/*/resourceGroups/$RG_NAME/providers/Microsoft.Network/loadBalancers/vm-migration-load-balancer/backendAddressPools/vm-migration-backend-pool \
         || true"
    
    run_command "Delete orphaned public IP resource" \
      "az network public-ip delete \
         --resource-group $RG_NAME \
         --name $APP_2_PIP"
  fi
  
  run_command "Delete orphaned NIC" \
    "az network nic delete \
       --resource-group $RG_NAME \
       --name $APP_NIC_2"
else
  echo "  No orphaned NIC found (good)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 2: Remove Public IP from App VM 1 NIC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$APP_1_PIP" ] && [ -n "$APP_NIC_1" ]; then
  run_command "Disassociate public IP from App VM 1" \
    "az network nic ip-config address-pool remove \
       --resource-group $RG_NAME \
       --nic-name $APP_NIC_1 \
       --ip-config-name ipconfig1 \
       --public-ip-address $APP_1_PIP \
       || true"
  
  run_command "Delete public IP from App VM 1" \
    "az network public-ip delete \
       --resource-group $RG_NAME \
       --name $APP_1_PIP"
else
  echo "  App VM 1 public IP not found (may already be removed)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 3: Remove DB NICs from LB Backend Pool"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$DB_NIC_1" ]; then
  run_command "Remove DB NIC 1 from LB backend pool" \
    "az network nic ip-config address-pool remove \
       --resource-group $RG_NAME \
       --nic-name $DB_NIC_1 \
       --ip-config-name ipconfig1 \
       --lb-address-pool /subscriptions/*/resourceGroups/$RG_NAME/providers/Microsoft.Network/loadBalancers/vm-migration-load-balancer/backendAddressPools/vm-migration-backend-pool \
       || true"
fi

if [ -n "$DB_NIC_2" ]; then
  run_command "Remove DB NIC 2 from LB backend pool" \
    "az network nic ip-config address-pool remove \
       --resource-group $RG_NAME \
       --nic-name $DB_NIC_2 \
       --ip-config-name ipconfig1 \
       --lb-address-pool /subscriptions/*/resourceGroups/$RG_NAME/providers/Microsoft.Network/loadBalancers/vm-migration-load-balancer/backendAddressPools/vm-migration-backend-pool \
       || true"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 4: Delete Extra DB VM (vm-migartion-virtual-machine-for-db-2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DB_VM_2="vm-migartion-virtual-machine-for-db-2"

if az vm show -g "$RG_NAME" -n "$DB_VM_2" -o json > /dev/null 2>&1; then
  if [ "$APPLY_MODE" = true ] && [ "$FORCE_DELETE" = false ]; then
    if ! confirm "Delete extra DB VM: $DB_VM_2?"; then
      echo "  Skipped deletion of $DB_VM_2"
    else
      run_command "Delete extra DB VM 2" \
        "az vm delete \
           --resource-group $RG_NAME \
           --name $DB_VM_2 \
           --yes"
    fi
  elif [ "$APPLY_MODE" = true ] && [ "$FORCE_DELETE" = true ]; then
    echo -e "${RED}⚠  FORCE DELETE ENABLED: Deleting $DB_VM_2 without confirmation${NC}"
    run_command "Delete extra DB VM 2 (forced)" \
      "az vm delete \
         --resource-group $RG_NAME \
         --name $DB_VM_2 \
         --yes"
  else
    echo "  [DRY-RUN] Would delete: $DB_VM_2"
  fi
else
  echo "  DB VM 2 not found (already deleted)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 5: Fix DB NSG Rule Source CIDR (10.0.1.0/24 → 10.0.0.0/24)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_command "Update DB NSG inbound rule source" \
  "az network nsg rule update \
     --resource-group $RG_NAME \
     --nsg-name network-security-group-db \
     --name network-security-group-db-inbound-rules \
     --source-address-prefixes 10.0.0.0/24 \
     --protocol Tcp \
     --destination-port-ranges 5432 \
     --access Allow \
     --priority 100"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 6: Update Load Balancer Health Probe to HTTP /health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_command "Update LB health probe protocol and path" \
  "az network lb probe update \
     --resource-group $RG_NAME \
     --lb-name vm-migration-load-balancer \
     --name vm-migration-load-balancing-health-probe \
     --protocol Http \
     --port 80 \
     --path /health"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION 7: Create Second App VM (if missing)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APP_VM_2="vm-migartion-virtual-machine-for-app-2"

if ! az vm show -g "$RG_NAME" -n "$APP_VM_2" -o json > /dev/null 2>&1; then
  echo -e "${YELLOW}⚠  App VM 2 not found. Would create from App VM 1 template.${NC}"
  echo "  This requires getting App VM 1 specs and cloud-init script."
  echo "  [DRY-RUN] Would create App VM 2 with:"
  echo "    - Same OS image as App VM 1"
  echo "    - NIC in app-subnet"
  echo "    - No public IP"
  echo "    - Attached to LB backend pool"
  echo "    - Cloud-init: git clone and systemd service start"
  echo ""
  echo "  Note: App VM 2 creation requires additional manual steps or"
  echo "  full Terraform re-apply. See README_fix.md for details."
else
  echo -e "${GREEN}✓${NC} App VM 2 already exists: $APP_VM_2"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$DRY_RUN" = true ]; then
  echo -e "${BLUE}[DRY-RUN MODE]${NC} Commands above would be executed in --apply mode."
  echo ""
  echo "To apply these changes, run:"
  echo "  bash infra/scripts/fix-actions.sh --apply"
  echo ""
  echo "Or to auto-delete extra DB VM without prompts:"
  echo "  bash infra/scripts/fix-actions.sh --apply --force-delete-db-vm"
  echo ""
  exit 0
else
  echo -e "${GREEN}✓${NC} Fix actions completed."
  echo ""
  echo "Next: Run verification to confirm all issues are resolved:"
  echo "  bash infra/scripts/fix-and-verify.sh"
  echo ""
  exit 0
fi
