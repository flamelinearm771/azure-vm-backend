#!/bin/bash
################################################################################
# QUICKCLIP APP VM DEPLOYMENT - COPY-PASTE COMMANDS
# Run these commands sequentially on the App VM
################################################################################

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  QuickClip App VM Deployment                                   ║"
echo "║  Follow these steps to complete the deployment                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# PART 1: SYSTEM SETUP (Run this first)
# ============================================================================

cat << 'EOF'

🔧 PART 1: System Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Update system packages:
   sudo apt-get update && sudo apt-get upgrade -y

2. Install Node.js 18:
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs

3. Install ffmpeg:
   sudo apt-get install -y ffmpeg

4. Verify installations:
   node --version
   npm --version
   ffmpeg -version

EOF

# ============================================================================
# PART 2: CREATE APP USER AND DIRECTORIES
# ============================================================================

cat << 'EOF'

👤 PART 2: Create App User & Directories
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Create quickclip user:
   sudo useradd -m quickclip || echo "User already exists"

2. Create app directory:
   sudo mkdir -p /opt/quickclip
   sudo chown quickclip:quickclip /opt/quickclip

3. Create config directory:
   sudo mkdir -p /etc/quickclip
   sudo chown root:root /etc/quickclip

EOF

# ============================================================================
# PART 3: DEPLOY APPLICATION CODE
# ============================================================================

cat << 'EOF'

📦 PART 3: Deploy Application Code
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Copy upload-api files:
   sudo mkdir -p /opt/quickclip/upload-api
   sudo cp upload-api/server-vm.js /opt/quickclip/upload-api/server-vm.js
   sudo cp upload-api/blobStorage-vm.js /opt/quickclip/upload-api/blobStorage.js
   sudo cp upload-api/serviceBus-vm.js /opt/quickclip/upload-api/serviceBus.js
   sudo cp upload-api/blobResults-vm.js /opt/quickclip/upload-api/blobResults.js
   sudo cp upload-api/package.json /opt/quickclip/upload-api/package.json

2. Copy worker files:
   sudo mkdir -p /opt/quickclip/worker/lib
   sudo cp worker/worker-vm.js /opt/quickclip/worker/worker-vm.js
   sudo cp worker/serviceBusReceiver-vm.js /opt/quickclip/worker/serviceBusReceiver.js
   sudo cp worker/blobDownload-vm.js /opt/quickclip/worker/blobDownload.js
   sudo cp worker/blobResults-vm.js /opt/quickclip/worker/blobResults.js
   sudo cp worker/lib/processVideo-vm.js /opt/quickclip/worker/lib/processVideo.js
   sudo cp worker/package.json /opt/quickclip/worker/package.json

3. Set correct permissions:
   sudo chown -R quickclip:quickclip /opt/quickclip

EOF

# ============================================================================
# PART 4: INSTALL DEPENDENCIES
# ============================================================================

cat << 'EOF'

📚 PART 4: Install npm Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Install Upload API dependencies:
   cd /opt/quickclip/upload-api
   sudo -u quickclip npm install --production

2. Install Worker dependencies:
   cd /opt/quickclip/worker
   sudo -u quickclip npm install --production

3. Verify installations:
   ls -la /opt/quickclip/upload-api/node_modules
   ls -la /opt/quickclip/worker/node_modules

EOF

# ============================================================================
# PART 5: CONFIGURE ENVIRONMENT
# ============================================================================

cat << 'EOF'

⚙️  PART 5: Configure Environment Variables
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Create environment file (auto-generated with Azure credentials):
   sudo tee /etc/quickclip/env > /dev/null << 'ENVFILE'
# Azure Service Bus
SERVICE_BUS_CONNECTION_STRING=<PASTE_YOUR_SERVICE_BUS_CONNECTION_STRING>
SERVICE_BUS_QUEUE=video-jobs

# Azure Blob Storage
STORAGE_CONNECTION_STRING=<PASTE_YOUR_STORAGE_CONNECTION_STRING>

# Application
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=*

# API Keys (GET FROM THE LINKS BELOW)
DEEPGRAM_API_KEY=<YOUR_DEEPGRAM_KEY>
HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN>
ENVFILE

2. Set file permissions (only quickclip user can read):
   sudo chmod 600 /etc/quickclip/env

3. Edit and add your API keys:
   sudo nano /etc/quickclip/env

   Get API keys from:
   - Deepgram: https://console.deepgram.com/
   - HuggingFace: https://huggingface.co/settings/tokens

EOF

# ============================================================================
# PART 6: INSTALL SYSTEMD SERVICES
# ============================================================================

cat << 'EOF'

🚀 PART 6: Install Systemd Services
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Copy Upload API service:
   sudo tee /etc/systemd/system/quickclip-api.service > /dev/null << 'SVCFILE'
[Unit]
Description=QuickClip Upload API Service
After=network.target

[Service]
Type=simple
User=quickclip
WorkingDirectory=/opt/quickclip/upload-api
EnvironmentFile=/etc/quickclip/env
ExecStart=/usr/bin/node server-vm.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCFILE

2. Copy Worker service:
   sudo tee /etc/systemd/system/quickclip-worker.service > /dev/null << 'SVCFILE'
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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCFILE

3. Reload systemd:
   sudo systemctl daemon-reload

4. Enable services to start on boot:
   sudo systemctl enable quickclip-api
   sudo systemctl enable quickclip-worker

EOF

# ============================================================================
# PART 7: START SERVICES
# ============================================================================

cat << 'EOF'

✨ PART 7: Start Services
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Start Upload API service:
   sudo systemctl start quickclip-api

2. Start Worker service:
   sudo systemctl start quickclip-worker

3. Check service status:
   sudo systemctl status quickclip-api
   sudo systemctl status quickclip-worker

4. View real-time logs:
   sudo journalctl -u quickclip-api -f      # Upload API logs
   sudo journalctl -u quickclip-worker -f   # Worker logs (new terminal)

EOF

# ============================================================================
# PART 8: VERIFY DEPLOYMENT
# ============================================================================

cat << 'EOF'

✅ PART 8: Verify Deployment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Check health endpoint:
   curl http://localhost:3000/health
   curl http://20.204.249.182/health

   Expected response:
   {"status":"healthy","timestamp":"2026-02-08T..."}

2. Create test video:
   ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 \
           -f lavfi -i sine=f=1000:d=2 test.mp4

3. Test upload:
   curl -F "video=@test.mp4" http://localhost:3000/upload

   Expected response:
   {"jobId":"uuid-here","status":"queued"}

4. Check job status:
   curl http://localhost:3000/jobs/uuid-here

   Responses:
   - Processing: {"status":"processing"}
   - Completed: {"status":"completed","result":{...}}

5. Monitor worker processing:
   sudo journalctl -u quickclip-worker -f

EOF

# ============================================================================
# PART 9: FRONTEND CONFIGURATION
# ============================================================================

cat << 'EOF'

📱 PART 9: Frontend Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Set backend URL in frontend .env:
   NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182

2. Or set at build time:
   NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182 npm run build

3. Expected frontend behavior:
   - User selects video file
   - Click "Upload & Start"
   - See stage progression: Uploaded → Queued → Processing → Completed
   - View transcription and summary when done

EOF

# ============================================================================
# TROUBLESHOOTING
# ============================================================================

cat << 'EOF'

🔧 Troubleshooting
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue: Services won't start
Solution:
  - Check environment file: cat /etc/quickclip/env
  - Check permissions: sudo ls -la /etc/quickclip/env
  - Should be: -rw------- (600)
  - Fix: sudo chmod 600 /etc/quickclip/env

Issue: API returns 500 error
Solution:
  - Check logs: sudo journalctl -u quickclip-api -n 100
  - Verify API keys are set: grep "API_KEY\|HF_TOKEN" /etc/quickclip/env
  - Verify Azure credentials: grep "SERVICE_BUS\|STORAGE" /etc/quickclip/env

Issue: Worker not processing jobs
Solution:
  - Check worker logs: sudo journalctl -u quickclip-worker -n 100
  - Verify Service Bus connection
  - Check queue: az servicebus queue list -g vm-migration --namespace-name quickclip-sb-*

Issue: Health check fails (Connection refused)
Solution:
  - API service not running: sudo systemctl start quickclip-api
  - Port conflict: sudo netstat -tlnp | grep 3000
  - Check NSG rules: az network nsg rule list -g vm-migration --nsg-name network-security-group-app

EOF

# ============================================================================
# FINAL CHECKLIST
# ============================================================================

cat << 'EOF'

📋 Final Deployment Checklist
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

□ Node.js 18 installed
□ ffmpeg installed
□ quickclip user created
□ /opt/quickclip directories created
□ Application files copied
□ npm dependencies installed
□ Environment file created with Azure credentials
□ API keys added (DEEPGRAM_API_KEY, HF_TOKEN)
□ Systemd services installed
□ Services enabled (auto-start)
□ Services started
□ Health endpoint responds
□ Test video uploaded successfully
□ Worker processing jobs
□ Frontend configured with backend URL
□ All tests passing ✅

EOF

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Deployment Guide Complete                                     ║"
echo "║  Follow the steps above to deploy QuickClip                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
