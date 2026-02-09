// upload-api/blobResults.js
import { BlobServiceClient } from "@azure/storage-blob";
import crypto from "crypto";

// Ensure crypto is available globally for Azure SDK
if (!globalThis.crypto) {
  globalThis.crypto = crypto.webcrypto || crypto;
}

const connectionString = process.env.STORAGE_CONNECTION_STRING;
if (!connectionString) throw new Error("STORAGE_CONNECTION_STRING not set");

const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
const containerName = "results";

/**
 * Uploads result JSON (you already have this - kept for completeness).
 */
export async function uploadResult(jobId, result) {
  const containerClient = blobServiceClient.getContainerClient(containerName);
  await containerClient.createIfNotExists();
  const blobClient = containerClient.getBlockBlobClient(`${jobId}.json`);
  const data = JSON.stringify(result, null, 2);
  await blobClient.upload(data, Buffer.byteLength(data));
  console.log("Uploaded result for job:", jobId);
}

/**
 * Fetches and returns parsed JSON result for jobId if it exists.
 * Returns null if not found.
 */
export async function getResultIfExists(jobId) {
  const containerClient = blobServiceClient.getContainerClient(containerName);
  const blobClient = containerClient.getBlockBlobClient(`${jobId}.json`);

  const exists = await blobClient.exists();
  if (!exists) return null;

  // downloadToBuffer is convenient for small JSON blobs
  const buffer = await blobClient.downloadToBuffer();
  const text = buffer.toString("utf8");
  try {
    return JSON.parse(text);
  } catch (err) {
    // Return raw text in case parsing fails
    return { raw: text };
  }
}
