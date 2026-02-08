import { BlobServiceClient } from "@azure/storage-blob";
import path from "path";
import os from "os";

const connectionString = process.env.STORAGE_CONNECTION_STRING;
if (!connectionString) throw new Error("STORAGE_CONNECTION_STRING not set");

const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
const containerName = "videos";

export async function downloadVideo(videoBlobPath) {
  const name = videoBlobPath.replace(/^videos\//, "");
  const containerClient = blobServiceClient.getContainerClient(containerName);
  const blobClient = containerClient.getBlobClient(name);

  const localPath = path.join(os.tmpdir(), name);
  await blobClient.downloadToFile(localPath);
  console.log("📥 Downloaded video to:", localPath);
  return localPath;
}
