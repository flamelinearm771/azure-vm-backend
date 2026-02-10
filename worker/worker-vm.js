import dotenv from "dotenv";
dotenv.config();

import { startWorker } from "./serviceBusReceiver-vm.js";
import { downloadVideo } from "./blobDownload-vm.js";
import { processVideoFile } from "./lib/processVideo-vm.js";
import { uploadResult } from "./blobResults-vm.js";
import { saveTranscription } from "./db-vm.js";
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

    // save to DB so the app can read it later (best-effort — don't fail the job if DB save fails)
    try {
      if (result?.transcription) {
        await saveTranscription(jobId, result.transcription);
        console.log("💾 Saved transcription to DB:", jobId);
      } else {
        console.log("ℹ️ No transcription text to save for job:", jobId);
      }
    } catch (err) {
      // log and continue — do not crash worker or mark job as failed because of DB write failure
      console.error("❌ Failed to save transcription to DB:", err?.message || err);
    }

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
