# QuickClip Deployment Verification

## Deployment Status

✅ **Deployment Script Created**: `/tmp/deploy-final.sh`

✅ **Executed via Azure CLI**: Deployment package sent to VM

## What Was Deployed

### System Components
- ✅ Node.js 18 installed
- ✅ FFmpeg installed
- ✅ Application user `quickclip` created
- ✅ Application directories created at `/opt/quickclip/`

### Application Files Deployed

#### Upload API (`/opt/quickclip/upload-api/`)
- `server-vm.js` - Express.js server with REST endpoints
- `blobStorage-vm.js` - Azure Blob Storage upload handler
- `serviceBus-vm.js` - Service Bus message sender
- `blobResults-vm.js` - Result retrieval from Blob
- `package.json` - Dependencies (express, cors, multer, azure-service-bus, azure-storage-blob)

#### Worker Service (`/opt/quickclip/worker/`)
- `worker-vm.js` - Service Bus consumer and orchestrator
- `serviceBusReceiver-vm.js` - Queue listener with retry logic
- `blobDownload-vm.js` - Video downloader from Blob Storage
- `blobResults-vm.js` - Result uploader to Blob Storage
- `lib/processVideo-vm.js` - Video processor with ffmpeg, Deepgram, HuggingFace integration
- `package.json` - Dependencies

#### Configuration
- `/etc/quickclip/env` - Environment variables with Azure credentials
- `/etc/systemd/system/quickclip-api.service` - API auto-start service
- `/etc/systemd/system/quickclip-worker.service` - Worker auto-start service

## Service Status

### To Check Service Status (SSH to VM):
```bash
ssh vm-app@20.204.249.182
sudo systemctl status quickclip-api quickclip-worker
```

### To View Service Logs:
```bash
# API logs
sudo journalctl -u quickclip-api -f

# Worker logs
sudo journalctl -u quickclip-worker -f
```

## Health Check

### Test API Health:
```bash
curl http://20.204.249.182/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-02-08T..."
}
```

## Configuration Required

The deployment created all files but with placeholder values for API keys:

### 1. Get Azure Connection Strings

On your local machine:
```bash
# Service Bus connection string
az servicebus namespace authorization-rule keys list \
  -g vm-migration \
  --namespace-name quickclip-sb-14899 \
  -n RootManageSharedAccessKey \
  --query primaryConnectionString --out tsv

# Storage account connection string
az storage account show-connection-string \
  -g vm-migration \
  -n quickclipsa14899 \
  --query connectionString --out tsv
```

### 2. Get API Keys

- **Deepgram**: https://console.deepgram.com/ → API Keys
- **HuggingFace**: https://huggingface.co/settings/tokens

### 3. Update Environment File on VM

SSH to VM:
```bash
ssh vm-app@20.204.249.182
sudo nano /etc/quickclip/env
```

Update these lines:
```
SERVICE_BUS_CONNECTION_STRING=Endpoint=sb://quickclip-sb-14899.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY_HERE
STORAGE_CONNECTION_STRING=DefaultEndpointProtocol=https;AccountName=quickclipsa14899;AccountKey=YOUR_KEY_HERE;EndpointSuffix=core.windows.net
DEEPGRAM_API_KEY=sk_live_YOUR_KEY_HERE
HF_TOKEN=hf_YOUR_TOKEN_HERE
```

### 4. Restart Services with Credentials

```bash
sudo systemctl restart quickclip-api quickclip-worker
```

## Deployment Endpoints

- **Upload Endpoint**: `POST http://20.204.249.182/upload`
  - Accepts multipart form-data with `video` file
  - Returns: `{jobId, status: "queued"}`

- **Health Endpoint**: `GET http://20.204.249.182/health`
  - Returns: `{status: "healthy", timestamp}`

- **Job Status Endpoint**: `GET http://20.204.249.182/jobs/:jobId`
  - Returns: `{jobId, transcript, summary, processedAt}`

## Frontend Integration

Configure frontend with:
```javascript
const API_URL = 'http://20.204.249.182'

// Upload video
const formData = new FormData()
formData.append('video', videoFile)

const response = await fetch(`${API_URL}/upload`, {
  method: 'POST',
  body: formData
})

const { jobId } = await response.json()

// Check job status
const statusResponse = await fetch(`${API_URL}/jobs/${jobId}`)
const results = await statusResponse.json()
```

## Service Auto-Restart

Both services are configured to:
- Start automatically on VM boot
- Restart automatically if they crash
- Restart with 10-second delay after failure

## Logs Location

- API logs: `sudo journalctl -u quickclip-api`
- Worker logs: `sudo journalctl -u quickclip-worker`
- System logs: `/var/log/syslog`

## Troubleshooting

### API not responding
1. Check service is running: `sudo systemctl status quickclip-api`
2. Check logs: `sudo journalctl -u quickclip-api -n 50`
3. Verify connection strings in: `cat /etc/quickclip/env`
4. Restart service: `sudo systemctl restart quickclip-api`

### Worker not processing jobs
1. Check service: `sudo systemctl status quickclip-worker`
2. Check logs: `sudo journalctl -u quickclip-worker -n 50`
3. Verify Service Bus connection: `az servicebus queue show --resource-group vm-migration --namespace-name quickclip-sb-14899 --name video-jobs`

### File permissions
```bash
# Ensure quickclip user owns files
sudo chown -R quickclip:quickclip /opt/quickclip
sudo chmod 600 /etc/quickclip/env
```

## Infrastructure Summary

| Component | Value |
|-----------|-------|
| Load Balancer IP | 20.204.249.182 |
| App VM | 10.0.0.4 |
| Storage Account | quickclipsa14899 |
| Service Bus | quickclip-sb-14899 |
| API Port | 3000 |
| Region | Central India |

## Next Steps

1. ✅ Deploy application - DONE
2. ⏳ SSH to VM and update `/etc/quickclip/env` with real credentials
3. ⏳ Restart services
4. ⏳ Test health endpoint
5. ⏳ Deploy frontend with `NEXT_PUBLIC_BACKEND_URL=http://20.204.249.182`
6. ⏳ Test end-to-end upload workflow
