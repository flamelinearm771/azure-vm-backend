import fs from "fs";
import os from "os";
import path from "path";
import util from "util";
import { exec as execCb } from "child_process";
import ffmpegStatic from "ffmpeg-static";
import { createClient } from "@deepgram/sdk";
import { InferenceClient } from "@huggingface/inference";

const exec = util.promisify(execCb);

/* ------------------------ ENV VALIDATION ------------------------ */

if (!process.env.DEEPGRAM_API_KEY) {
  throw new Error("DEEPGRAM_API_KEY not set");
}

if (!process.env.HF_TOKEN) {
  throw new Error("HF_TOKEN not set");
}

/* ---------------------- CLIENT INITIALIZATION ------------------- */

const deepgram = createClient(process.env.DEEPGRAM_API_KEY);
const hf = new InferenceClient(process.env.HF_TOKEN);

/* ------------------------- MAIN FUNCTION ------------------------ */

export async function processVideoFile(videoPath) {
  const tmpDir = os.tmpdir();
  const audioPath = path.join(tmpDir, `audio_${Date.now()}.wav`);

  let transcription = "";
  let summary = "";

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

  /* -------------------- HF SUMMARIZATION -------------------- */

  try {
    if (transcription.trim().length === 0) {
      summary = "No transcription available to summarize.";
    } else {
      const prompt = `
Summarize the transcript below into a concise technical summary.
Focus on key points and omit filler.

Transcript:
${transcription}
`;

      const response = await hf.chatCompletion({
        model: "NousResearch/Hermes-3-Llama-3.1-8B",
        messages: [
          {
            role: "user",
            content: prompt,
          },
        ],
        max_tokens: 300,
        temperature: 0.4,
      });

      summary = response?.choices?.[0]?.message?.content ?? "";
    }
  } catch (err) {
    console.error("HuggingFace error:", err);
    summary = `Summary generation failed: ${err.message}`;
  }

  /* ---------------------- CLEANUP ---------------------- */

  await fs.promises.unlink(audioPath).catch(() => {});

  /* ---------------------- RESULT ---------------------- */

  return {
    transcription,
    summary,
  };
}
