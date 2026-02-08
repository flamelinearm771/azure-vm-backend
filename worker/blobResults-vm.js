import { BlobServiceClient } from "@azure/storage-blob";

const connectionString = process.env.STORAGE_CONNECTION_STRING;
if (!connectionString) throw new Error("STORAGE_CONNECTION_STRING not set");

const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
const containerName = "results";

export async function uploadResult(jobId, result) {
  const containerClient = blobServiceClient.getContainerClient(containerName);
  await containerClient.createIfNotExists();
  const blobClient = containerClient.getBlockBlobClient(`${jobId}.json`);
  const data = JSON.stringify(result, null, 2);
  await blobClient.upload(data, Buffer.byteLength(data));
  console.log("✅ Uploaded result for job:", jobId);
}
