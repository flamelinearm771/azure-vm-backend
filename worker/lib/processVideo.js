import fs from "fs";
import os from "os";
import path from "path";
import util from "util";
import { exec as execCb } from "child_process";
import ffmpegStatic from "ffmpeg-static";

// Load env from parent directory
import dotenv from "dotenv";
import { fileURLToPath } from "url";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(path.dirname(__dirname), ".env");
dotenv.config({ path: envPath });

// Now import Deepgram after env is loaded
import { createClient } from "@deepgram/sdk";

const exec = util.promisify(execCb);

/* ------------------------ ENV VALIDATION ------------------------ */

if (!process.env.DEEPGRAM_API_KEY) {
  throw new Error("DEEPGRAM_API_KEY not set");
}

/* ---------------------- CLIENT INITIALIZATION ------------------- */

const deepgram = createClient(process.env.DEEPGRAM_API_KEY);

/* ------------------------- MAIN FUNCTION ------------------------ */

export async function processVideoFile(videoPath) {
  const tmpDir = os.tmpdir();
  const audioPath = path.join(tmpDir, `audio_${Date.now()}.wav`);

  let transcription = "";

  /* ---------------------- FFMPEG SETUP ---------------------- */

  let ffmpegBinary = "ffmpeg";

  try {
    await exec(`${ffmpegBinary} -version`);
  } catch {
    if (!ffmpegStatic) {
      throw new Error("ffmpeg not available");
    }
    ffmpegBinary = ffmpegStatic;
  }

  /* -------------------- AUDIO EXTRACTION -------------------- */

  try {
    const ffmpegCmd = `"${ffmpegBinary}" -y -i "${videoPath}" -vn -acodec pcm_s16le -ar 16000 -ac 1 "${audioPath}"`;
    console.log("Running ffmpeg:", ffmpegCmd);

    await exec(ffmpegCmd, {
      maxBuffer: 1024 * 1024 * 200,
    });
  } catch (err) {
    throw new Error("ffmpeg failed: " + (err?.stderr || err?.message));
  }

  /* -------------------- DEEPGRAM ASR -------------------- */

  try {
    console.log("Calling Deepgram ASR (nova-2)");

    const audioBuffer = await fs.promises.readFile(audioPath);

    const { result, error } =
      await deepgram.listen.prerecorded.transcribeFile(audioBuffer, {
        model: "nova-2",
        smart_format: true,
        language: "en",
      });

    if (error) throw error;

    transcription =
      result?.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? "";

    console.log("Transcription length:", transcription.length);
  } catch (err) {
    console.error("Deepgram error:", err);
    throw new Error("ASR failed: " + err.message);
  }

  /* ---------------------- CLEANUP ---------------------- */

  await fs.promises.unlink(audioPath).catch(() => {});

  /* ---------------------- RESULT ---------------------- */

  return {
    transcription,
  };
}
