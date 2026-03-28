export const VOICE_OVERLAY_HTML = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <style>
      :root {
        color-scheme: light;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
      }
      html, body {
        margin: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: transparent;
      }
      body {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      #capsule {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 7px 10px;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.9);
        border: 1px solid rgba(255, 255, 255, 0.72);
        box-shadow: 0 14px 28px rgba(15, 23, 42, 0.18);
        backdrop-filter: blur(18px);
        -webkit-backdrop-filter: blur(18px);
      }
      body[data-state='idle'] #capsule {
        opacity: 0;
      }
      body[data-state='recording'] #capsule,
      body[data-state='transcribing'] #capsule,
      body[data-state='success'] #capsule,
      body[data-state='error'] #capsule {
        opacity: 1;
      }
      #dot {
        width: 7px;
        height: 7px;
        border-radius: 999px;
        background: #ef4444;
        flex: 0 0 auto;
      }
      #indicator {
        width: 18px;
        height: 14px;
        position: relative;
        display: inline-flex;
        align-items: flex-end;
        justify-content: center;
      }
      body[data-state='recording'] #indicator {
        gap: 2px;
      }
      body[data-state='recording'] #indicator span {
        width: 3px;
        border-radius: 999px;
        background: #ef4444;
        animation: voice-bars 0.72s ease-in-out infinite;
        transform-origin: bottom center;
      }
      body[data-state='recording'] #indicator span:nth-child(2) {
        animation-delay: 0.12s;
      }
      body[data-state='recording'] #indicator span:nth-child(3) {
        animation-delay: 0.24s;
      }
      body[data-state='recording'] #indicator span:nth-child(4) {
        animation-delay: 0.36s;
      }
      body[data-state='transcribing'] #dot {
        background: #f59e0b;
      }
      body[data-state='transcribing'] #indicator {
        gap: 3px;
        align-items: center;
      }
      body[data-state='transcribing'] #indicator span {
        width: 4px;
        height: 4px;
        border-radius: 999px;
        background: rgba(245, 158, 11, 0.4);
        animation: voice-dots 0.88s ease-in-out infinite;
      }
      body[data-state='transcribing'] #indicator span:nth-child(2) {
        animation-delay: 0.16s;
      }
      body[data-state='transcribing'] #indicator span:nth-child(3) {
        animation-delay: 0.32s;
      }
      body[data-state='transcribing'] #indicator span:nth-child(4) {
        display: none;
      }
      body[data-state='success'] #dot {
        background: #16a34a;
      }
      body[data-state='success'] #indicator {
        align-items: center;
        justify-content: center;
      }
      body[data-state='success'] #indicator span {
        width: 9px;
        height: 5px;
        border-left: 2px solid #16a34a;
        border-bottom: 2px solid #16a34a;
        transform: rotate(-45deg);
      }
      body[data-state='success'] #indicator span:nth-child(n + 2) {
        display: none;
      }
      body[data-state='error'] #dot {
        background: #dc2626;
      }
      body[data-state='error'] #indicator {
        align-items: center;
        justify-content: center;
      }
      body[data-state='error'] #indicator span {
        position: absolute;
        width: 10px;
        height: 2px;
        border-radius: 999px;
        background: #dc2626;
      }
      body[data-state='error'] #indicator span:nth-child(1) {
        transform: rotate(45deg);
      }
      body[data-state='error'] #indicator span:nth-child(2) {
        transform: rotate(-45deg);
      }
      body[data-state='error'] #indicator span:nth-child(n + 3) {
        display: none;
      }
      @keyframes voice-bars {
        0%, 100% { height: 5px; opacity: 0.45; }
        50% { height: 13px; opacity: 1; }
      }
      @keyframes voice-dots {
        0%, 100% { opacity: 0.25; transform: scale(0.9); }
        50% { opacity: 1; transform: scale(1.1); }
      }
    </style>
  </head>
  <body data-state="idle">
    <div id="capsule">
      <div id="dot"></div>
      <div id="indicator">
        <span style="height: 5px"></span>
        <span style="height: 9px"></span>
        <span style="height: 12px"></span>
        <span style="height: 7px"></span>
      </div>
    </div>
    <script>
      (() => {
        const state = {
          stream: null,
          recorder: null,
          recorderChunks: [],
          chunkCount: 0,
          startTime: 0,
        };

        const toMono = (buffer) => {
          if (buffer.numberOfChannels === 1) {
            return new Float32Array(buffer.getChannelData(0));
          }
          const left = buffer.getChannelData(0);
          const right = buffer.getChannelData(1);
          const merged = new Float32Array(buffer.length);
          for (let index = 0; index < buffer.length; index += 1) {
            merged[index] = (left[index] + right[index]) / 2;
          }
          return merged;
        };

        const resampleTo16k = (samples, sourceRate) => {
          if (!samples.length) {
            return new Float32Array();
          }
          if (sourceRate === 16000) {
            return samples;
          }
          const targetLength = Math.max(1, Math.round(samples.length * 16000 / sourceRate));
          const result = new Float32Array(targetLength);
          const ratio = (samples.length - 1) / Math.max(1, targetLength - 1);
          for (let index = 0; index < targetLength; index += 1) {
            const sourceIndex = index * ratio;
            const lowerIndex = Math.floor(sourceIndex);
            const upperIndex = Math.min(samples.length - 1, lowerIndex + 1);
            const weight = sourceIndex - lowerIndex;
            result[index] = samples[lowerIndex] * (1 - weight) + samples[upperIndex] * weight;
          }
          return result;
        };

        const floatToPcm16Base64 = (samples) => {
          const pcm = new Int16Array(samples.length);
          for (let index = 0; index < samples.length; index += 1) {
            const value = Math.max(-1, Math.min(1, samples[index]));
            pcm[index] = value < 0 ? value * 0x8000 : value * 0x7fff;
          }
          const bytes = new Uint8Array(pcm.buffer);
          let binary = "";
          const chunkSize = 0x8000;
          for (let offset = 0; offset < bytes.length; offset += chunkSize) {
            binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
          }
          return btoa(binary);
        };

        const decodeRecordedAudio = async (chunks, mimeType) => {
          if (!chunks.length) {
            return {
              samples: new Float32Array(),
              sampleRate: 16000,
            };
          }

          const blob = new Blob(chunks, { type: mimeType || "audio/webm" });
          const arrayBuffer = await blob.arrayBuffer();
          const context = new AudioContext();

          try {
            const audioBuffer = await context.decodeAudioData(arrayBuffer.slice(0));
            return {
              samples: toMono(audioBuffer),
              sampleRate: audioBuffer.sampleRate,
            };
          } finally {
            if (context.state !== "closed") {
              await context.close();
            }
          }
        };

        const teardown = async () => {
          try {
            if (state.recorder && state.recorder.state !== "inactive") {
              await new Promise((resolve) => {
                state.recorder.addEventListener("stop", () => resolve(), { once: true });
                try {
                  state.recorder.stop();
                } catch {
                  resolve();
                }
              });
            }
            state.stream?.getTracks().forEach((track) => track.stop());
          } finally {
            state.stream = null;
            state.recorder = null;
            state.recorderChunks = [];
            state.chunkCount = 0;
          }
        };

        window.voiceVibeOverlaySetState = (nextState) => {
          document.body.dataset.state = nextState;
        };

        window.voiceVibeOverlayStartRecording = async () => {
          await teardown();
          state.recorderChunks = [];
          state.chunkCount = 0;
          state.startTime = Date.now();

          const stream = await navigator.mediaDevices.getUserMedia({
            audio: {
              channelCount: 1,
              echoCancellation: true,
              noiseSuppression: true,
              autoGainControl: true,
            },
            video: false,
          });

          const preferredMimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
            ? "audio/webm;codecs=opus"
            : "audio/webm";
          const recorder = new MediaRecorder(
            stream,
            preferredMimeType ? { mimeType: preferredMimeType } : undefined
          );
          recorder.addEventListener("dataavailable", (event) => {
            if (event.data && event.data.size > 0) {
              state.recorderChunks.push(event.data);
              state.chunkCount += 1;
            }
          });
          recorder.start(250);
          state.stream = stream;
          state.recorder = recorder;
          window.voiceVibeOverlaySetState("recording");
          return true;
        };

        window.voiceVibeOverlayStopRecording = async () => {
          if (!state.recorder) {
            return { pcmBase64: "", durationMs: 0, chunkCount: 0 };
          }

          const recorder = state.recorder;
          const recordedChunks = await new Promise((resolve, reject) => {
            recorder.addEventListener("stop", () => resolve([...state.recorderChunks]), { once: true });
            recorder.addEventListener("error", () => reject(new Error("MediaRecorder failed to capture audio.")), {
              once: true,
            });

            if (recorder.state === "inactive") {
              resolve([...state.recorderChunks]);
              return;
            }

            recorder.stop();
          });
          const decoded = await decodeRecordedAudio(recordedChunks, recorder.mimeType);
          const resampled = resampleTo16k(decoded.samples, decoded.sampleRate);
          const pcmBase64 = floatToPcm16Base64(resampled);
          const durationMs = Math.max(0, Date.now() - state.startTime);
          const chunkCount = state.chunkCount;
          await teardown();
          return { pcmBase64, durationMs, chunkCount };
        };

        window.voiceVibeOverlayCancelRecording = async () => {
          await teardown();
          return true;
        };
      })();
    </script>
  </body>
</html>`;
