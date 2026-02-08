# Video Transcription Service - Complete

A production-ready microservice for video transcription powered by **Deepgram**.

## 🎯 Overview

This is a streamlined, cloud-native transcription service that:
- Accepts video uploads via HTTP API
- Processes videos asynchronously via Azure Service Bus
- Extracts audio and performs speech-to-text transcription
- Returns results as JSON with transcription text

**Technology Stack:**
- Node.js 20 (Docker containers)
- Azure Blob Storage (video/result storage)
- Azure Service Bus (async job queue)
- Azure Container Apps (serverless deployment)
- Deepgram API (speech-to-text)
- ffmpeg (audio extraction)

## 🚀 Quick Start

### Upload a Video

```bash
curl -F "video=@myfile.mp4" \
  https://upload-api.orangecliff-5027c880.centralindia.azurecontainerapps.io/upload
```

**Response:**
```json
{
  "jobId": "26ce08dc-c10a-494a-b40a-0d004fabf8af",
  "status": "queued"
}
```

### Get Transcription Result

Results are stored in Azure Blob Storage at: `results/<jobId>.json`

**Format:**
```json
{
  "transcription": "Hello world, this is a test transcription..."
}
```

## 📋 Architecture

```
User → Upload API → Blob Storage (video) → Service Bus
                         ↑
                         │
                    Worker Service
                         │
                    Deepgram API
                         │
        Blob Storage (results/<jobId>.json)
```

## 📁 Project Structure

```
.
├── upload-api/              # HTTP upload endpoint
│   ├── server.js           # Express server
│   ├── blobUpload.js       # Blob storage upload logic
│   ├── serviceBus.js       # Service Bus publisher
│   ├── Dockerfile          # Container config
│   └── package.json
│
├── worker/                  # Async job processor
│   ├── worker.js           # Main worker loop
│   ├── serviceBusReceiver.js # Service Bus consumer
│   ├── blobDownload.js     # Blob storage download logic
│   ├── lib/
│   │   └── processVideo.js # Core transcription logic
│   ├── Dockerfile          # Container config
│   └── package.json
│
├── queue/                   # Job queue storage
│   └── jobs/              # Pending jobs
│
├── VERIFICATION_COMPLETE.md # Test results & verification
├── CLEANUP_COMPLETE.md      # Cleanup documentation
└── verify.sh               # Automated test script

```

## 🔧 Environment Variables

### Worker Service
- `SERVICE_BUS_CONNECTION_STRING` - Azure Service Bus connection
- `STORAGE_CONNECTION_STRING` - Azure Storage account connection
- `DEEPGRAM_API_KEY` - Deepgram API key for transcription

### Upload API
- `SERVICE_BUS_CONNECTION_STRING` - Azure Service Bus connection
- `STORAGE_CONNECTION_STRING` - Azure Storage account connection

## 📊 Features

✅ **Async Processing** - Jobs queued for reliable processing
✅ **Scalable** - Worker can be scaled to multiple instances
✅ **Error Handling** - Failed jobs saved with error messages
✅ **Stateless** - Can run in containers or serverless
✅ **Simple** - Focused on transcription (no extra features)
✅ **Cloud-Native** - Built for Azure infrastructure

## 🧪 Testing

Run the automated verification script:

```bash
./verify.sh
```

This will:
- Check service health
- Create a test video
- Upload it to the API
- Verify processing
- Confirm result format
- Validate environment variables

## 📈 Performance

| Metric | Value |
|--------|-------|
| Upload latency | <100ms |
| Processing time | ~2-4 seconds |
| API calls | 1 (Deepgram only) |
| Worker scaling | Up to 3 instances |
| Result format | Transcription only |

## 🛠️ Deployment

### Azure Container Apps

Services are deployed to Azure Container Apps:
- **Upload API** - Public FQDN endpoint on port 3000
- **Worker** - Private endpoint (internal networking)

### Docker Images

Pre-built images in Azure Container Registry:
- `videotranscriberacr.azurecr.io/upload-api:latest`
- `videotranscriberacr.azurecr.io/worker:latest`

## 📝 API Reference

### POST /upload

Upload a video for transcription.

**Request:**
```
Content-Type: multipart/form-data
Body: video (binary file)
```

**Response:**
```json
{
  "jobId": "uuid",
  "status": "queued"
}
```

**Status Codes:**
- `200` - Success
- `400` - Bad request (no video)
- `500` - Server error

## 🔐 Security Considerations

- API keys stored in Azure Key Vault
- Service Bus uses connection strings
- Blob storage protected with access keys
- No API authentication (add as needed)
- Results are stored in private blob container

## 📚 Documentation

- [VERIFICATION_COMPLETE.md](VERIFICATION_COMPLETE.md) - Test results & verification
- [CLEANUP_COMPLETE.md](CLEANUP_COMPLETE.md) - Code cleanup documentation

## 🐛 Troubleshooting

### Worker not processing jobs?
```bash
az containerapp logs show --name worker --resource-group video-transcription-pipeline
```

### Check result blob:
```bash
az storage blob download --account-name videostorage1769140753 \
  --container-name results --name "<jobId>.json" \
  --file result.json --account-key "<key>"
cat result.json
```

### Upload API issues?
```bash
az containerapp logs show --name upload-api --resource-group video-transcription-pipeline
```

## 📞 Support

For issues or questions:
1. Check the logs using Azure CLI
2. Verify environment variables are set
3. Confirm Deepgram API key is valid
4. Check Service Bus and Storage Account connectivity

## 📜 License

This project is provided as-is for video transcription services.

---

**Status:** ✅ Production Ready
**Last Updated:** January 23, 2026
**Version:** 1.0.0 (Transcription-only)
