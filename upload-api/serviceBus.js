import { ServiceBusClient } from "@azure/service-bus";

const connectionString = process.env.SERVICE_BUS_CONNECTION_STRING;
if (!connectionString) throw new Error("SERVICE_BUS_CONNECTION_STRING not set");

const queueName = process.env.SERVICE_BUS_QUEUE || "video-jobs";
const sbClient = new ServiceBusClient(connectionString);
const sender = sbClient.createSender(queueName);

export async function sendJobMessage(job) {
  const message = {
    body: job,
    contentType: "application/json"
  };
  await sender.sendMessages(message);
  console.log("sent job to service bus:", job.jobId);
}
