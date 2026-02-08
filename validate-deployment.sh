#!/bin/bash
###############################################################################
# QuickClip VM Migration - Post-Deployment Validation Script
# Validates that the deployment meets Task 1 and Task 2 requirements
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
RG="${1:-rg-quickclip-vm-migration}"
LB_NAME="lb-app"
PIP_NAME="pip-lb"

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
warn() { echo -e "${YELLOW}⚠ WARN${NC} $1"; }

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

###############################################################################
# Task 1: Network Security Validation
###############################################################################
echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Task 1: Network Security Validation${NC}"
echo -e "${BLUE}======================================${NC}"

# Test 1.1: Check resource group exists
log "Checking resource group exists..."
if az group show -n "$RG" &>/dev/null; then
  pass "Resource group '$RG' exists"
  ((PASS_COUNT++))
else
  fail "Resource group '$RG' not found"
  ((FAIL_COUNT++))
fi

# Test 1.2: Check VNet exists
log "Checking VNet exists..."
if VNET=$(az network vnet list -g "$RG" --query "[0].name" -o tsv 2>/dev/null); then
  if [ -n "$VNET" ]; then
    pass "VNet '$VNET' found"
    ((PASS_COUNT++))
  else
    fail "No VNet found in resource group"
    ((FAIL_COUNT++))
  fi
else
  fail "Failed to list VNets"
  ((FAIL_COUNT++))
fi

# Test 1.3: Check subnets exist
log "Checking subnets exist..."
APP_SUBNET=$(az network vnet subnet list -g "$RG" --vnet-name "$VNET" --query "[?name=='app-subnet'].name" -o tsv 2>/dev/null)
DB_SUBNET=$(az network vnet subnet list -g "$RG" --vnet-name "$VNET" --query "[?name=='db-subnet'].name" -o tsv 2>/dev/null)

if [ -n "$APP_SUBNET" ]; then
  pass "Application subnet found: $APP_SUBNET"
  ((PASS_COUNT++))
else
  fail "Application subnet not found"
  ((FAIL_COUNT++))
fi

if [ -n "$DB_SUBNET" ]; then
  pass "Database subnet found: $DB_SUBNET"
  ((PASS_COUNT++))
else
  fail "Database subnet not found"
  ((FAIL_COUNT++))
fi

# Test 1.4: Check NSGs exist
log "Checking Network Security Groups..."
NSG_APP=$(az network nsg list -g "$RG" --query "[?name=='nsg-app'].name" -o tsv 2>/dev/null)
NSG_DB=$(az network nsg list -g "$RG" --query "[?name=='nsg-db'].name" -o tsv 2>/dev/null)

if [ -n "$NSG_APP" ]; then
  pass "Application NSG found: $NSG_APP"
  ((PASS_COUNT++))
else
  fail "Application NSG not found"
  ((FAIL_COUNT++))
fi

if [ -n "$NSG_DB" ]; then
  pass "Database NSG found: $NSG_DB"
  ((PASS_COUNT++))
else
  fail "Database NSG not found"
  ((FAIL_COUNT++))
fi

# Test 1.5: Validate NSG rules
log "Validating NSG rules..."
HTTP_RULE=$(az network nsg rule list -g "$RG" --nsg-name "$NSG_APP" --query "[?name=='AllowHTTP'].name" -o tsv 2>/dev/null)
HTTPS_RULE=$(az network nsg rule list -g "$RG" --nsg-name "$NSG_APP" --query "[?name=='AllowHTTPS'].name" -o tsv 2>/dev/null)
SSH_RULE=$(az network nsg rule list -g "$RG" --nsg-name "$NSG_APP" --query "[?name=='AllowSSH'].name" -o tsv 2>/dev/null)

if [ -n "$HTTP_RULE" ]; then
  pass "HTTP rule (80) found in app NSG"
  ((PASS_COUNT++))
else
  fail "HTTP rule (80) not found in app NSG"
  ((FAIL_COUNT++))
fi

if [ -n "$HTTPS_RULE" ]; then
  pass "HTTPS rule (443) found in app NSG"
  ((PASS_COUNT++))
else
  fail "HTTPS rule (443) not found in app NSG"
  ((FAIL_COUNT++))
fi

if [ -n "$SSH_RULE" ]; then
  pass "SSH rule (22) found in app NSG"
  ((PASS_COUNT++))
else
  fail "SSH rule (22) not found in app NSG"
  ((FAIL_COUNT++))
fi

# Test 1.6: Check database NSG rules
log "Validating database NSG rules..."
DB_RULE=$(az network nsg rule list -g "$RG" --nsg-name "$NSG_DB" --query "[?name=='AllowPostgreSQLFromApp'].name" -o tsv 2>/dev/null)

if [ -n "$DB_RULE" ]; then
  pass "PostgreSQL rule found in database NSG"
  ((PASS_COUNT++))
else
  fail "PostgreSQL rule not found in database NSG"
  ((FAIL_COUNT++))
fi

# Test 1.7: Check VMs exist
log "Checking VMs exist..."
APP_VM_1=$(az vm list -g "$RG" --query "[?name=='vm-app-1'].name" -o tsv 2>/dev/null)
APP_VM_2=$(az vm list -g "$RG" --query "[?name=='vm-app-2'].name" -o tsv 2>/dev/null)
DB_VM=$(az vm list -g "$RG" --query "[?name=='vm-db'].name" -o tsv 2>/dev/null)

if [ -n "$APP_VM_1" ] && [ -n "$APP_VM_2" ]; then
  pass "Application VMs found: $APP_VM_1, $APP_VM_2"
  ((PASS_COUNT++))
else
  fail "Application VMs not found (need vm-app-1 and vm-app-2)"
  ((FAIL_COUNT++))
fi

if [ -n "$DB_VM" ]; then
  pass "Database VM found: $DB_VM"
  ((PASS_COUNT++))
else
  fail "Database VM not found (need vm-db)"
  ((FAIL_COUNT++))
fi

# Test 1.8: Check database VM has no public IP
log "Checking database VM has no public IP..."
DB_PUBLIC_IPS=$(az vm list-ip-addresses -g "$RG" --name "$DB_VM" --query "[0].virtualMachines[0].publicIpAddresses[*].ipAddress" -o tsv 2>/dev/null || echo "")

if [ -z "$DB_PUBLIC_IPS" ]; then
  pass "Database VM has no public IP (secure)"
  ((PASS_COUNT++))
else
  fail "Database VM should not have public IP but found: $DB_PUBLIC_IPS"
  ((FAIL_COUNT++))
fi

###############################################################################
# Task 2: High Availability Validation
###############################################################################
echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Task 2: High Availability Validation${NC}"
echo -e "${BLUE}======================================${NC}"

# Test 2.1: Check Availability Set exists
log "Checking Availability Set..."
AVSET=$(az vm availability-set list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)

if [ -n "$AVSET" ]; then
  pass "Availability Set found: $AVSET"
  ((PASS_COUNT++))
  
  # Check VMs are in the availability set
  AVSET_VMS=$(az vm availability-set show -g "$RG" -n "$AVSET" --query "virtualMachines[].id" -o tsv 2>/dev/null | wc -l)
  if [ "$AVSET_VMS" -ge 2 ]; then
    pass "Availability Set has 2+ VMs"
    ((PASS_COUNT++))
  else
    warn "Availability Set should have 2+ VMs, found: $AVSET_VMS"
    ((WARN_COUNT++))
  fi
else
  fail "Availability Set not found"
  ((FAIL_COUNT++))
fi

# Test 2.2: Check Load Balancer exists
log "Checking Load Balancer..."
LB=$(az network lb list -g "$RG" --query "[?name=='$LB_NAME'].name" -o tsv 2>/dev/null)

if [ -n "$LB" ]; then
  pass "Load Balancer found: $LB"
  ((PASS_COUNT++))
else
  fail "Load Balancer '$LB_NAME' not found"
  ((FAIL_COUNT++))
fi

# Test 2.3: Check Load Balancer public IP
log "Checking Load Balancer public IP..."
LB_PIP=$(az network public-ip show -g "$RG" -n "$PIP_NAME" --query ipAddress -o tsv 2>/dev/null)

if [ -n "$LB_PIP" ] && [ "$LB_PIP" != "null" ]; then
  pass "Load Balancer public IP: $LB_PIP"
  ((PASS_COUNT++))
else
  fail "Load Balancer public IP not found or not allocated"
  ((FAIL_COUNT++))
fi

# Test 2.4: Check backend pool
log "Checking Load Balancer backend pool..."
BACKEND_POOL=$(az network lb address-pool list -g "$RG" --lb-name "$LB" --query "[0].name" -o tsv 2>/dev/null)

if [ -n "$BACKEND_POOL" ]; then
  pass "Backend pool found: $BACKEND_POOL"
  ((PASS_COUNT++))
  
  # Check backend pool members
  BACKEND_MEMBERS=$(az network lb address-pool address list -g "$RG" --lb-name "$LB" --pool-name "$BACKEND_POOL" --query "length([])" -o tsv 2>/dev/null)
  if [ "$BACKEND_MEMBERS" -ge 2 ]; then
    pass "Backend pool has 2+ members"
    ((PASS_COUNT++))
  else
    warn "Backend pool should have 2+ members, found: $BACKEND_MEMBERS"
    ((WARN_COUNT++))
  fi
else
  fail "Backend pool not found"
  ((FAIL_COUNT++))
fi

# Test 2.5: Check health probe
log "Checking health probe..."
HEALTH_PROBE=$(az network lb probe list -g "$RG" --lb-name "$LB" --query "[0].name" -o tsv 2>/dev/null)

if [ -n "$HEALTH_PROBE" ]; then
  pass "Health probe found: $HEALTH_PROBE"
  ((PASS_COUNT++))
  
  PROBE_PORT=$(az network lb probe show -g "$RG" --lb-name "$LB" -n "$HEALTH_PROBE" --query port -o tsv 2>/dev/null)
  pass "Health probe port: $PROBE_PORT"
  ((PASS_COUNT++))
else
  fail "Health probe not found"
  ((FAIL_COUNT++))
fi

# Test 2.6: Check load balancing rules
log "Checking load balancing rules..."
RULES=$(az network lb rule list -g "$RG" --lb-name "$LB" --query "length([])" -o tsv 2>/dev/null)

if [ "$RULES" -ge 1 ]; then
  pass "Load balancing rules found: $RULES rule(s)"
  ((PASS_COUNT++))
else
  fail "No load balancing rules found"
  ((FAIL_COUNT++))
fi

###############################################################################
# Connectivity Tests
###############################################################################
echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Connectivity Tests${NC}"
echo -e "${BLUE}======================================${NC}"

# Test 3.1: Test Load Balancer health endpoint
if [ -n "$LB_PIP" ] && [ "$LB_PIP" != "null" ]; then
  log "Testing Load Balancer health endpoint..."
  if timeout 5 curl -s http://"$LB_PIP"/health >/dev/null 2>&1; then
    pass "Load Balancer responds to health check"
    ((PASS_COUNT++))
  else
    warn "Load Balancer health check failed (VMs may still be initializing)"
    ((WARN_COUNT++))
  fi
fi

###############################################################################
# Summary
###############################################################################
echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}======================================${NC}"

TOTAL=$((PASS_COUNT + FAIL_COUNT))
SUCCESS_RATE=0
if [ $TOTAL -gt 0 ]; then
  SUCCESS_RATE=$((PASS_COUNT * 100 / TOTAL))
fi

echo -e "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "${YELLOW}Warnings: $WARN_COUNT${NC}"
echo ""
echo "Success Rate: $SUCCESS_RATE%"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ All critical tests passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Update credential.md with Service Bus and Storage connection strings"
  echo "2. SSH to App VMs and configure /etc/myapp/.env"
  echo "3. Test endpoints: curl http://$LB_PIP/health"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Some tests failed. Check output above.${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "1. Ensure all Terraform resources have been created: terraform apply"
  echo "2. Check cloud-init logs on VMs: /var/log/cloud-init-output.log"
  echo "3. Verify NSG rules are correctly applied"
  echo "4. Wait 5-10 minutes for cloud-init to complete on VMs"
  echo ""
  exit 1
fi
