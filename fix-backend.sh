#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Backend Diagnostic & Fix ===${NC}"

# SSH command
VM_USER="vm-app"
VM_IP="20.207.67.82"
SSH_CMD="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${VM_USER}@${VM_IP}"

echo -e "\n${YELLOW}1. Checking if backend is running...${NC}"
$SSH_CMD "ps aux | grep 'node.*server.js' | grep -v grep" && echo -e "${GREEN}✓ Backend is running${NC}" || echo -e "${RED}✗ Backend is NOT running${NC}"

echo -e "\n${YELLOW}2. Checking environment variables...${NC}"
$SSH_CMD "cat /home/vm-app/.env 2>/dev/null || echo 'No .env file found'"

echo -e "\n${YELLOW}3. Checking if upload-api directory exists...${NC}"
$SSH_CMD "ls -la /home/vm-app/upload-api/server.js 2>/dev/null && echo 'Found' || echo 'Not found'"

echo -e "\n${YELLOW}4. Testing connectivity to http://20.207.67.82:3000${NC}"
curl -s --connect-timeout 3 http://20.207.67.82:3000/ && echo -e "${GREEN}✓ Backend responds${NC}" || echo -e "${RED}✗ Backend not responding${NC}"

echo -e "\n${YELLOW}5. Checking backend logs...${NC}"
$SSH_CMD "tail -20 /tmp/upload-api.log 2>/dev/null || echo 'No logs found'"

echo -e "\n${YELLOW}6. Checking node installation...${NC}"
$SSH_CMD "which node && node --version"

echo -e "\n${YELLOW}7. Checking npm dependencies...${NC}"
$SSH_CMD "cd /home/vm-app/upload-api && npm list --depth=0 2>&1 | head -20"

echo -e "\n${YELLOW}=== End Diagnostic ===${NC}"
