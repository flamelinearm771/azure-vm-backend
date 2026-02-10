// upload-api/db-vm.js
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

export async function getTranscription(jobId) {
  if (!jobId) return null;
  const q = "SELECT transcription FROM transcriptions WHERE job_id = $1::uuid";
  const r = await pool.query(q, [jobId]);
  return r.rows[0]?.transcription ?? null;
}

export async function getAllTranscriptions() {
  const q = "SELECT job_id, transcription FROM transcriptions ORDER BY job_id DESC";
  const r = await pool.query(q);
  return r.rows;
}

export async function closePool() {
  await pool.end();
}
