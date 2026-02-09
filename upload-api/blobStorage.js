import { BlobServiceClient } from "@azure/storage-blob";
import path from "path";
import fs from "fs/promises";
import crypto from "crypto";

// Ensure crypto is available globally for Azure SDK
if (!globalThis.crypto) {
  globalThis.crypto = crypto.webcrypto || crypto;
}

const connectionString = process.env.STORAGE_CONNECTION_STRING;
if (!connectionString) throw new Error("STORAGE_CONNECTION_STRING not set");

const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);

const containerName = "videos";

export async function uploadVideoToBlob(localFilePath, blobPath /* like 'videos/<id>.mp4' */) {
  // blobPath may include container prefix; we accept 'videos/<name>' or just '<name>'
  const name = blobPath.replace(/^videos\//, "");
  const containerClient = blobServiceClient.getContainerClient(containerName);
  await containerClient.createIfNotExists();
  const blockBlobClient = containerClient.getBlockBlobClient(name);

  // uploadFile exists on BlockBlobClient
  await blockBlobClient.uploadFile(localFilePath);
  console.log("uploaded blob:", name);
}
