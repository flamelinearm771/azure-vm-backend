// Setup crypto immediately for Azure SDK compatibility
import crypto from "crypto";
if (!globalThis.crypto) {
  globalThis.crypto = crypto.webcrypto || crypto;
}

import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, ".env");
dotenv.config({ path: envPath });

// Now use dynamic imports for modules that depend on env variables
import fs from "fs/promises";
const { startWorker } = await import("./serviceBusReceiver.js");
const { downloadVideo } = await import("./blobDownload.js");
const { processVideoFile } = await import("./lib/processVideo.js");
const { uploadResult } = await import("./blobResults.js");

async function handleJob(job) {
  const { jobId, videoBlob } = job;
  console.log("Processing job:", jobId);

  try {
    const localPath = await downloadVideo(videoBlob);
    const result = await processVideoFile(localPath);

    await uploadResult(jobId, result);

    // remove local file
    try { await fs.unlink(localPath); } catch(e){}

    console.log("Job completed:", jobId);
  } catch (err) {
    console.error("Job processing failed:", err);
    throw err; // message will be retried by service bus
  }
}

startWorker(handleJob);
