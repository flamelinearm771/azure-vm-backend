// upload-api/server.js
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

// CORS
const allowed = (process.env.ALLOWED_ORIGINS || "").split(",").map(s => s.trim()).filter(Boolean);
// app.use(cors({ origin: allowed.length ? allowed : true, credentials: true }));
app.use(cors({
  origin: "*",
  methods: ["GET", "POST"],
  allowedHeaders: ["Content-Type"],
}));


const upload = multer({ dest: "uploads/" });

// Upload endpoint
app.post("/upload", upload.single("video"), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: "video required" });

  const jobId = crypto.randomUUID();
  const localPath = `uploads/${jobId}.mp4`;

  try {
    await fs.rename(req.file.path, localPath);
    console.log(`[${jobId}] saved locally ${localPath}`);

    // Upload to blob container 'videos'
    // NOTE: uploadVideoToBlob(filePath, blobName) expected. If your function signature differs,
    // change the call accordingly (see comments below).
    console.log(`[${jobId}] uploading to blob storage...`);
    await uploadVideoToBlob(localPath, `${jobId}.mp4`);
    console.log(`[${jobId}] uploaded to blob storage`);

    // remove local file
    await fs.unlink(localPath).catch(()=>{});

    // send job message with path the worker expects
    await sendJobMessage({
      jobId,
      videoBlob: `videos/${jobId}.mp4`, // worker will strip `videos/` or use appropriately
      createdAt: new Date().toISOString()
    });

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
      // Optional: you can return queue info here instead
      return res.json({ status: "processing" });
    }

    // expected shape: { transcription: "...", summary: "...", ... } (worker writes whatever)
    return res.json({
      status: "completed",
      result,
    });
  } catch (err) {
    console.error("error fetching job result", err);
    return res.status(500).json({ error: String(err) });
  }
});

app.get("/", (req, res) => res.json({ ok: true, msg: "upload-api" }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Upload API listening on ${PORT}`));
