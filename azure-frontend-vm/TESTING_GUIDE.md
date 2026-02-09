# Frontend Testing & Verification Guide

## Pre-Flight Checklist

Before running the frontend, ensure:

- [ ] Node.js 18+ installed (`node --version`)
- [ ] Backend service is running on configured port
- [ ] Backend API endpoints working:
  - [ ] `POST /upload` returns `{ jobId, status }`
  - [ ] `GET /jobs/{id}` returns `{ status, result }`
- [ ] Network access between frontend and backend

## Step-by-Step Test

### Step 1: Install & Configure

```bash
# Navigate to frontend
cd azure-frontend-vm

# Install dependencies
npm install

# Check that .env.local exists
cat .env.local
# Should show: NEXT_PUBLIC_BACKEND_URL=http://localhost:3000
```

### Step 2: Start Development Server

```bash
npm run dev
```

Expected output:
```
✓ Ready in 2.5s
➜ Local:   http://localhost:3000
➜ Profiles: http://localhost:3000/profiles
➜ press h for help
```

### Step 3: Open in Browser

Navigate to: `http://localhost:3000`

Should see:
- Purple/indigo gradient background
- "Video Transcription" title
- Video file input
- Upload & Start button
- Reset button

### Step 4: Test Upload

1. **Select a video file**
   - Click file input
   - Choose a short video (10-30 seconds preferred)
   - Watch for: "Selected: video.mp4 (X.XX MB)" confirmation

2. **Click Upload & Start**
   - Progress bar appears
   - Activity Log starts showing events

3. **Monitor Activity Log**
   ```
   [timestamp] Selected file: video.mp4 (15.25 MB)
   [timestamp] Uploading to http://localhost:3000/upload
   [timestamp] Job created with ID: abc-123-def-456
   [timestamp] Initial status: queued
   ```

4. **Watch Progress Bar**
   - Stage 1: 🟢 Uploaded
   - Stage 2: 🟢 Queued (might stay here while waiting)
   - Stage 3: 🟢 Processing
   - Stage 4: 🟢 Completed

5. **Check Results**
   - When completed, should see:
     - Transcription section with full text
     - Summary section
     - Key Points (if available)

## Expected Timings

| Stage | Duration | Notes |
|-------|----------|-------|
| Upload | 1-3 sec | Depends on file size & network |
| Queued | 1-10 sec | Waiting in Service Bus |
| Processing | 5-30 sec | Depends on video length & complexity |
| Result Display | Instant | Once status changes to completed |

**Total**: 10-45 seconds for a typical 10-30 sec video

## Troubleshooting: Common Issues

### ❌ Cannot select file

**Symptom**: File input disabled or not responding

**Solution**:
- Check browser console (F12) for JavaScript errors
- Make sure you're clicking on the input, not outside it
- Try refreshing the page

---

### ❌ Upload fails immediately

**Symptom**:
```
Error: Failed to fetch
or
Error: Connect to backend failed
```

**Activity Log shows**:
```
[timestamp] Uploading to http://localhost:3000/upload
[timestamp] Upload failed: Failed to fetch
```

**Causes & Solutions**:
1. Backend not running
   - Start backend: `npm run dev` (in backend folder)
   - Verify it's listening on port 3000

2. Wrong backend URL
   - Edit `.env.local`
   - Restart frontend: `npm run dev`
   - Activity log should show correct URL

3. CORS error (check browser console)
   - Backend needs CORS headers
   - Add to backend: `Access-Control-Allow-Origin: *`

4. Firewall blocking
   - Check if ports are accessible
   - Try: `curl http://localhost:3000` from terminal

---

### ❌ Upload succeeds but stuck on "Queued"

**Symptom**:
```
Progress bar at stage 2 "Queued"
Activity log keeps showing:
  [timestamp] Job status: queued
  [timestamp] Job status: queued
  [timestamp] Job status: queued
```

**Causes & Solutions**:
1. Worker service not running
   - Check if Worker process is active
   - Start Worker: `npm run dev` (in worker folder)
   - Watch Worker logs for errors

2. Service Bus not configured
   - Check Worker can connect to Service Bus
   - Verify connection string in Worker config

3. Job not properly queued
   - Check backend logs for errors
   - Try with smaller video file

---

### ❌ Stuck on "Processing"

**Symptom**:
```
Progress bar at stage 3 "Processing"
Status remains unchanged after 2+ minutes
```

**Causes & Solutions**:
1. Worker crashed
   - Check Worker logs for error
   - Restart Worker service

2. Video processing taking too long
   - Worker might be slow
   - Try with shorter/smaller video

3. Timeout in processing
   - Check Worker logs for specific error
   - May need to increase timeout

---

### ❌ "Job not found" error

**Symptom**:
```
Activity log shows:
  [timestamp] Poll response not OK: 404
  [timestamp] Max retries reached. Stopping poll.
Error: Job polling timeout
```

**Causes & Solutions**:
1. Job ID not persisted
   - Backend needs to save job to database/cache
   - Check backend storage configuration

2. Wrong job ID format
   - Verify jobId returned from upload is correct
   - Check backend logs

3. Backend lost job data
   - Check if backend restarted after upload
   - Verify persistent storage is configured

---

### ❌ "Invalid JSON from server"

**Symptom**:
```
Activity log shows:
  [timestamp] Invalid JSON response: <!DOCTYPE html>...
```

**Solution**:
- Backend is returning HTML error page
- Check browser console for what status code is returned
- Look in backend logs for the actual error

---

### ❌ Results show but transcription is empty

**Symptom**:
```
Result displays but transcription section empty
```

**Causes & Solutions**:
1. Worker didn't generate transcription
   - Check Worker logs for errors
   - Verify AI service is configured

2. Result not properly formatted
   - Check backend returns: `{ transcription: "..." }`
   - Verify Worker saves results correctly

## Testing Different Scenarios

### Test 1: Small Video (Recommended First Test)
```
File: 10-second MP4 (< 5 MB)
Expected: Complete within 30 seconds
```

### Test 2: Larger Video
```
File: 1-minute MP4 (50-100 MB)
Expected: Complete within 1-2 minutes
```

### Test 3: Multiple Uploads
```
Upload video 1 → Complete
Reset
Upload video 2 → Complete
Upload video 3 while video 2 processing
Expected: All should complete without conflicts
```

### Test 4: Network Interruption
```
Start upload
Disconnect internet briefly
Expected: Frontend shows error or retries gracefully
Reconnect
Expected: Frontend recovers if poll not timed out
```

## Verification Checklist

- [ ] Frontend loads without console errors
- [ ] Can select video file
- [ ] File size displays correctly
- [ ] Upload button works
- [ ] Activity log shows events with timestamps
- [ ] Progress bar appears and updates
- [ ] Job ID visible in Activity log
- [ ] Status changes from Queued → Processing → Completed
- [ ] Results display with transcription
- [ ] Can upload multiple videos
- [ ] Reset button clears everything
- [ ] Error messages are helpful and clear

## Performance Benchmarks

Expected performance on typical system:

| Operation | Time | Status |
|-----------|------|--------|
| Frontend load | < 2 sec | Should be instant |
| File selection | Instant | No delay |
| Upload (10 MB) | 2-5 sec | Depends on network |
| Queue wait | 1-10 sec | Depends on queue depth |
| Processing (30 sec video) | 10-30 sec | Depends on model |
| Result display | < 1 sec | Instant once ready |

## Browser Console Debugging

Open F12 and check Console tab for:

1. **Network errors**:
   - CORS issues
   - Connection refused
   - Timeouts

2. **React errors**:
   - Component rendering issues
   - State management errors

3. **Polling logs**:
   - Frontend logs each poll attempt
   - Shows response status codes

Common patterns to search for:
```javascript
// In console, type:
// See all fetch errors
console.log(document.body.innerHTML); // See rendered HTML

// Check Network tab to see:
// - POST /upload request/response
// - GET /jobs/:id requests/responses
// - Check Status codes (200 = good, 4xx = client error, 5xx = server error)
```

## Success Indicators

✅ Everything working when you see:

1. **Upload response**:
   ```json
   {
     "jobId": "550e8400-e29b-41d4-a716-446655440000",
     "status": "queued"
   }
   ```

2. **Status response**:
   ```json
   {
     "status": "completed",
     "result": {
       "transcription": "Full transcript text...",
       "summary": "Brief summary..."
     }
   }
   ```

3. **Frontend display**:
   - Green checkmarks on all 4 stages
   - "✓ Processing completed successfully!" message
   - Transcription text visible
   - No error messages

## Need More Help?

1. **Check Activity Log** - Shows exact error and stage
2. **Open Browser Console (F12)** - Shows network/JS errors
3. **Check Backend Logs** - Backend service logs
4. **Check Worker Logs** - Worker service logs
5. **Read FRONTEND_README.md** - Detailed documentation

---

**Remember**: The Activity Log is your best debugging tool. It shows exactly what's happening at each stage!
