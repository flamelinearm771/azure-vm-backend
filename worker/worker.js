import dotenv from "dotenv";
dotenv.config();

import { startWorker } from "./serviceBusReceiver.js";
import { downloadVideo } from "./blobDownload.js";
import { processVideoFile } from "./lib/processVideo.js";
import { uploadResult } from "./blobResults.js";
import fs from "fs/promises";
import path from "path";

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
