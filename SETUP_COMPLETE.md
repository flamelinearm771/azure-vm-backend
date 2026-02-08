# QuickClip VM Deployment - Quick Setup Guide

## ✅ What's Done

The complete QuickClip application has been deployed to the Azure VM at `10.0.0.4` behind load balancer IP `20.204.249.182`.

**Installed:**
- ✅ Node.js 18, ffmpeg
- ✅ Upload API service (Express.js server)
- ✅ Worker service (Azure Service Bus consumer)
- ✅ Systemd auto-restart services
- ✅ Environment configuration template

## 🔧 Required Setup (5 minutes)

### Step 1: Get Your Azure Credentials

Run these commands on your local machine:

```bash
# Get Service Bus connection string
SB_KEY=$(az servicebus namespace authorization-rule keys list \
  -g vm-migration \
  --namespace-name quickclip-sb-14899 \
  -n RootManageSharedAccessKey \
  --query primaryConnectionString --out tsv)

echo "SERVICE_BUS: $SB_KEY"

# Get Storage connection string
STORAGE_KEY=$(az storage account show-connection-string \
  -g vm-migration \
  -n quickclipsa14899 \
  --query connectionString --out tsv)

echo "STORAGE: $STORAGE_KEY"
```

### Step 2: Get API Keys

- **Deepgram API Key**: https://console.deepgram.com/
- **HuggingFace Token**: https://huggingface.co/settings/tokens

### Step 3: SSH to VM and Update Configuration

```bash
# SSH to VM
ssh vm-app@20.204.249.182

# Edit configuration
sudo nano /etc/quickclip/env
```

Update the file with your values:
```
SERVICE_BUS_CONNECTION_STRING=Endpoint=sb://quickclip-sb-14899.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_SB_KEY_HERE
STORAGE_CONNECTION_STRING=DefaultEndpointProtocol=https;AccountName=quickclipsa14899;AccountKey=YOUR_STORAGE_KEY_HERE;EndpointSuffix=core.windows.net
DEEPGRAM_API_KEY=sk_live_YOUR_DEEPGRAM_KEY_HERE
HF_TOKEN=hf_YOUR_HUGGINGFACE_TOKEN_HERE
```

### Step 4: Restart Services

```bash
sudo systemctl restart quickclip-api quickclip-worker
```

### Step 5: Verify

```bash
# Check services
sudo systemctl status quickclip-api quickclip-worker

# Check logs
sudo journalctl -u quickclip-api -n 20
```

## 🧪 Test the API

### From local machine:

```bash
# 1. Health check
curl http://20.204.249.182/health

# 2. Create test video
ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 test.mp4

# 3. Upload video
JOB_ID=$(curl -s -F "video=@test.mp4" http://20.204.249.182/upload | jq -r '.jobId')
echo "Job ID: $JOB_ID"

# 4. Check status (wait a few seconds for worker to process)
curl http://20.204.249.182/jobs/$JOB_ID
```

## 🚀 Frontend Setup

In your Next.js frontend .env.local:
```
NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182
```

Then use:
```javascript
const API_URL = process.env.NEXT_PUBLIC_BACKEND_URL

// Upload
const formData = new FormData()
formData.append('video', videoFile)
const { jobId } = await fetch(`${API_URL}/upload`, {
  method: 'POST',
  body: formData
}).then(r => r.json())

// Get results
const results = await fetch(`${API_URL}/jobs/${jobId}`).then(r => r.json())
```

## 📊 Architecture

```
Frontend (Next.js)
        ↓
Load Balancer (20.204.249.182:80)
        ↓
App VM (10.0.0.4:3000)
    ├─ Upload API
    │  ├─ /upload (POST) - Accept video, send to queue
    │  ├─ /health (GET) - Health check
    │  └─ /jobs/:jobId (GET) - Get results
    │
    └─ Worker Service
       └─ Listens to Service Bus
          └─ Processes with ffmpeg + Deepgram + HuggingFace
             └─ Saves results to Blob Storage

Azure Services
├─ Service Bus (video-jobs queue)
├─ Blob Storage (videos & results)
└─ Load Balancer (health checks on /health)
```

## 🔍 Troubleshooting

### API not responding

```bash
# SSH to VM
ssh vm-app@20.204.249.182

# Check service status
sudo systemctl status quickclip-api

# Check logs
sudo journalctl -u quickclip-api -n 50

# Check if environment variables are set
cat /etc/quickclip/env

# Restart
sudo systemctl restart quickclip-api
```

### Worker not processing jobs

```bash
# Check worker
sudo systemctl status quickclip-worker

# Check logs
sudo journalctl -u quickclip-worker -n 50

# Verify connection to Service Bus
az servicebus queue show \
  -g vm-migration \
  --namespace-name quickclip-sb-14899 \
  --name video-jobs
```

### Permissions issues

```bash
sudo chown -R quickclip:quickclip /opt/quickclip
sudo chmod 600 /etc/quickclip/env
```

## 📝 Important Files

- **Config**: `/etc/quickclip/env`
- **API**: `/opt/quickclip/upload-api/`
- **Worker**: `/opt/quickclip/worker/`
- **Services**: `/etc/systemd/system/quickclip-*.service`

## 🎯 Deployment Complete!

Your QuickClip backend is ready to receive videos:
- **Upload URL**: `http://20.204.249.182/upload`
- **Health Check**: `http://20.204.249.182/health`
- **Results URL**: `http://20.204.249.182/jobs/{jobId}`

Connect your frontend and start uploading! 🎉
