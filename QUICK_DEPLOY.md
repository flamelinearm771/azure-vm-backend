# 🎯 Quick Reference: Deploy PostgreSQL + New Endpoint

## Status: READY FOR PRODUCTION ✅

---

## One-Line Summary
**Worker → PostgreSQL** | **API DB-first read** | **NEW: `/transcriptions` endpoint** | **vm-app only**

---

## Deploy Commands (Copy-Paste)

```bash
# SSH to vm-app
ssh <user>@<vm-app-ip>

# Pull and deploy
cd ~/azure-backend-vm
git pull origin main

# Verify (should show 1673e3b on top)
git log --oneline -1

# Restart services
sudo systemctl restart quickclip-worker.service quickclip-api.service

# Test immediately
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/transcriptions
```

---

## What Changed (5 Commits)

```
1673e3b ← NEW endpoint (/transcriptions)
54f1774 ← API checks DB first
edae1cc ← API DB helper
2bfdf9f ← Worker saves to DB
78232f7 ← Worker DB helper
01af751 ← baseline
```

**Files: 4 | Lines: +94 | Deletions: -3**

---

## Verify Deployment (Run These)

```bash
# 1. Services running?
sudo systemctl status quickclip-worker.service | grep active

# 2. DB connected?
psql -h 10.0.1.4 -U appuser -d transcription_db -c "SELECT 1;"

# 3. API responding?
curl http://127.0.0.1:3000/health | jq .status

# 4. NEW endpoint working?
curl http://127.0.0.1:3000/transcriptions | jq 'length'

# 5. Logs clean?
sudo journalctl -u quickclip-worker.service -n 5 | grep -i error || echo "✓ No errors"
sudo journalctl -u quickclip-api.service -n 5 | grep -i error || echo "✓ No errors"
```

---

## Rollback (1 Command)

```bash
cd ~/azure-backend-vm && git reset --hard 01af751 && \
sudo systemctl restart quickclip-worker.service quickclip-api.service
```

---

## New Endpoint Spec

```
GET /transcriptions

Response:
[
  {"job_id": "uuid...", "transcription": "text..."},
  {"job_id": "uuid...", "transcription": "text..."}
]
```

---

## What Did NOT Change

- ✓ vm-db untouched
- ✓ PostgreSQL schema untouched
- ✓ Blob storage unchanged
- ✓ Service Bus unchanged
- ✓ Existing endpoints unchanged

---

## Safety Guarantees

- ✅ DB save is best-effort (worker won't fail)
- ✅ Blob fallback still works if DB is down
- ✅ No breaking changes to existing APIs
- ✅ No authentication added
- ✅ No secrets added to code

---

## Expected Deployment Time

- Pull & verify: **2 min**
- Stop services: **5 sec**
- Start services: **10 sec**
- Smoke tests: **2 min**
- **Total: ~5 min (30 sec downtime)**

---

## Emergency Abort

```bash
git reset --hard 01af751
sudo systemctl restart quickclip-worker.service quickclip-api.service
# Back to previous state
```

---

## Documentation

- **Detailed guide:** [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Summary:** [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)
- **PR details:** [PR_DESCRIPTION.md](PR_DESCRIPTION.md)

---

**Ready? 🚀 Start with `git pull origin main`**
