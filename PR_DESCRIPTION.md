# PR Description: Save Transcriptions to PostgreSQL Database

## Summary
This PR wires the worker and upload-api services to persist transcriptions to PostgreSQL database on vm-db (10.0.1.4), while maintaining all existing blob storage and service bus functionality. The implementation is minimal, safe, and fully reversible.

**Key changes:**
- Added database helper modules with connection pooling
- Worker saves transcriptions to DB after blob upload (best-effort, non-blocking)
- Upload API checks DB first for results, then falls back to blob storage
- No changes to existing blob, service bus, or other unrelated logic
- No secrets committed; all DB credentials use environment variables with safe defaults

## Files Changed
1. **worker/db-vm.js** (new) - Database helper with `saveTranscription()` and `closePool()`
2. **worker/worker-vm.js** - Added import and best-effort DB save after `uploadResult()`
3. **upload-api/db-vm.js** (new) - Database helper with `getTranscription()` and `closePool()`
4. **upload-api/server-vm.js** - Updated `/jobs/:jobId` GET handler to check DB first, fallback to blob

## Design Decisions
- **Non-blocking DB writes**: Worker saves to DB after blob upload completes; DB write failures do not mark the job as failed
- **Fast read path**: API checks DB first (faster than blob), falls back to blob for backward compatibility
- **Idempotent saves**: Using `ON CONFLICT` upsert to handle retries safely
- **Connection pooling**: 5-connection pool to vm-db for efficient resource use
- **SSL support**: DB connections use configurable SSL (default: disabled for private network)

## Environment Variables (Optional)
Add these to `.env` on vm-app if you want to override defaults:
```
DB_HOST=10.0.1.4
DB_PORT=5432
DB_NAME=transcription_db
DB_USER=appuser
DB_PASSWORD=strongpassword
DB_SSL=false
```

## Verification Steps (Required Before Merge)

### 1. Verify dependencies are installed
```bash
cd ~/PH-EG-QuickClip/azure-backend-vm/worker && npm list pg
cd ~/PH-EG-QuickClip/azure-backend-vm/upload-api && npm list pg
```
Expected: Both should show `pg@^8.18.0`

### 2. Test database connectivity from vm-app
```bash
psql -h 10.0.1.4 -U appuser -d transcription_db -c "SELECT version();"
```
Expected: PostgreSQL version output (no error)

### 3. Verify table exists
```bash
psql -h 10.0.1.4 -U appuser -d transcription_db -c "\dt transcriptions;"
```
Expected: Should show `public | transcriptions | table | postgres`

### 4. Restart services on vm-app
```bash
sudo systemctl restart quickclip-worker.service
sudo systemctl restart quickclip-api.service
```

### 5. Check service status
```bash
sudo systemctl status quickclip-worker.service
sudo systemctl status quickclip-api.service
```
Expected: Both should show `active (running)`

### 6. Trigger a test job (option A: direct upload)
From local machine:
```bash
curl -F "video=@/path/to/small-test-video.mp4" \
  http://<vm-app-public-ip>:3000/upload
```
Expected: Returns `{"jobId":"<uuid>","status":"queued"}`

### 7. Wait for processing
Poll the result endpoint every 10 seconds:
```bash
curl http://<vm-app-public-ip>:3000/jobs/<jobId>
```
Expected: Initially `{"status":"processing"}`, then `{"status":"completed","result":{"transcription":"..."}}`

### 8. Verify database row
From vm-app:
```bash
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "SELECT job_id, LENGTH(transcription) as text_length FROM transcriptions ORDER BY job_id DESC LIMIT 5;"
```
Expected: Should show the test jobId with transcription length > 0

### 9. Verify API returns DB result (not blob)
```bash
curl http://<vm-app-public-ip>:3000/jobs/<jobId> | jq .result
```
Expected: `{"transcription":"...full transcription text..."}`

### 10. Check logs for DB save success
From vm-app:
```bash
sudo journalctl -u quickclip-worker.service -n 50 --follow
```
Expected: Should see `💾 Saved transcription to DB: <jobId>` in logs

## Rollback Plan (If Needed)

### Option 1: Quick reversal (revert commits)
```bash
cd ~/PH-EG-QuickClip/azure-backend-vm

# Revert to main
git checkout main
git reset --hard origin/main

# Restart services
sudo systemctl restart quickclip-worker.service
sudo systemctl restart quickclip-api.service
```
This restores previous code and restarts services to pick up changes immediately.

### Option 2: Keep branch, disable DB (if partial issue)
If only reads are problematic, comment out the DB check in upload-api/server-vm.js:
```javascript
// const transcription = await getTranscription(jobId);
// if (transcription) { ... }
```
Or if only writes are problematic, comment out the DB save in worker/worker-vm.js:
```javascript
// await saveTranscription(jobId, result.transcription);
```

### Option 3: Clean up test data
If test data needs to be removed:
```bash
psql -h 10.0.1.4 -U appuser -d transcription_db \
  -c "DELETE FROM transcriptions WHERE job_id = '<test-jobId>';"
```

## Code Review Checklist
- [ ] All 4 commits are present and logical
- [ ] No `.env` or secrets are committed
- [ ] Verification steps 1-10 pass without errors
- [ ] Worker logs show DB save messages
- [ ] API returns transcriptions from DB (verified with curl)
- [ ] Rollback plan was tested (optional but recommended)
- [ ] No other files were modified
- [ ] Blob storage and service bus functionality unchanged

## Additional Notes
- **DB Pool Capacity**: 5 connections should be sufficient for this workload; increase if needed in `db-vm.js` (`max: 5` parameter)
- **SSL**: Connection uses unencrypted TLS by default on private network; set `DB_SSL=true` and provide certificate if needed
- **Monitoring**: Check `sudo journalctl -u quickclip-*.service` for any database connection errors
- **Future Work**: Consider adding a metrics/monitoring layer for DB query times and connection pool usage

## Testing Status
- [x] Code changes reviewed
- [x] Minimal changes (add-only except for handler update)
- [x] No breaking changes to existing APIs
- [ ] Ready for integration testing on vm-app
- [ ] Ready for end-to-end testing with uploaded videos

---

**Ready for code review and verification on staging environment before production deployment.**
