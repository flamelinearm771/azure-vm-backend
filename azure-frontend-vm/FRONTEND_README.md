# Video Transcription Frontend

A modern Next.js frontend for uploading videos and getting AI-powered transcriptions with real-time progress tracking.

## Features

✅ **Video Upload** - Drag & drop or select video files  
✅ **Real-time Progress Tracking** - Visual progress bar showing backend stage:
  - Uploaded → File received by API
  - Queued → Job in Service Bus queue
  - Processing → Worker is processing
  - Completed → Result ready

✅ **Detailed Activity Log** - See exactly what's happening at each stage  
✅ **Error Handling** - Clear error messages for debugging backend issues  
✅ **Result Display** - Shows transcription, summary, and key points  
✅ **Responsive Design** - Works on desktop and mobile  

## Architecture

```
Frontend (Next.js)
    ↓ POST /upload (video file)
Backend API (upload-api)
    ↓ Creates job, puts in queue
Service Bus (Azure)
    ↓
Worker Service (serviceBusReceiver)
    ↓ Processes video
    ↓ Stores results in Blob Storage
Frontend polls GET /jobs/:jobId
    ↓ Receives status updates
    ↓ Shows results when completed
```

## Setup

### Prerequisites
- Node.js 18+ 
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

The frontend will be available at `http://localhost:3000`

### Configuration

Edit `.env.local` to set your backend URL:

```env
# Local development
NEXT_PUBLIC_BACKEND_URL=http://localhost:3000

# Azure deployment
NEXT_PUBLIC_BACKEND_URL=https://your-backend-url:3000
```

## Backend Integration Points

### 1. Upload Endpoint
**POST** `/upload`

**Request:**
- FormData with `video` field containing the video file

**Response:**
```json
{
  "jobId": "uuid-string",
  "status": "queued"
}
```

**Errors:**
- `400`: Invalid file or missing video field
- `413`: File too large
- `500`: Server error

### 2. Job Status Endpoint
**GET** `/jobs/:jobId`

**Response:**
```json
{
  "status": "queued|processing|completed|failed",
  "result": {
    "transcription": "...",
    "summary": "...",
    "keyPoints": ["...", "..."]
  },
  "error": "Optional error message if status is failed"
}
```

**Possible Statuses:**
- `queued` - Job waiting in Service Bus
- `processing` - Worker actively processing
- `completed` - Processing done, results available
- `failed` - Processing failed

**Errors:**
- `404`: Job not found
- `500`: Server error

## Frontend Stages & Debugging

### Stage Flow
```
idle
  ↓ (file selected)
preparing
  ↓ (submitting)
uploaded
  ↓ (API received file)
queued
  ↓ (Service Bus processing)
processing
  ↓ (Worker active)
completed ✓
  or
failed ✗
```

### Activity Log
The activity log (shown at bottom) displays timestamps for:
- File selection and size
- Upload start/completion
- Job ID creation
- Status changes
- Any errors or retries

### Common Issues

#### "Job not found" or repeated 404s
- **Cause**: Backend not receiving the file correctly
- **Check**: Is `/upload` endpoint working?
- **Debug**: Look for errors in Activity Log with response status

#### Long queue times
- **Cause**: Service Bus queue processing slowly
- **Check**: Is the Worker service running?
- **Debug**: Watch Activity Log for stuck "queued" status

#### Processing hangs
- **Cause**: Worker encountered an error
- **Check**: Is the Worker healthy?
- **Debug**: Look in Activity Log for error messages from status endpoint

#### Upload fails immediately
- **Cause**: Backend URL misconfigured or backend down
- **Check**: `.env.local` has correct `NEXT_PUBLIC_BACKEND_URL`
- **Debug**: Check browser console (F12) for CORS or network errors

## Development

### Scripts
```bash
npm run dev      # Start development server
npm run build    # Build for production
npm start        # Start production server
npm run lint     # Run ESLint
```

### Key Components

**VideoProcessor** - Main component handling:
- File selection and validation
- Upload request
- Polling loop with retry logic
- State management for stages
- UI rendering for progress and results

**ProgressBar** - Visual indicator showing:
- Current stage (numbered circles)
- Completion percentage
- Connecting animated line

**LogViewer** - Activity log with:
- Timestamps for each event
- Color-coded messages (error/warn/success/info)
- Auto-scrolling display

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXT_PUBLIC_BACKEND_URL` | `http://localhost:3000` | Backend API URL |

**Note**: `NEXT_PUBLIC_` prefix makes it available in the browser.

## Deployment

### Azure Container Instances / App Service

1. Build the image:
```bash
npm run build
```

2. Deploy using the provided deployment scripts or:
```bash
az containerapp up \
  --name quickclip-frontend \
  --resource-group your-rg \
  --environment your-env \
  --image your-registry/quickclip-frontend:latest
```

### Vercel

1. Push to GitHub
2. Connect repository to Vercel
3. Set `NEXT_PUBLIC_BACKEND_URL` in Environment Variables
4. Deploy

## Troubleshooting

### Connection Refused
- Backend is not running or not accessible
- Check `NEXT_PUBLIC_BACKEND_URL` 
- Verify firewall/security rules

### CORS Errors
- Backend not allowing requests from this domain
- Backend needs to set proper CORS headers

### Stuck on "Queued"
- Check if Worker service is running
- Review Worker logs for errors
- Check Service Bus queue for messages

### Timeout (Max Retries)
- Backend taking too long to process
- Check backend logs
- Increase `MAX_POLL_RETRIES` if needed

## Browser Requirements
- Modern browser with ES2020+ support
- Chrome, Firefox, Safari, Edge (latest versions)

## Support

Check the activity log first for detailed debugging information. If you need more help, check:
- Browser Console (F12) for network errors
- Backend logs for processing errors
- Worker logs for transcription failures
