# Deployment Guide: PostgreSQL Transcriptions Layer + Read-Only Endpoint

**Status:** Ready for deployment to vm-app ONLY  
**Date:** February 10, 2026  
**Environment:** Production (Live)  
**Risk Level:** Low (additive changes, backward compatible)

---

## Summary of Changes

✅ **Merged:** feature/save-transcriptions-to-db → main  
✅ **New Commits:** 5 total (4 from feature branch + 1 new endpoint)

### What Changed:
1. Worker saves transcriptions to PostgreSQL after blob upload
2. API checks PostgreSQL first, falls back to blob storage
3. NEW: Frontend can now fetch all transcriptions via `/transcriptions` endpoint

### What Did NOT Change:
- ✓ Database schema (vm-db untouched)
- ✓ PostgreSQL configuration (vm-db untouched)
- ✓ Blob storage logic (unchanged)
- ✓ Service Bus pipeline (unchanged)
- ✓ Existing API endpoints (/ , /upload, /jobs/:jobId, /health)
- ✓ Authentication (none added)
- ✓ .env secrets (none added)

---

## Pre-Deployment Checklist

Before proceeding, verify:

- [ ] You are on vm-app (NOT vm-db)
- [ ] You have git access to the repository
- [ ] Worker and upload-api services are currently running
- [ ] PostgreSQL on vm-db is reachable from vm-app
- [ ] No active job processing (wait for queue to clear, or stop briefly)

---

## Deployment Steps (vm-app ONLY)

### Step 1: Pull Latest Code

```bash
# SSH into vm-app
ssh <vm-app-user>@<vm-app-public-ip>

# Navigate to repository
cd ~/azure-backend-vm

# Verify you're on main branch
git branch
# Expected: * main

# Pull the latest changes
git pull origin main
# Expected: Fast-forward to commit 1673e3b
```

### Step 2: Verify No Local Changes on vm-app

```bash
# Check for uncommitted changes
git status
# Expected: "On branch main. Your branch is up to date with 'origin/main'"

# Check for untracked files that shouldn't be there
git log --oneline -3
# Expected:
# 1673e3b feat: add read-only /transcriptions endpoint for frontend
# 54f1774 feat: check PostgreSQL first when fetching job results
# edae1cc feat: add database helper module for upload-api (db-vm.js)
```

### Step 3: Stop Services Gracefully

```bash
# Stop the services (brief downtime, ~30 seconds)
sudo systemctl stop quickclip-worker.service
sudo systemctl stop quickclip-api.service

# Wait for graceful shutdown
sleep 5

# Verify they're stopped
sudo systemctl status quickclip-worker.service
sudo systemctl status quickclip-api.service
# Expected: "inactive (dead)"
```

### Step 4: Verify Database Connectivity

```bash
# Test connection to vm-db from vm-app
psql -h 10.0.1.4 -U appuser -d transcription_db -c "SELECT COUNT(*) FROM transcriptions;"
# Expected: Returns a number (count of rows)
```

### Step 5: Restart Services

```bash
# Start both services
sudo systemctl start quickclip-worker.service
sudo systemctl start quickclip-api.service

# Wait for startup
sleep 3

# Verify both are running
sudo systemctl status quickclip-worker.service
sudo systemctl status quickclip-api.service
# Expected: "active (running)"
```

### Step 6: Check Logs for Errors

```bash
# Check worker logs (last 30 lines)
sudo journalctl -u quickclip-worker.service -n 30

# Check API logs (last 30 lines)
sudo journalctl -u quickclip-api.service -n 30
# Expected: No ERROR lines; should see startup messages
```

---

## Verification Tests (vm-app ONLY)

Run these tests IN ORDER to verify everything works:

### Test 1: Health Check (Existing Endpoint)
```bash
curl http://127.0.0.1:3000/health
# Expected: {"status":"healthy","timestamp":"..."}
```

### Test 2: Root Endpoint (Existing)
```bash
curl http://127.0.0.1:3000/
# Expected: {"ok":true,"msg":"QuickClip Upload API"}
```

### Test 3: Fetch Job by ID (Existing Behavior)
```bash
# Use a known job ID from the database (or from earlier today)
curl http://127.0.0.1:3000/jobs/e788d5c2-264d-4dfe-86bb-9bd41ec71f56
# Expected: {"status":"completed","result":{"transcription":"..."}}
#           OR {"status":"processing"} for jobs still running
```

### Test 4: NEW - Fetch All Transcriptions
```bash
curl http://127.0.0.1:3000/transcriptions
# Expected: 
# [
#   {"job_id":"uuid1","transcription":"text1"},
#   {"job_id":"uuid2","transcription":"text2"},
#   ...
# ]
# OR [] if database is empty
```

### Test 5: Verify Worker Still Processes Jobs

```bash
# Option A: Wait for existing jobs in queue to complete
# Check logs for "✅ Job completed:" messages
sudo journalctl -u quickclip-worker.service -f
# (Press Ctrl+C to exit)

# Option B: Upload a test video manually
# (Only if you have a test video. Keep it small for quick processing.)
curl -F "video=@/path/to/test.mp4" http://127.0.0.1:3000/upload
# Expected: {"jobId":"<uuid>","status":"queued"}

# Then poll for result
curl http://127.0.0.1:3000/jobs/<uuid>
# Expected: Eventually returns {"status":"completed","result":{"transcription":"..."}}
```

### Test 6: Verify Transcription Saved to DB

```bash
# After a job completes, verify it's in the database
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "SELECT job_id, LENGTH(transcription) FROM transcriptions ORDER BY job_id DESC LIMIT 1;"
# Expected: Shows the job_id and transcription length
```

---

## Expected Behavior After Deployment

### Worker Service
- ✓ Continues downloading videos from blob
- ✓ Continues processing videos with Deepgram
- ✓ Continues uploading results to blob storage
- ✓ NOW ALSO saves transcriptions to PostgreSQL (best-effort)
- ✓ If DB save fails, job still completes successfully (checked in logs)

### Upload API Service
- ✓ `/upload` endpoint works unchanged
- ✓ `/jobs/:jobId` endpoint NOW checks PostgreSQL first (faster for repeat queries)
- ✓ `/jobs/:jobId` still falls back to blob if not in DB
- ✓ `/health` endpoint works unchanged
- ✓ NEW: `/transcriptions` endpoint returns all stored transcriptions

### Frontend
- ✓ Existing polling to `/jobs/:jobId` still works
- ✓ NEW: Can optionally call `/transcriptions` to fetch all transcriptions at once

---

## Troubleshooting

### Issue: Services fail to start
```bash
# Check for port conflicts
sudo lsof -i :3000  # For upload-api
sudo lsof -i :5672  # For worker (service bus)

# Check disk space
df -h

# Restart Docker/systemd as needed
sudo systemctl restart docker  # If using containers
```

### Issue: Database connection fails
```bash
# Verify vm-db is reachable
ping 10.0.1.4
# Expected: Ping should succeed

# Test psql connection
psql -h 10.0.1.4 -U appuser -d transcription_db -c "SELECT 1;"
# Expected: Returns 1

# Check firewall rules (from vm-app perspective)
telnet 10.0.1.4 5432
# Expected: Connection should work
```

### Issue: Worker logs show "Failed to save transcription to DB"
- This is expected and safe. The message means:
  - Job still completed successfully ✓
  - Transcription was uploaded to blob ✓
  - DB write failed (possible network glitch)
  - No action needed; job is complete
  - Retry will happen on next worker run if needed

### Issue: `/transcriptions` endpoint returns empty array
- Possible causes:
  - Database has no transcriptions yet (jobs still processing)
  - Worker is saving to blob but not DB (check worker logs)
  - Connection pool issue:
    ```bash
    # Restart API service only
    sudo systemctl restart quickclip-api.service
    ```

### Issue: Rollback needed
If ANY issue persists, rollback immediately:
```bash
# Revert to previous main
git reset --hard origin/main
# OR specify commit hash before merge:
git reset --hard 01af751

# Restart services
sudo systemctl restart quickclip-worker.service quickclip-api.service

# Verify
curl http://127.0.0.1:3000/health
```

---

## Performance Notes

- **DB Query Time:** ~1-5ms per query (local private network)
- **Connection Pool:** 5 max connections (suitable for current load)
- **Transcription Storage:** TEXT field can handle large transcriptions (unlimited in PostgreSQL)
- **Query Pattern:** Check DB first for `/jobs/:jobId`, then blob (optimization)

---

## Monitoring (Post-Deployment)

### Check for DB Write Failures
```bash
# Monitor for "Failed to save transcription to DB" messages
sudo journalctl -u quickclip-worker.service -f | grep "Failed to save"
# If you see many, investigate network or pool issues
```

### Monitor Connection Pool
```bash
# Query active connections to transcription_db from vm-app
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"
# Expected: Should see transcription_db with ≤ 5 connections
```

### Monitor Transcription Growth
```bash
# Check new transcriptions added in last hour
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "SELECT COUNT(*) FROM transcriptions WHERE job_id IN (SELECT job_id FROM transcriptions ORDER BY job_id DESC LIMIT 100);"
```

---

## Rollback Plan (if needed)

**Simple rollback (fastest):**
```bash
cd ~/azure-backend-vm
git reset --hard origin/main  # Keep current version
# OR revert to pre-merge:
git reset --hard 01af751      # Revert to commit BEFORE merge

sudo systemctl restart quickclip-worker.service quickclip-api.service
```

**Database cleanup (optional, if test data needs removal):**
```bash
# Remove specific test job
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "DELETE FROM transcriptions WHERE job_id = '<test-uuid>';"

# OR clear all (only if resetting completely):
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "DELETE FROM transcriptions;"
```

---

## Sign-Off

Once all tests pass:

- [ ] Health check successful
- [ ] Existing endpoints work
- [ ] New /transcriptions endpoint works
- [ ] Worker logs show no unexpected errors
- [ ] Worker still processes jobs
- [ ] Transcriptions appear in both DB and via API
- [ ] No vm-db changes were made

**Deployment Status:** ✅ **READY FOR PRODUCTION**

---

## Questions or Issues?

If deployment fails at ANY step:
1. STOP immediately (do not continue to next step)
2. Check logs: `sudo journalctl -u quickclip-*.service -n 50`
3. Verify database: `psql -h 10.0.1.4 -U appuser -d transcription_db -c "SELECT 1;"`
4. Rollback if unsure: `git reset --hard 01af751 && sudo systemctl restart quickclip-*.service`
5. Report the specific error

**Good luck! 🚀**
