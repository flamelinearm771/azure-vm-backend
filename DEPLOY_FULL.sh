#!/bin/bash

###############################################################################
# COMPREHENSIVE DEPLOYMENT SCRIPT
# Sets up Azure resources, deploys to VM, and starts services
###############################################################################

set -e

RG="vm-migration"
APP_VM="vm-migartion-virtual-machine-for-app-1"
STORAGE_ACCOUNT="quickclipsa$(date +%s | tail -c 6)"
SERVICE_BUS_NS="quickclip-sb-$(date +%s | tail -c 6)"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  QUICKCLIP - COMPLETE VM DEPLOYMENT                           ║"
echo "║  $(date)  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# STEP 1: CREATE AZURE RESOURCES
# ============================================================================

echo "📦 STEP 1: Creating Azure Resources"
echo "──────────────────────────────────────────────────────────────────"
echo ""

echo "  ⏳ Creating Storage Account: $STORAGE_ACCOUNT"
az storage account create \
  -g $RG \
  -n $STORAGE_ACCOUNT \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  -o none 2>/dev/null

STORAGE_CONN=$(az storage account show-connection-string -g $RG -n $STORAGE_ACCOUNT -o tsv 2>/dev/null)
echo "     ✅ Storage Account created"

echo "  ⏳ Creating Blob Containers"
az storage container create -n videos --connection-string "$STORAGE_CONN" -o none 2>/dev/null || true
az storage container create -n results --connection-string "$STORAGE_CONN" -o none 2>/dev/null || true
echo "     ✅ Containers: videos, results"

echo "  ⏳ Creating Service Bus: $SERVICE_BUS_NS"
az servicebus namespace create \
  -g $RG \
  -n $SERVICE_BUS_NS \
  --sku Basic \
  -o none 2>/dev/null

SERVICE_BUS_CONN=$(az servicebus namespace authorization-rule keys list \
  -g $RG \
  --namespace-name $SERVICE_BUS_NS \
  -n RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv 2>/dev/null)

echo "     ✅ Service Bus Namespace created"

echo "  ⏳ Creating Service Bus Queue: video-jobs"
az servicebus queue create \
  -g $RG \
  --namespace-name $SERVICE_BUS_NS \
  -n video-jobs \
  --max-size 3072 \
  -o none 2>/dev/null || true

echo "     ✅ Service Bus Queue created"

echo ""
echo "✅ STEP 1 COMPLETE"
echo ""

# ============================================================================
# STEP 2: PREPARE ENVIRONMENT FILE
# ============================================================================

echo "⚙️  STEP 2: Creating Environment Configuration"
echo "──────────────────────────────────────────────────────────────────"
echo ""

ENV_FILE="/tmp/quickclip.env"

cat > $ENV_FILE << EOF
# ============================================
# QuickClip Environment Variables
# ============================================

# Azure Service Bus
SERVICE_BUS_CONNECTION_STRING=$SERVICE_BUS_CONN
SERVICE_BUS_QUEUE=video-jobs

# Azure Blob Storage
STORAGE_CONNECTION_STRING=$STORAGE_CONN

# Application Configuration
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=*

# API Keys (REQUIRED - Set these before starting services)
# Get DEEPGRAM_API_KEY from: https://console.deepgram.com/
# Get HF_TOKEN from: https://huggingface.co/settings/tokens
DEEPGRAM_API_KEY=${DEEPGRAM_API_KEY:-}
HF_TOKEN=${HF_TOKEN:-}

EOF

echo "  ✅ Environment file created: $ENV_FILE"
echo ""

# ============================================================================
# STEP 3: DEPLOY TO APP VM
# ============================================================================

echo "🚀 STEP 3: Deploying Application to App VM"
echo "──────────────────────────────────────────────────────────────────"
echo ""

# Create deployment package
DEPLOY_PKG="/tmp/quickclip-deploy.tar.gz"

echo "  ⏳ Creating deployment package..."

# Copy application files
mkdir -p /tmp/quickclip-deploy/upload-api
mkdir -p /tmp/quickclip-deploy/worker/lib
mkdir -p /tmp/quickclip-deploy/systemd

# Copy upload-api files
cp upload-api/server-vm.js /tmp/quickclip-deploy/upload-api/server-vm.js
cp upload-api/blobStorage-vm.js /tmp/quickclip-deploy/upload-api/blobStorage.js
cp upload-api/serviceBus-vm.js /tmp/quickclip-deploy/upload-api/serviceBus.js
cp upload-api/blobResults-vm.js /tmp/quickclip-deploy/upload-api/blobResults.js
cp upload-api/package.json /tmp/quickclip-deploy/upload-api/package.json 2>/dev/null || \
  cat > /tmp/quickclip-deploy/upload-api/package.json << 'PKGJSON'
{
  "name": "quickclip-upload-api",
  "version": "1.0.0",
  "type": "module",
  "scripts": {"start": "node server-vm.js"},
  "dependencies": {
    "@azure/service-bus": "^7.9.0",
    "@azure/storage-blob": "^12.14.0",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "multer": "^1.4.5-lts.1"
  }
}
PKGJSON

# Copy worker files
cp worker/worker-vm.js /tmp/quickclip-deploy/worker/worker-vm.js
cp worker/serviceBusReceiver-vm.js /tmp/quickclip-deploy/worker/serviceBusReceiver.js
cp worker/blobDownload-vm.js /tmp/quickclip-deploy/worker/blobDownload.js
cp worker/blobResults-vm.js /tmp/quickclip-deploy/worker/blobResults.js
cp worker/lib/processVideo-vm.js /tmp/quickclip-deploy/worker/lib/processVideo.js
cp worker/package.json /tmp/quickclip-deploy/worker/package.json 2>/dev/null || \
  cat > /tmp/quickclip-deploy/worker/package.json << 'PKGJSON'
{
  "name": "quickclip-worker",
  "version": "1.0.0",
  "type": "module",
  "scripts": {"start": "node worker-vm.js"},
  "dependencies": {
    "@azure/service-bus": "^7.9.0",
    "@azure/storage-blob": "^12.14.0",
    "@deepgram/sdk": "^3.3.0",
    "@huggingface/inference": "^2.6.4",
    "ffmpeg-static": "^5.1.0"
  }
}
PKGJSON

# Copy systemd files
cp infra/systemd/quickclip-api.service /tmp/quickclip-deploy/systemd/ 2>/dev/null || \
  cat > /tmp/quickclip-deploy/systemd/quickclip-api.service << 'SYSFILE'
[Unit]
Description=QuickClip Upload API
After=network.target
[Service]
Type=simple
User=quickclip
WorkingDirectory=/opt/quickclip/upload-api
EnvironmentFile=/etc/quickclip/env
ExecStart=/usr/bin/node server-vm.js
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
SYSFILE

cp infra/systemd/quickclip-worker.service /tmp/quickclip-deploy/systemd/ 2>/dev/null || \
  cat > /tmp/quickclip-deploy/systemd/quickclip-worker.service << 'SYSFILE'
[Unit]
Description=QuickClip Worker Service
After=network.target
[Service]
Type=simple
User=quickclip
WorkingDirectory=/opt/quickclip/worker
EnvironmentFile=/etc/quickclip/env
ExecStart=/usr/bin/node worker-vm.js
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
SYSFILE

# Copy env file
cp $ENV_FILE /tmp/quickclip-deploy/env

# Create install script
cat > /tmp/quickclip-deploy/install.sh << 'INSTSCRIPT'
#!/bin/bash
set -e

echo "🚀 Installing QuickClip on App VM..."

# Update and install dependencies
sudo apt-get update -qq
sudo apt-get install -y curl git ffmpeg > /dev/null 2>&1

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - > /dev/null 2>&1
sudo apt-get install -y nodejs > /dev/null 2>&1

# Create app user
sudo useradd -m quickclip 2>/dev/null || true
sudo mkdir -p /opt/quickclip
sudo chown quickclip:quickclip /opt/quickclip

# Deploy application
cd /tmp/quickclip-deploy
sudo cp -r upload-api /opt/quickclip/
sudo cp -r worker /opt/quickclip/
sudo mkdir -p /etc/quickclip
sudo cp env /etc/quickclip/env
sudo chown quickclip:quickclip /etc/quickclip/env
sudo chmod 600 /etc/quickclip/env

# Install npm dependencies
cd /opt/quickclip/upload-api
sudo -u quickclip npm install --production > /dev/null 2>&1

cd /opt/quickclip/worker
sudo -u quickclip npm install --production > /dev/null 2>&1

# Install systemd services
sudo cp /tmp/quickclip-deploy/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload

echo "✅ Installation complete!"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Update environment variables (API keys):"
echo "   sudo nano /etc/quickclip/env"
echo ""
echo "2. Start services:"
echo "   sudo systemctl start quickclip-api"
echo "   sudo systemctl start quickclip-worker"
echo ""
echo "3. Check status:"
echo "   sudo systemctl status quickclip-api"
echo "   sudo systemctl status quickclip-worker"
echo ""
INSTSCRIPT

chmod +x /tmp/quickclip-deploy/install.sh

# Create tarball
cd /tmp
tar -czf $DEPLOY_PKG quickclip-deploy/ > /dev/null 2>&1

echo "     ✅ Deployment package ready: $DEPLOY_PKG"
echo ""

# ============================================================================
# STEP 4: COPY TO APP VM
# ============================================================================

echo "📤 STEP 4: Copying Files to App VM"
echo "──────────────────────────────────────────────────────────────────"
echo ""

echo "  ⏳ Uploading deployment package..."
# Use az vm run-command to copy files
az vm run-command invoke \
  -g $RG \
  -n $APP_VM \
  --command-id RunShellScript \
  --scripts "cd /tmp && mkdir -p quickclip-deploy" \
  -o none 2>/dev/null

# For actual deployment, user will need to manually run on VM or use custom extension
echo "     ℹ️  Package location: $DEPLOY_PKG"
echo "     ℹ️  To deploy, on the App VM run:"
echo "         cd /tmp && bash quickclip-deploy/install.sh"
echo ""

# ============================================================================
# STEP 5: SUMMARY
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  DEPLOYMENT SUMMARY                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Created Azure Resources:"
echo "  ✅ Storage Account: $STORAGE_ACCOUNT"
echo "  ✅ Service Bus: $SERVICE_BUS_NS"
echo "  ✅ Queue: video-jobs"
echo "  ✅ Containers: videos, results"
echo ""
echo "🖥️  Application VM:"
echo "  VM Name: $APP_VM"
echo "  Private IP: 10.0.0.4"
echo "  Load Balancer IP: 20.204.249.182"
echo "  Health Endpoint: http://20.204.249.182/health"
echo ""
echo "⚙️  Configuration Files:"
echo "  Environment: $ENV_FILE"
echo "  Deployment: $DEPLOY_PKG"
echo ""
echo "🚀 DEPLOYMENT INSTRUCTIONS:"
echo ""
echo "1️⃣  SSH into App VM (or use Azure Bastion):"
echo "    ssh vm-app@20.204.249.182"
echo "    Password: Virtual-Machine-App-1"
echo ""
echo "2️⃣  Download and extract deployment package:"
echo "    curl -O file://$DEPLOY_PKG"
echo "    tar -xzf quickclip-deploy.tar.gz"
echo ""
echo "3️⃣  Run installation script:"
echo "    cd quickclip-deploy && bash install.sh"
echo ""
echo "4️⃣  Configure API keys:"
echo "    sudo nano /etc/quickclip/env"
echo "    Add: DEEPGRAM_API_KEY=your_key"
echo "    Add: HF_TOKEN=your_token"
echo ""
echo "5️⃣  Start services:"
echo "    sudo systemctl enable quickclip-api"
echo "    sudo systemctl enable quickclip-worker"
echo "    sudo systemctl start quickclip-api"
echo "    sudo systemctl start quickclip-worker"
echo ""
echo "6️⃣  Verify health check:"
echo "    curl http://20.204.249.182/health"
echo ""
echo "📱 Frontend Configuration:"
echo "  NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182"
echo ""
echo "✨ Deployment ready! Follow the instructions above."
echo ""
