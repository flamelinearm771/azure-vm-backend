#!/bin/bash
set -e

###############################################################################
# QUICKCLIP VM DEPLOYMENT SCRIPT
# Deploys upload-api and worker service to Azure VMs
# Prerequisites: App VM must be created and accessible
###############################################################################

RG="vm-migration"
APP_VM="vm-migartion-virtual-machine-for-app-1"
APP_VM_IP="10.0.0.4"
STORAGE_ACCOUNT="quickclipsa$(date +%s | tail -c 6)"
SERVICE_BUS_NS="quickclip-sb-$(date +%s | tail -c 6)"

echo "📦 QUICKCLIP VM DEPLOYMENT"
echo "================================"
echo ""

# STEP 1: Create Storage Account
echo "✓ STEP 1: Creating Storage Account ($STORAGE_ACCOUNT)..."
az storage account create \
  -g $RG \
  -n $STORAGE_ACCOUNT \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  -o none

STORAGE_CONN=$(az storage account show-connection-string -g $RG -n $STORAGE_ACCOUNT -o tsv)
echo "  → Storage Account created"
echo "  → Connection: ${STORAGE_CONN:0:80}..."
echo ""

# STEP 2: Create Blob Containers
echo "✓ STEP 2: Creating Blob Containers..."
az storage container create -n videos --connection-string "$STORAGE_CONN" -o none
az storage container create -n results --connection-string "$STORAGE_CONN" -o none
echo "  → Containers: videos, results"
echo ""

# STEP 3: Create Service Bus Namespace
echo "✓ STEP 3: Creating Service Bus Namespace ($SERVICE_BUS_NS)..."
az servicebus namespace create \
  -g $RG \
  -n $SERVICE_BUS_NS \
  --sku Basic \
  -o none

SERVICE_BUS_CONN=$(az servicebus namespace authorization-rule keys list \
  -g $RG \
  --namespace-name $SERVICE_BUS_NS \
  -n RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv)

echo "  → Service Bus Namespace created"
echo "  → Connection: ${SERVICE_BUS_CONN:0:80}..."
echo ""

# STEP 4: Create Service Bus Queue
echo "✓ STEP 4: Creating Service Bus Queue (video-jobs)..."
az servicebus queue create \
  -g $RG \
  --namespace-name $SERVICE_BUS_NS \
  -n video-jobs \
  --max-size 3072 \
  -o none
echo "  → Queue: video-jobs (max 3GB)"
echo ""

# STEP 5: Save Credentials
echo "✓ STEP 5: Saving Credentials..."
cat > /tmp/azure-creds.env << EOF
# Azure Service Bus
SERVICE_BUS_CONNECTION_STRING=$SERVICE_BUS_CONN
SERVICE_BUS_QUEUE=video-jobs

# Azure Blob Storage
STORAGE_CONNECTION_STRING=$STORAGE_CONN

# Application
PORT=3000
NODE_ENV=production

# API Keys (TO BE FILLED BY USER)
# DEEPGRAM_API_KEY=
# HF_TOKEN=
EOF

echo "  → Credentials saved to /tmp/azure-creds.env"
echo ""

# STEP 6: Summary
echo "✓ DEPLOYMENT SUMMARY"
echo "================================"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Service Bus: $SERVICE_BUS_NS"
echo "App VM: $APP_VM ($APP_VM_IP)"
echo ""
echo "⚠️  NEXT STEPS:"
echo "1. Add API keys to /tmp/azure-creds.env:"
echo "   - DEEPGRAM_API_KEY"
echo "   - HF_TOKEN"
echo "2. Run: bash infra/scripts/deploy-app-vm.sh"
echo ""
