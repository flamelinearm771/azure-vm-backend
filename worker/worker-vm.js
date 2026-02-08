import dotenv from "dotenv";
dotenv.config();

import { startWorker } from "./serviceBusReceiver-vm.js";
import { downloadVideo } from "./blobDownload-vm.js";
import { processVideoFile } from "./lib/processVideo-vm.js";
import { uploadResult } from "./blobResults-vm.js";
import fs from "fs/promises";
import path from "path";

async function handleJob(job) {
  const { jobId, videoBlob } = job;
  console.log("⚙️  Processing job:", jobId);

  try {
    const localPath = await downloadVideo(videoBlob);
    console.log("🎬 Downloaded video:", jobId);

    const result = await processVideoFile(localPath);
    console.log("✨ Processing complete:", jobId);

    await uploadResult(jobId, result);
    console.log("💾 Result uploaded:", jobId);

    // remove local file
    try { await fs.unlink(localPath); } catch(e){}

    console.log("✅ Job completed:", jobId);
  } catch (err) {
    console.error("❌ Job processing failed:", jobId, err.message);
    throw err;
  }
}

console.log("🚀 QuickClip Worker Service Starting...");
startWorker(handleJob);
