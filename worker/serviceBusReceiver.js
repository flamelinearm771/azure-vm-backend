import { ServiceBusClient } from "@azure/service-bus";

const connectionString = process.env.SERVICE_BUS_CONNECTION_STRING;
if (!connectionString) throw new Error("SERVICE_BUS_CONNECTION_STRING not set");

const queueName = process.env.SERVICE_BUS_QUEUE || "video-jobs";

export function startWorker(onJob) {
  const client = new ServiceBusClient(connectionString);
  const receiver = client.createReceiver(queueName);

  console.log("Worker listening for messages...");

  receiver.subscribe({
    processMessage: async (message) => {
      try {
        console.log("Received job:", message.body.jobId);
        await onJob(message.body);

        await receiver.completeMessage(message);
        console.log("Message completed:", message.body.jobId);
      } catch (err) {
        console.error("Job processing failed:", err.message);

        // Explicitly abandon so it retries safely
        await receiver.abandonMessage(message);
      }
    },
    processError: async (args) => {
      console.error("Service Bus error:", args.error);
    },
  });
}
