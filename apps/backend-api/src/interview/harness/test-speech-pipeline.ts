import { writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { ConfigService } from '@nestjs/config';
import { GeminiLlmService } from '../services/gemini-llm.service';
import { GroqSttService } from '../services/groq-stt.service';
import { GroqTtsService } from '../services/groq-tts.service';
import { InterviewPromptService } from '../services/interview-prompt.service';
import { InterviewEvaluationValidator } from '../services/interview-evaluation-validator.service';
import { loadLocalCompanyContext } from './local-company-context.loader';

async function testSpeechPipeline() {
  console.log('=== END-TO-END SPEECH PIPELINE TEST (Whisper STT -> Gemini LLM -> Orpheus TTS) ===\n');

  const configService = new ConfigService(process.env);
  const provider = configService.get<string>('INTERVIEW_TTS_PROVIDER', 'groq');
  const ttsModel = configService.get<string>('INTERVIEW_GROQ_TTS_MODEL', 'canopylabs/orpheus-v1-english');

  console.log(`[CONFIG CHECK]`);
  console.log(`- TTS Provider: ${provider}`);
  console.log(`- Orpheus TTS Model: ${ttsModel}`);
  console.log(`- Gemini Model: ${configService.get('INTERVIEW_GEMINI_MODEL', 'gemini-3.5-flash')}`);
  console.log(`- Whisper STT Model: ${configService.get('INTERVIEW_STT_MODEL', 'whisper-large-v3-turbo')}\n`);

  // 1. Initialize services
  const promptService = new InterviewPromptService(configService);
  const evaluationValidator = new InterviewEvaluationValidator();
  const geminiLlm = new GeminiLlmService(configService, promptService, evaluationValidator);
  const groqStt = new GroqSttService(configService);
  const groqTts = new GroqTtsService(configService);

  // 2. Test Orpheus TTS directly
  console.log('--- Step 1: Testing Orpheus TTS Synthesis ---');
  const sampleQuestion = 'Halo! Selamat datang di simulasi wawancara YUDHA. Silakan perkenalkan diri Anda dan ceritakan pengalaman terbaik Anda.';
  console.log(`Synthesizing text: "${sampleQuestion}"`);

  const ttsStart = Date.now();
  const ttsResult = await groqTts.synthesize({ text: sampleQuestion, language: 'id' });
  const ttsLatency = Date.now() - ttsStart;

  console.log(`TTS Synthesis Successful!`);
  console.log(`- Provider: ${ttsResult.provider}`);
  console.log(`- Content-Type: ${ttsResult.contentType}`);
  console.log(`- Audio Size: ${ttsResult.audio.length} bytes`);
  console.log(`- Latency: ${ttsLatency}ms`);

  const outputAudioPath = resolve(process.cwd(), 'orpheus-test-output.wav');
  writeFileSync(outputAudioPath, ttsResult.audio);
  console.log(`🔊 Saved output audio file to: ${outputAudioPath}\n`);

  // 3. Test STT & Gemini LLM (auto-uses generated audio or user provided audio)
  const inputAudioPath = (process.argv[2] && existsSync(process.argv[2])) 
    ? process.argv[2] 
    : outputAudioPath;

  console.log(`--- Step 2: Testing Whisper STT with audio ${inputAudioPath} ---`);
  const audioBuffer = require('fs').readFileSync(inputAudioPath);
  const sttResult = await groqStt.transcribe({
    audio: audioBuffer,
    fileName: 'sample.wav',
    mimeType: 'audio/wav',
  });
  console.log(`✅ STT Transcription: "${sttResult.text}"`);

  console.log('\n--- Step 3: Testing Gemini LLM Evaluation ---');
  const loadedContext = await loadLocalCompanyContext('bank-mandiri');
  const llmInput = {
    companyContext: loadedContext.snapshot,
    targetRole: loadedContext.defaultTargetRole,
    mode: 'realistic',
    language: 'Bahasa Indonesia',
    rollingSummary: '',
    recentTurns: [],
    latestQuestion: sampleQuestion,
    latestAnswer: sttResult.text,
  };
  const evalResult = await geminiLlm.evaluateAnswer(llmInput);
  console.log(`✅ Gemini LLM Next Question: "${evalResult.nextQuestion}"`);

  console.log('\n--- Step 4: Synthesizing Gemini Next Question via Orpheus TTS ---');
  const nextAudioResult = await groqTts.synthesize({ text: evalResult.nextQuestion, language: 'id' });
  const nextAudioPath = resolve(process.cwd(), 'orpheus-next-question.wav');
  writeFileSync(nextAudioPath, nextAudioResult.audio);
  console.log(`🔊 Saved next question audio to: ${nextAudioPath}`);

  console.log('\n=== E2E SPEECH PIPELINE TEST PASSED ===');
}

testSpeechPipeline().catch((err) => {
  console.error(' Speech Pipeline Test Failed:', err);
  process.exit(1);
});
