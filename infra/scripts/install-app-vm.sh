#!/bin/bash

###############################################################################
# DEPLOY TO APP VM
# Runs on the App VM to install and configure the application
###############################################################################

set -e

echo "🚀 INSTALLING APPLICATION ON APP VM"
echo "===================================="
echo ""

# Update system
echo "✓ Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install Node.js 18
echo "✓ Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - > /dev/null 2>&1
sudo apt-get install -y nodejs > /dev/null 2>&1

# Install additional dependencies
echo "✓ Installing dependencies..."
sudo apt-get install -y ffmpeg git curl > /dev/null 2>&1

# Create app directory
echo "✓ Setting up application directory..."
sudo mkdir -p /opt/quickclip
sudo chown $USER:$USER /opt/quickclip
cd /opt/quickclip

# Clone or download application code
echo "✓ Downloading application code..."
mkdir -p upload-api worker

# Create upload-api package.json
cat > upload-api/package.json << 'EOF'
{
  "name": "quickclip-upload-api",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "@azure/service-bus": "^7.9.0",
    "@azure/storage-blob": "^12.14.0",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "multer": "^1.4.5-lts.1"
  }
}
EOF

# Create worker package.json
cat > worker/package.json << 'EOF'
{
  "name": "quickclip-worker",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node worker.js"
  },
  "dependencies": {
    "@azure/service-bus": "^7.9.0",
    "@azure/storage-blob": "^12.14.0",
    "@deepgram/sdk": "^3.3.0",
    "@huggingface/inference": "^2.6.4",
    "ffmpeg-static": "^5.1.0"
  }
}
EOF

# Install dependencies
echo "✓ Installing npm dependencies..."
cd upload-api && npm install --production > /dev/null 2>&1
cd ../worker && npm install --production > /dev/null 2>&1
cd ..

echo ""
echo "✅ INSTALLATION COMPLETE"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Copy application files to /opt/quickclip/"
echo "2. Set environment variables in /etc/quickclip/env"
echo "3. Create systemd services"
echo ""
