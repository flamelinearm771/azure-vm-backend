"use client";

import { useState, useEffect, useRef } from "react";

/*
  Page: VideoProcessor
  - Uploads file to BACKEND_URL + /upload
  - Receives { jobId, status }
  - Polls BACKEND_URL + /jobs/:jobId until completed/failed
  - Shows "stage" tracker: Uploaded -> Queued -> Processing -> Completed/Failed
  - Config: set NEXT_PUBLIC_BACKEND_URL in your .env.local or use default
*/

const DEFAULT_BACKEND =
  typeof window !== "undefined" && window.location.hostname === "localhost"
    ? "http://localhost:3000" // dev backend default
    : "https://upload-api.orangecliff-5027c880.centralindia.azurecontainerapps.io";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || DEFAULT_BACKEND;

export default function VideoProcessor() {
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [jobId, setJobId] = useState(null);
  const [stage, setStage] = useState("idle"); // idle, preparing, uploaded, queued, processing, completed, failed
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [polling, setPolling] = useState(false);
  const [pollRetries, setPollRetries] = useState(0);
  const intervalRef = useRef(null);
  const [progressText, setProgressText] = useState("");
  const [detailedLogs, setDetailedLogs] = useState([]);

  // choose polling interval (ms)
  const POLL_INTERVAL = 2000;
  const MAX_POLL_RETRIES = 30; // ~60 seconds max

  const addLog = (message, type = "info") => {
    const timestamp = new Date().toLocaleTimeString();
    setDetailedLogs((prev) => [...prev, { timestamp, message, type }]);
  };

  const reset = () => {
    setFile(null);
    setUploading(false);
    setJobId(null);
    setStage("idle");
    setResult(null);
    setError(null);
    setProgressText("");
    setDetailedLogs([]);
    setPollRetries(0);
    stopPolling();
  };

  const stopPolling = () => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
    setPolling(false);
  };

  const handleFileChange = (e) => {
    const f = e.target.files?.[0] ?? null;
    setFile(f);
    setError(null);
    setResult(null);
    setStage("idle");
    setProgressText("");
    setDetailedLogs([]);
    setPollRetries(0);
  };

  const startPolling = (job) => {
    setPolling(true);
    setPollRetries(0);
    addLog(`Starting to poll job ${job}`, "info");

    intervalRef.current = setInterval(async () => {
      setPollRetries((prev) => prev + 1);

      try {
        const res = await fetch(`${BACKEND_URL}/jobs/${job}`);
        
        if (!res.ok) {
          addLog(
            `Poll response not OK: ${res.status}. Retrying...`,
            pollRetries > 10 ? "warn" : "info"
          );

          if (pollRetries > MAX_POLL_RETRIES) {
            addLog(`Max retries reached (${MAX_POLL_RETRIES}). Stopping poll.`, "error");
            setError("Job polling timeout - backend may be unresponsive");
            setStage("failed");
            stopPolling();
          }
          return;
        }

        const bodyText = await res.text();
        let j;
        try {
          j = JSON.parse(bodyText);
        } catch {
          addLog(`Invalid JSON response: ${bodyText.substring(0, 100)}...`, "error");
          return;
        }

        // j expected shape: { status: "queued|processing|completed|failed", result: {...}, error: "..." }
        addLog(`Job status: ${j.status}`, "info");

        if (j.status === "queued") {
          setStage("queued");
          setProgressText("Job is queued in Service Bus...");
        } else if (j.status === "processing") {
          setStage("processing");
          setProgressText("Worker is processing the video...");
        } else if (j.status === "completed") {
          setStage("completed");
          setProgressText("✓ Processing completed successfully!");
          setResult(j.result ?? null);
          addLog("Job completed successfully", "success");
          stopPolling();
        } else if (j.status === "failed") {
          setStage("failed");
          setProgressText("✗ Job processing failed");
          const errorMsg = j.error || "Unknown error";
          setError(errorMsg);
          addLog(`Job failed: ${errorMsg}`, "error");
          stopPolling();
        } else {
          setStage(j.status || "queued");
          addLog(`Unknown status: ${j.status}`, "warn");
        }
      } catch (err) {
        addLog(`Poll error: ${err.message}`, "error");
        setProgressText("Error polling job status (see logs below)");
        // keep polling — network hiccups happen
      }
    }, POLL_INTERVAL);
  };

  const handleSubmit = async () => {
    setError(null);
    setResult(null);
    setDetailedLogs([]);

    if (!file) {
      setError("Please select a video file first.");
      addLog("No file selected", "error");
      return;
    }

    setUploading(true);
    setStage("preparing");
    setProgressText("Preparing upload...");
    addLog(`Selected file: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`, "info");

    try {
      const fd = new FormData();
      fd.append("video", file);

      setProgressText("Uploading to backend...");
      addLog(`Uploading to ${BACKEND_URL}/upload`, "info");

      const res = await fetch(`${BACKEND_URL}/upload`, {
        method: "POST",
        body: fd,
      });

      const bodyText = await res.text();
      let body;
      try {
        body = JSON.parse(bodyText);
      } catch {
        throw new Error("Invalid JSON from server: " + bodyText);
      }

      if (!res.ok) {
        const errMsg = body.error || `Upload failed: ${res.status}`;
        throw new Error(errMsg);
      }

      // Expect { jobId, status }
      const id = body.jobId;
      if (!id) throw new Error("No jobId returned from upload API");

      setJobId(id);
      setStage(body.status || "queued");
      setProgressText("✓ File uploaded — starting job queue...");
      addLog(`Job created with ID: ${id}`, "success");
      addLog(`Initial status: ${body.status || "queued"}`, "info");

      // start polling
      startPolling(id);
    } catch (err) {
      console.error("Upload / submit error:", err);
      const errorMsg = err.message || String(err);
      setError(errorMsg);
      addLog(`Upload failed: ${errorMsg}`, "error");
      setStage("failed");
    } finally {
      setUploading(false);
    }
  };

  // cleanup polling when leaving
  useEffect(() => {
    return () => stopPolling();
  }, []);

  // Stage progress component with visual indicators
  const ProgressBar = () => {
    const stages = [
      { id: "uploaded", label: "Uploaded", desc: "File → API" },
      { id: "queued", label: "Queued", desc: "Service Bus" },
      { id: "processing", label: "Processing", desc: "Worker" },
      { id: "completed", label: "Completed", desc: "Ready" },
    ];

    const getStageIndex = () => {
      const stageMap = {
        idle: -1,
        preparing: 0,
        uploaded: 0,
        queued: 1,
        processing: 2,
        completed: 3,
        failed: 3,
      };
      return stageMap[stage] ?? -1;
    };

    const currentIndex = getStageIndex();

    return (
      <div className="space-y-4">
        {/* Main progress bar */}
        <div className="relative">
          <div className="flex justify-between mb-3">
            {stages.map((s, idx) => (
              <div key={s.id} className="text-center">
                <div
                  className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-semibold transition-all"
                  style={{
                    background: idx <= currentIndex ? "#10b981" : "#374151",
                    boxShadow:
                      idx <= currentIndex
                        ? "0 0 12px rgba(16,185,129,0.4)"
                        : "none",
                  }}
                >
                  {idx <= currentIndex ? "✓" : idx + 1}
                </div>
                <p className="text-xs mt-1 font-semibold">{s.label}</p>
                <p className="text-xs text-zinc-400">{s.desc}</p>
              </div>
            ))}
          </div>

          {/* Connecting line */}
          <div className="absolute top-5 left-0 right-0 h-0.5 bg-gradient-to-r from-zinc-600 to-zinc-600">
            <div
              className="h-full bg-gradient-to-r from-green-500 to-emerald-500 transition-all duration-300"
              style={{
                width: `${((currentIndex + 1) / stages.length) * 100}%`,
              }}
            />
          </div>
        </div>

        {/* Status message */}
        <div className="text-center p-3 bg-white/5 rounded-lg border border-white/10">
          <p className="text-sm font-medium text-zinc-100">{progressText}</p>
          {jobId && (
            <p className="text-xs text-zinc-400 mt-1">
              Job ID: <span className="font-mono text-emerald-400">{jobId}</span>
            </p>
          )}
        </div>
      </div>
    );
  };

  // Log viewer component
  const LogViewer = () => {
    return (
      <div className="p-4 bg-zinc-950 border border-zinc-800 rounded-lg max-h-48 overflow-y-auto">
        <p className="text-xs font-semibold text-zinc-400 mb-2">Activity Log</p>
        <div className="space-y-1 font-mono text-xs">
          {detailedLogs.length === 0 ? (
            <p className="text-zinc-600">No logs yet...</p>
          ) : (
            detailedLogs.map((log, idx) => (
              <div
                key={idx}
                className={`
                  ${
                    log.type === "error"
                      ? "text-red-400"
                      : log.type === "success"
                      ? "text-green-400"
                      : log.type === "warn"
                      ? "text-yellow-400"
                      : "text-zinc-300"
                  }
                `}
              >
                <span className="text-zinc-600">[{log.timestamp}]</span> {log.message}
              </div>
            ))
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-purple-900 via-indigo-900 to-black text-white p-6 md:p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-10">
          <h1 className="text-4xl md:text-5xl font-bold mb-2">Video Transcription</h1>
          <p className="text-zinc-300">Upload your video and get AI-powered transcription</p>
        </div>

        {/* Main Card */}
        <div className="bg-black/40 p-8 rounded-2xl border border-white/5 shadow-2xl backdrop-blur">
          {/* File Input Section */}
          <div className="mb-6">
            <label className="block text-sm font-semibold mb-3 text-zinc-100">
              Select Video File
            </label>
            <div className="relative">
              <input
                type="file"
                accept="video/*"
                onChange={handleFileChange}
                disabled={uploading || polling}
                className="block w-full py-3 px-4 rounded-lg bg-white/5 border border-white/10 hover:border-white/20 disabled:opacity-50 cursor-pointer"
              />
              {file && (
                <p className="text-xs mt-2 text-emerald-400 flex items-center gap-2">
                  <span>✓</span>
                  {file.name} ({(file.size / 1024 / 1024).toFixed(2)} MB)
                </p>
              )}
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex gap-3 mb-8">
            <button
              onClick={handleSubmit}
              disabled={uploading || !file || polling}
              className="flex-1 px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 rounded-lg font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {uploading ? "Uploading..." : polling ? "Processing..." : "Upload & Start"}
            </button>
            <button
              onClick={reset}
              className="px-6 py-3 bg-zinc-700 hover:bg-zinc-600 rounded-lg font-semibold transition-all"
            >
              Reset
            </button>
          </div>

          {/* Progress Bar */}
          {jobId || stage !== "idle" ? <ProgressBar /> : null}

          {/* Error Display */}
          {error && (
            <div className="mt-6 p-4 bg-red-900/30 border border-red-600/50 rounded-lg">
              <p className="text-sm font-semibold text-red-300 flex items-center gap-2">
                <span>⚠️</span> Error Details
              </p>
              <p className="text-sm text-red-200 mt-2">{error}</p>
            </div>
          )}

          {/* Logs */}
          {(detailedLogs.length > 0 || uploading || polling) && (
            <div className="mt-6">
              <LogViewer />
            </div>
          )}

          {/* Results */}
          {result && (
            <div className="mt-8 space-y-6">
              <div className="p-6 bg-gradient-to-r from-emerald-900/20 to-teal-900/20 border border-emerald-500/30 rounded-lg">
                <h2 className="text-xl font-semibold mb-3 text-emerald-300 flex items-center gap-2">
                  <span>✓</span> Transcription
                </h2>
                <pre className="whitespace-pre-wrap text-sm text-zinc-100 bg-black/40 p-4 rounded overflow-x-auto">
                  {result.transcription || "No transcription available"}
                </pre>
              </div>

              {result.summary && (
                <div className="p-6 bg-gradient-to-r from-blue-900/20 to-cyan-900/20 border border-blue-500/30 rounded-lg">
                  <h2 className="text-xl font-semibold mb-3 text-blue-300">Summary</h2>
                  <p className="text-sm text-zinc-100 leading-relaxed">
                    {result.summary}
                  </p>
                </div>
              )}

              {result.keyPoints && Array.isArray(result.keyPoints) && (
                <div className="p-6 bg-gradient-to-r from-amber-900/20 to-orange-900/20 border border-amber-500/30 rounded-lg">
                  <h2 className="text-xl font-semibold mb-3 text-amber-300">Key Points</h2>
                  <ul className="text-sm text-zinc-100 space-y-2">
                    {result.keyPoints.map((point, idx) => (
                      <li key={idx} className="flex gap-2">
                        <span className="text-amber-400">•</span>
                        <span>{point}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          )}

          {/* Footer */}
          <div className="mt-8 pt-6 border-t border-white/10 text-xs text-zinc-400 space-y-1">
            <p>
              <span className="font-semibold">Backend:</span> {BACKEND_URL}
            </p>
            <p>
              <span className="font-semibold">Flow:</span> POST /upload → returns jobId →
              GET /jobs/:id polls status
            </p>
            <p className="text-zinc-500">
              Open browser console (F12) for detailed logs and debugging.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
