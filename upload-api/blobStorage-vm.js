import { BlobServiceClient } from "@azure/storage-blob";
import path from "path";
import fs from "fs/promises";

const connectionString = process.env.STORAGE_CONNECTION_STRING;
if (!connectionString) throw new Error("STORAGE_CONNECTION_STRING not set");

const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
const containerName = "videos";

export async function uploadVideoToBlob(localFilePath, blobPath) {
  const name = blobPath.replace(/^videos\//, "");
  const containerClient = blobServiceClient.getContainerClient(containerName);
  await containerClient.createIfNotExists();
  const blockBlobClient = containerClient.getBlockBlobClient(name);

  await blockBlobClient.uploadFile(localFilePath);
  console.log("✅ uploaded blob:", name);
}
