import dotenv from "dotenv";
dotenv.config();

import express from "express";
import multer from "multer";
import fs from "fs/promises";
import crypto from "crypto";
import cors from "cors";

import { uploadVideoToBlob } from "./blobStorage.js"; 
import { sendJobMessage } from "./serviceBus.js";
import { getResultIfExists } from "./blobResults.js";

const app = express();

// CORS configuration
const allowed = (process.env.ALLOWED_ORIGINS || "*").split(",").map(s => s.trim()).filter(Boolean);
app.use(cors({ origin: allowed, credentials: true }));

// JSON body parser
app.use(express.json({ limit: '50mb' }));

const upload = multer({ dest: "uploads/", limits: { fileSize: 5000 * 1024 * 1024 } }); // 5GB

// Health check endpoint for load balancer
app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy", timestamp: new Date().toISOString() });
});

// Upload endpoint
app.post("/upload", upload.single("video"), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: "video required" });

  const jobId = crypto.randomUUID();
  const localPath = `uploads/${jobId}.mp4`;

  try {
    await fs.rename(req.file.path, localPath);
    console.log(`[${jobId}] saved locally ${localPath}`);

    // Upload to blob container 'videos'
    console.log(`[${jobId}] uploading to blob storage...`);
    await uploadVideoToBlob(localPath, `${jobId}.mp4`);
    console.log(`[${jobId}] uploaded to blob storage`);

    // remove local file
    await fs.unlink(localPath).catch(()=>{});

    // send job message with path the worker expects
    await sendJobMessage({
      jobId,
      videoBlob: `videos/${jobId}.mp4`,
      createdAt: new Date().toISOString()
    });

    console.log(`[${jobId}] job message sent to service bus`);

    return res.json({ jobId, status: "queued" });
  } catch (err) {
    console.error("upload failed", err);
    try { await fs.unlink(localPath); } catch(e){}
    return res.status(500).json({ error: String(err) });
  }
});

// GET job result (poll /jobs/:jobId)
app.get("/jobs/:jobId", async (req, res) => {
  const { jobId } = req.params;
  if (!jobId) return res.status(400).json({ error: "jobId required" });

  try {
    const result = await getResultIfExists(jobId);

    if (!result) {
      // Job still processing
      return res.json({ status: "processing" });
    }

    // Return completed result
    return res.json({
      status: "completed",
      result,
    });
  } catch (err) {
    console.error("error fetching job result", err);
    return res.status(500).json({ error: String(err) });
  }
});

// Root endpoint
app.get("/", (req, res) => res.json({ ok: true, msg: "QuickClip Upload API" }));

// Create uploads directory
try {
  await fs.mkdir("uploads", { recursive: true });
} catch (e) {}

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Upload API listening on ${PORT}`);
  console.log(`📍 Health check: http://0.0.0.0:${PORT}/health`);
});
