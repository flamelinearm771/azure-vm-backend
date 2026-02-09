# Frontend Quick Start Guide

## What Was Built

✅ Complete Next.js video transcription frontend with:
- Video file upload
- Real-time progress tracking with 4-stage pipeline
- Detailed activity logging
- Error diagnosis
- Beautiful responsive UI

## Quick Start (5 minutes)

### 1. Install Dependencies
```bash
cd azure-frontend-vm
npm install
```

### 2. Configure Backend URL
Edit `.env.local`:
```env
# For local testing (backend on localhost)
NEXT_PUBLIC_BACKEND_URL=http://localhost:3000

# For Azure VM backend
NEXT_PUBLIC_BACKEND_URL=http://your-vm-ip:3000
```

### 3. Start Development Server
```bash
npm run dev
```

### 4. Open in Browser
- Local: http://localhost:3000
- Network: http://your-ip:3000

## How to Test

1. **Select a video file** (MP4, MOV, etc.) - preferably short (10-30 seconds)
2. **Click "Upload & Start"**
3. **Watch the progress tracker**:
   - 🟢 Uploaded (file sent to API)
   - 🟢 Queued (waiting in Service Bus)
   - 🟢 Processing (worker active)
   - 🟢 Completed (results ready)

## Understanding the Activity Log

Watch the timestamps:
```
[14:30:45] Selected file: video.mp4 (15.25 MB)
[14:30:46] Uploading to http://localhost:3000/upload
[14:30:48] Job created with ID: abc-123-def-456
[14:30:48] Initial status: queued
[14:30:50] Job status: queued
[14:31:05] Job status: processing
[14:31:25] Job status: completed
✓ Processing completed successfully!
```

## Troubleshooting

### ❌ Upload fails immediately
```
Error: Failed to fetch - Check NEXT_PUBLIC_BACKEND_URL
```
→ Verify backend is running on the configured URL

### ❌ Stuck on "Queued"
```
[timestamp] Job status: queued (keeps repeating)
```
→ Worker service might not be running. Check backend logs.

### ❌ "Invalid JSON from server"
```
Error: Invalid JSON response
```
→ Backend returning HTML error page. Check backend is responding with JSON.

### ❌ Job 404 errors
```
Poll response not OK: 404
```
→ Job ID might not be persisted. Check backend database/storage.

## Frontend URL Configuration

### Local Development
```env
NEXT_PUBLIC_BACKEND_URL=http://localhost:3000
```

### Azure VM
```env
NEXT_PUBLIC_BACKEND_URL=http://10.0.1.4:3000
```

### Azure Container Apps
```env
NEXT_PUBLIC_BACKEND_URL=https://upload-api.orangecliff-5027c880.centralindia.azurecontainerapps.io
```

## Backend Requirements

Your backend must support:

### ✅ POST /upload
- Accept FormData with `video` file
- Return JSON: `{ jobId, status }`

### ✅ GET /jobs/:jobId  
- Return JSON: `{ status, result, error }`
- Statuses: `queued | processing | completed | failed`

## Production Build

```bash
# Build optimized version
npm run build

# Start production server
npm start
```

## File Structure

```
azure-frontend-vm/
├── .env.local              ← Edit backend URL here
├── package.json
├── next.config.mjs
├── src/
│   └── app/
│       ├── page.jsx        ← Main video processor
│       ├── layout.js       ← App layout
│       └── globals.css     ← Tailwind styles
└── public/
    └── (static assets)
```

## Key Features Explained

### 🔄 Progress Tracking
- Animated progress bar with 4 stages
- Colored indicators (green = active, gray = pending)
- Live status messages

### 📝 Activity Log
- **[time]** - Timestamp of event
- **success** (green) - Operations completed
- **error** (red) - Something went wrong
- **warn** (yellow) - Worth investigating
- **info** (gray) - General information

### 🎯 Error Recovery
- Auto-retries polling up to 30 times (~60 sec)
- Clear error messages for each failure point
- Logs show exactly where in pipeline it failed

### 📊 Results Display
Shows:
- **Transcription** - Full video transcript
- **Summary** - AI-generated summary
- **Key Points** - Extracted main points (if available)

## Next Steps

1. **Start backend** (upload-api and worker services)
2. **Run frontend**: `npm run dev`
3. **Test upload**: Select video → watch progress → check results
4. **Monitor logs**: Check Activity Log for any errors

## Support

- **Console**: Open F12 browser console for network logs
- **Activity Log**: Shows backend communication timeline
- **Backend logs**: Check backend service logs for processing errors

Good luck! 🚀
