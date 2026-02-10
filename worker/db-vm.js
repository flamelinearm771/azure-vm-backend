// worker/db-vm.js
import pkg from "pg";
const { Pool } = pkg;

const pool = new Pool({
  host: process.env.DB_HOST || "10.0.1.4",
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || "transcription_db",
  user: process.env.DB_USER || "appuser",
  password: process.env.DB_PASSWORD || "strongpassword",
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
  max: 5,
});

export async function saveTranscription(jobId, transcription) {
  if (!jobId) throw new Error("jobId required");
  const sql = `
    INSERT INTO transcriptions (job_id, transcription)
    VALUES ($1::uuid, $2)
    ON CONFLICT (job_id) DO UPDATE
      SET transcription = EXCLUDED.transcription
  `;
  await pool.query(sql, [jobId, transcription]);
}

export async function closePool() {
  await pool.end();
}
