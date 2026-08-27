import { io } from 'socket.io-client';
import { performance } from 'perf_hooks';

function createSamplePcmBuffer(
  durationSeconds = 1,
  sampleRate = 16000,
): Buffer {
  const numSamples = Math.floor(sampleRate * durationSeconds);
  const buffer = Buffer.alloc(numSamples * 2);

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    const sample = Math.floor(Math.sin(2 * Math.PI * 440 * t) * 16000);
    buffer.writeInt16LE(sample, i * 2);
  }

  return buffer;
}

async function runSocketBenchmark() {
  const baseUrl = process.env.TEST_BASE_URL || 'http://localhost:3000';
  const email = process.env.TEST_EMAIL || 'engineer@example.com';
  const password = process.env.TEST_PASSWORD || 'Password123!';

  console.log('⏱️  ================================================');
  console.log('⏱️  AI INTERVIEW LIVE SPEECH LATENCY BENCHMARK TOOL');
  console.log('⏱️  ================================================\n');

  console.log(`🔐 Authenticating (${email})...`);
  let token: string | undefined = process.env.TEST_JWT_TOKEN;

  if (!token) {
    try {
      const loginRes = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const loginData = (await loginRes.json()) as any;
      token = loginData?.session?.access_token;
    } catch {
      token = undefined;
    }
  }

  if (!token) {
    console.log('⚠️ Authentication fallback to dev-token...');
    token = 'dev-token';
  }

  let sessionId: string | undefined = process.env.TEST_SESSION_ID;
  if (!sessionId) {
    try {
      const sessionRes = await fetch(`${baseUrl}/interview/sessions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          companyId: 'pertamina',
          targetRole: 'Management Trainee Financial Analyst',
          mode: 'coaching',
          responseStyle: 'voice',
        }),
      });
      const sessionData = (await sessionRes.json()) as any;
      sessionId = sessionData?.sessionId;
    } catch {
      sessionId = undefined;
    }
  }

  if (!sessionId) {
    sessionId = '00000000-0000-0000-0000-000000000001';
  }

  console.log(
    `🚀 Connecting WebSocket (/interview-speech) for session ${sessionId}...`,
  );
  const socket = io(`${baseUrl}/interview-speech`, {
    auth: { token: `Bearer ${token}` },
  });

  let finishAnswerTime = 0;
  let sttDoneTime = 0;
  let textDoneTime = 0;
  let firstAudioTime = 0;

  socket.on('connect', () => {
    console.log('✅ Socket Connected! ID:', socket.id);
    console.log('📤 Emitting start_session...');
    socket.emit('start_session', { commandId: 'cmd-start-1', sessionId });
  });

  socket.on('session_ready', (data) => {
    console.log('📥 Session Ready:', data);

    const answerId = `answer-${Date.now()}`;
    const samplePcm = createSamplePcmBuffer(1.5, 16000);
    console.log(
      `📤 Simulating press-and-hold PCM16 capture (${samplePcm.length} bytes)...`,
    );
    socket.emit('audio_chunk', {
      commandId: 'cmd-chunk-1',
      sessionId,
      answerId,
      sequence: 0,
      audio: samplePcm.toString('base64'),
      encoding: 'pcm_s16le',
      sampleRateHz: 16000,
      channels: 1,
    });

    setTimeout(() => {
      console.log(
        '⏱️  [TIMESTAMP 0ms] Simulating button release with finish_answer...',
      );
      finishAnswerTime = performance.now();
      socket.emit('finish_answer', {
        commandId: `cmd-finish-${Date.now()}`,
        sessionId,
        answerId,
        finalSequence: 0,
      });
    }, 500);
  });

  socket.on('transcript_final', (data) => {
    sttDoneTime = performance.now();
    const sttLatency = Math.round(sttDoneTime - finishAnswerTime);
    const transcriptLength =
      typeof data.text === 'string' ? data.text.length : 0;
    console.log(
      `📥 [TIMESTAMP +${sttLatency}ms] STT final received (${transcriptLength} characters).`,
    );
  });

  socket.on('audio_chunk_ack', (data) => {
    console.log(`📥 Audio chunk ${data.sequence} acknowledged.`);
  });

  socket.on('question_audio_start', (data) => {
    console.log(
      `📥 Question audio started (${data.provider}, ${data.contentType}, ${data.totalChunks} chunks).`,
    );
  });

  socket.on('evaluation', (data) => {
    console.log(
      '📥 Coaching Evaluation Received:',
      data.evaluation?.overallScore,
    );
  });

  socket.on('question_text', (data) => {
    textDoneTime = performance.now();
    const llmLatency = Math.round(textDoneTime - sttDoneTime);
    console.log(
      `📥 [TIMESTAMP +${Math.round(textDoneTime - finishAnswerTime)}ms] LLM Question Text (+${llmLatency}ms from STT): "${data.text}"`,
    );
  });

  socket.on('question_audio_chunk', (data) => {
    if (firstAudioTime === 0) {
      firstAudioTime = performance.now();
      const firstAudioLatency = Math.round(firstAudioTime - finishAnswerTime);
      console.log(
        `⚡ [TIMESTAMP +${firstAudioLatency}ms] FIRST AUDIO CHUNK RECEIVED (Time-To-First-Byte Audio Playback)!`,
      );
    }
  });

  socket.on('turn_completed', (data) => {
    const totalTime = Math.round(performance.now() - finishAnswerTime);
    const sttMs = Math.round(sttDoneTime - finishAnswerTime);
    const llmMs = Math.round(textDoneTime - sttDoneTime);
    const ttsFirstByteMs = Math.round(firstAudioTime - finishAnswerTime);

    console.log('\n================================================');
    console.log('📊 LIVE SPEECH LATENCY BENCHMARK REPORT');
    console.log('================================================');
    console.log(`1️⃣  STT Whisper Transcription Latency : ${sttMs} ms`);
    console.log(`2️⃣  LLM Gemini Reasoning & Text Latency : ${llmMs} ms`);
    console.log(
      `3️⃣  TTFB Audio Playback (First Chunk)   : ${ttsFirstByteMs} ms  <-- Perceived User Latency!`,
    );
    console.log(`4️⃣  Total End-to-End Turn Completion    : ${totalTime} ms`);
    console.log('================================================');

    if (ttsFirstByteMs <= 1600) {
      console.log(
        '✅ PERCEIVED LATENCY WITHIN PRD TARGET (< 1.6s) — EXCELLENT REAL-TIME PACING!',
      );
    } else {
      console.log(
        '⚠️  LATENCY EXCEEDS 1.6s BUDGET — CHECK PROVIDER RESPONSE TIMES',
      );
    }
    console.log('================================================\n');

    socket.disconnect();
    process.exit(0);
  });

  socket.on('error', (err) => console.error('❌ Received Socket Error:', err));
  socket.on('connect_error', (err) =>
    console.error('❌ Connection Error:', err.message),
  );
}

runSocketBenchmark();
