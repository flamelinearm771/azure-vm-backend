# QuickClip VM Deployment Guide

## Overview

QuickClip has been transitioned from a container-based architecture to a VM-based deployment on Azure. This guide provides step-by-step instructions to complete the deployment.

**Architecture:**
- **Load Balancer**: Public endpoint (20.204.249.182)
- **App VM 1**: Running Upload API + Worker Service (10.0.0.4)
- **Storage Account**: Blob storage for videos & results
- **Service Bus**: Message queue for async job processing

---

## Prerequisites

✅ **Completed:**
- Azure Infrastructure provisioned
- NSG rules configured correctly
- Load Balancer health probe set to HTTP /health
- Service Bus namespace & queue created
- Storage Account with containers created

⚠️ **Required API Keys** (to be added):
- DEEPGRAM_API_KEY: https://console.deepgram.com/
- HF_TOKEN: https://huggingface.co/settings/tokens

---

## Quick Start (5 Minutes)

### Option 1: Manual SSH Deployment

1. **Access App VM**
   ```bash
   # You can SSH using Azure CLI or Bastion
   # Username: vm-app
   # Password: Virtual-Machine-App-1
   ```

2. **Download Deployment Package**
   ```bash
   cd /tmp
   # Copy the deployment package from your local machine
   # Or download from provided source
   ```

3. **Run Installation**
   ```bash
   cd /tmp/quickclip-deploy
   bash install.sh
   ```

4. **Configure API Keys**
   ```bash
   sudo nano /etc/quickclip/env
   # Add your API keys:
   # DEEPGRAM_API_KEY=sk-XXXX
   # HF_TOKEN=hf_XXXX
   ```

5. **Start Services**
   ```bash
   sudo systemctl enable quickclip-api
   sudo systemctl enable quickclip-worker
   sudo systemctl start quickclip-api
   sudo systemctl start quickclip-worker
   ```

6. **Verify**
   ```bash
   curl http://20.204.249.182/health
   # Expected: {"status":"healthy","timestamp":"2026-02-08T..."}
   ```

### Option 2: Using Azure Run Command (from local machine)

```bash
# Upload and execute deployment script on VM
az vm run-command invoke \
  -g vm-migration \
  -n vm-migartion-virtual-machine-for-app-1 \
  --command-id RunShellScript \
  --scripts "bash /tmp/quickclip-deploy/install.sh"
```

---

## Detailed Deployment Steps

### Step 1: Prepare Deployment Package

The deployment package includes:
- `upload-api/` - Node.js Express server
  - `server-vm.js` - Main upload endpoint
  - `blobStorage.js` - Blob upload handler
  - `serviceBus.js` - Message sender
  - `blobResults.js` - Result retrieval
  - `package.json` - Dependencies

- `worker/` - Background job processor
  - `worker-vm.js` - Job handler
  - `serviceBusReceiver.js` - Queue consumer
  - `blobDownload.js` - Video downloader
  - `blobResults.js` - Result uploader
  - `lib/processVideo.js` - Audio extraction, ASR, summarization
  - `package.json` - Dependencies

- `systemd/` - Service definitions
  - `quickclip-api.service` - Upload API service
  - `quickclip-worker.service` - Worker service

- `env` - Environment variables
- `install.sh` - Installation script

### Step 2: Verify Azure Resources

```bash
# Check Storage Account
az storage account show -g vm-migration -n quickclipsa14899

# Check Service Bus Queue
az servicebus queue list -g vm-migration --namespace-name quickclip-sb-14899

# Check NSG Rules
az network nsg rule list -g vm-migration --nsg-name network-security-group-app -o table
```

### Step 3: Install on App VM

The `install.sh` script will:
1. ✅ Update system packages
2. ✅ Install Node.js 18
3. ✅ Install ffmpeg (audio extraction)
4. ✅ Create `quickclip` system user
5. ✅ Deploy application to `/opt/quickclip/`
6. ✅ Install npm dependencies
7. ✅ Register systemd services
8. ✅ Configure environment variables

### Step 4: Add API Keys

Edit `/etc/quickclip/env`:

```bash
sudo nano /etc/quickclip/env
```

Find and update:
```env
DEEPGRAM_API_KEY=sk_your_deepgram_key_here
HF_TOKEN=hf_your_huggingface_token_here
```

### Step 5: Start Services

```bash
# Enable auto-start on system boot
sudo systemctl enable quickclip-api
sudo systemctl enable quickclip-worker

# Start services
sudo systemctl start quickclip-api
sudo systemctl start quickclip-worker

# Check status
sudo systemctl status quickclip-api
sudo systemctl status quickclip-worker

# View logs
sudo journalctl -u quickclip-api -f
sudo journalctl -u quickclip-worker -f
```

---

## Service Specifications

### Upload API Service (Port 3000)

**Endpoints:**

1. **Health Check** `GET /health`
   ```bash
   curl http://20.204.249.182/health
   ```
   Response:
   ```json
   {
     "status": "healthy",
     "timestamp": "2026-02-08T07:41:39.000Z"
   }
   ```

2. **Upload Video** `POST /upload`
   ```bash
   curl -F "video=@video.mp4" http://20.204.249.182/upload
   ```
   Response:
   ```json
   {
     "jobId": "uuid-here",
     "status": "queued"
   }
   ```

3. **Check Job Status** `GET /jobs/:jobId`
   ```bash
   curl http://20.204.249.182/jobs/uuid-here
   ```
   
   While processing:
   ```json
   {
     "status": "processing"
   }
   ```
   
   When complete:
   ```json
   {
     "status": "completed",
     "result": {
       "transcription": "...",
       "summary": "...",
       "processedAt": "2026-02-08T..."
     }
   }
   ```

### Worker Service

**Function:**
- Listens to Service Bus queue `video-jobs`
- Downloads video from Blob Storage
- Extracts audio with ffmpeg
- Calls Deepgram for ASR (transcription)
- Calls HuggingFace for summarization
- Uploads results to Blob Storage
- Automatically retries on failure

**Log Output:**
```
📡 Worker listening for messages on queue: video-jobs
📥 Received job: uuid-here
📥 Downloaded video to: /tmp/video.mp4
🎙️  Extracting audio...
✅ Audio extraction complete
🎤 Calling Deepgram ASR (nova-2)...
✅ Transcription complete: 5432 characters
📝 Generating summary with HuggingFace...
✅ Summary generation complete
✅ Uploaded result for job: uuid-here
✅ Job completed: uuid-here
```

---

## Frontend Configuration

### Next.js Frontend Setup

Configure the backend URL in your frontend environment:

```bash
# .env.local or .env.production
NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182
```

Or set at build time:
```bash
NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182 npm run build
```

### Frontend Code Flow

1. **User selects video** → displayed file info
2. **User clicks "Upload & Start"** → `POST /upload`
3. **Receive jobId** → start polling
4. **Poll every 2 seconds** → `GET /jobs/:jobId`
5. **Show stage progression**: Uploaded → Queued → Processing → Completed
6. **Display results**: Transcription + Summary

---

## Security Architecture

### Network Isolation

```
┌─────────────────────────────────────────────┐
│  Internet (Public)                          │
│  Frontend Users (Anywhere)                  │
└────────────────┬────────────────────────────┘
                 │
                 ▼
         ┌──────────────┐
         │  Load Balancer│  ← Public IP: 20.204.249.182
         │ Port 80/443  │     Health check: /health
         └────────┬─────┘
                  │
    ┌─────────────▼─────────────┐
    │  VNet: 10.0.0.0/16        │
    │  ┌──────────────────────┐ │
    │  │ app-subnet           │ │
    │  │ 10.0.0.0/24          │ │
    │  │                      │ │
    │  │ ┌────────────────┐   │ │
    │  │ │ App VM 1       │   │ │
    │  │ │ 10.0.0.4       │   │ │
    │  │ │ - Upload API   │   │ │
    │  │ │ - Worker       │   │ │
    │  │ └────────────────┘   │ │
    │  └──────────────────────┘ │
    │  ┌──────────────────────┐ │
    │  │ db-subnet            │ │
    │  │ 10.0.1.0/24          │ │
    │  │ (Private - DB only)  │ │
    │  └──────────────────────┘ │
    └─────────────────────────────┘

NSG Rules:
  - App Subnet: Allow HTTP/HTTPS from Internet
  - App Subnet: Allow Service Bus/Blob access (Azure)
  - DB Subnet: Allow access only from App Subnet
  - All egress allowed by default
```

### Data Flow Security

- **Upload**: Video → Blob Storage (HTTPS only)
- **Messages**: Job ID → Service Bus (HTTPS only)
- **Results**: Transcription → Blob Storage (HTTPS only)
- **Network**: All resources in private subnets
- **Access**: Only Load Balancer exposes public endpoint

---

## Monitoring & Troubleshooting

### Check Service Status

```bash
# Both services should be "active (running)"
sudo systemctl status quickclip-api
sudo systemctl status quickclip-worker
```

### View Recent Logs

```bash
# Last 50 lines from Upload API
sudo journalctl -u quickclip-api -n 50

# Last 50 lines from Worker
sudo journalctl -u quickclip-worker -n 50

# Real-time log stream
sudo journalctl -u quickclip-api -f
```

### Common Issues

**Issue: Services won't start**
```bash
# Check if environment file exists
cat /etc/quickclip/env

# Check file permissions
sudo ls -la /etc/quickclip/env

# Should be: -rw------- (600 permissions)
sudo chmod 600 /etc/quickclip/env
```

**Issue: API returns 500 error**
```bash
# Check logs for error details
sudo journalctl -u quickclip-api -n 100

# Most common: Missing API keys
grep "API_KEY\|HF_TOKEN" /etc/quickclip/env
```

**Issue: Worker not processing jobs**
```bash
# Check Service Bus connection
curl -X POST \
  -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)" \
  "https://quickclip-sb-14899.servicebus.windows.net/video-jobs?api-version=2021-05"

# Check worker logs
sudo journalctl -u quickclip-worker -n 100
```

**Issue: Upload API not responding**
```bash
# Check health endpoint
curl http://20.204.249.182/health

# If 404, app may not be running
# If timeout, check NSG rules
az network nsg rule list -g vm-migration --nsg-name network-security-group-app

# NSG must allow TCP 80 from Internet
```

---

## Testing the Full Pipeline

### 1. Health Check
```bash
curl -i http://20.204.249.182/health
# Expected: HTTP 200 OK
```

### 2. Upload Test Video
```bash
# Create a dummy video (ffmpeg required)
ffmpeg -f lavfi -i testsrc=duration=5:size=320x240:rate=1 test.mp4

# Upload to API
RESPONSE=$(curl -F "video=@test.mp4" http://20.204.249.182/upload)
echo $RESPONSE | jq .

# Extract jobId
JOB_ID=$(echo $RESPONSE | jq -r '.jobId')
echo "Job ID: $JOB_ID"
```

### 3. Poll Status
```bash
# Poll every 5 seconds until complete
for i in {1..60}; do
  STATUS=$(curl -s http://20.204.249.182/jobs/$JOB_ID | jq -r '.status')
  echo "[$i] Status: $STATUS"
  
  if [ "$STATUS" = "completed" ]; then
    curl http://20.204.249.182/jobs/$JOB_ID | jq .
    break
  fi
  
  sleep 5
done
```

### 4. Verify Results
```bash
# Results stored in Blob Storage
az storage blob list -c results --connection-string "$(az storage account show-connection-string -g vm-migration -n quickclipsa14899 -o tsv)" -o table
```

---

## Performance Optimization

### VM Configuration
- **Current**: Standard_B2s (2 vCPU, 4GB RAM)
- **Recommended for production**: Standard_D2s_v3 (2 vCPU, 8GB RAM)

### Scaling Strategy
1. **Add App VM 2** for load distribution
2. **Add Auto-scale** based on Service Bus queue depth
3. **Increase Worker Concurrency** (currently 1 worker per VM)

### Resource Limits
- **Storage Account**: 20PB (plenty for video storage)
- **Service Bus Queue**: 3GB max size
- **Blob Timeout**: 5 minutes per video

---

## Next Steps

1. ✅ SSH into App VM
2. ✅ Run installation script
3. ✅ Add API keys
4. ✅ Start services
5. ✅ Test health endpoint
6. ✅ Upload test video
7. ✅ Configure frontend with backend URL
8. ✅ Deploy frontend

---

## Support Resources

- **Deepgram Documentation**: https://developers.deepgram.com/
- **HuggingFace Inference**: https://huggingface.co/docs/hub/inference-overview
- **Azure Service Bus**: https://docs.microsoft.com/azure/service-bus-messaging/
- **Azure Storage**: https://docs.microsoft.com/azure/storage/blobs/

---

**Status**: Ready for deployment  
**Last Updated**: February 8, 2026  
**Architecture**: VM-based with Load Balancer, Service Bus, and Blob Storage
