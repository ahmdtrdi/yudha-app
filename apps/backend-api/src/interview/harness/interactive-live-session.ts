import { writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { createInterface } from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';
import { ConfigService } from '@nestjs/config';
import { GeminiLlmService } from '../services/gemini-llm.service';
import { GroqSttService } from '../services/groq-stt.service';
import { GroqTtsService } from '../services/groq-tts.service';
import { InterviewPromptService } from '../services/interview-prompt.service';
import { InterviewEvaluationValidator } from '../services/interview-evaluation-validator.service';
import { InterviewSummaryService } from '../services/interview-summary.service';
import { loadLocalCompanyContext } from './local-company-context.loader';
import { InterviewEvaluation, InterviewTurn } from '../interview.types';

async function runInteractiveLiveSession() {
  console.log('================================================================');
  console.log('      YUDHA AI INTERVIEW — LIVE CONVERSATION SIMULATOR          ');
  console.log('================================================================\n');

  const configService = new ConfigService(process.env);
  const promptService = new InterviewPromptService(configService);
  const summaryService = new InterviewSummaryService();
  const evaluationValidator = new InterviewEvaluationValidator();
  
  const geminiLlm = new GeminiLlmService(configService, promptService, evaluationValidator);
  const groqStt = new GroqSttService(configService);
  const groqTts = new GroqTtsService(configService);

  const companyContext = await loadLocalCompanyContext('bank-mandiri');
  const targetRole = 'Management Trainee';

  const readline = createInterface({ input, output });

  try {
    const candidateName = (await readline.question('Masukkan Nama Anda (default: Budi): ')).trim() || 'Budi';
    
    // 1. Opening Question
    let currentQuestion = `Halo ${candidateName}! Selamat datang di simulasi wawancara ${companyContext.snapshot.companyName} untuk posisi ${targetRole}. Silakan perkenalkan diri Anda dan ceritakan motivasi Anda.`;
    
    console.log(`\n----------------------------------------------------------------`);
    console.log(`🎙️  [INTERVIEWER] ${currentQuestion}`);
    console.log(`----------------------------------------------------------------`);

    // Synthesize opening question voice via Orpheus TTS
    console.log('🔊 Synthesizing interviewer voice via Groq Orpheus TTS...');
    const openingAudio = await groqTts.synthesize({ text: currentQuestion, language: 'id' });
    const openingPath = resolve(process.cwd(), 'turn-0-question.wav');
    writeFileSync(openingPath, openingAudio.audio);
    console.log(`🎧 Audio generated: ${openingPath} (${openingAudio.audio.length} bytes)\n`);

    const turns: InterviewTurn[] = [];
    const evaluations: InterviewEvaluation[] = [];
    let rollingSummary = '';
    const maxTurns = 3;

    for (let turnIndex = 1; turnIndex <= maxTurns; turnIndex++) {
      console.log(`>>> TURN ${turnIndex} of ${maxTurns} <<<`);
      console.log('Pilihan input jawaban:');
      console.log('  1. Ketik teks jawaban langsung');
      console.log('  2. Berikan file audio (.wav / .mp3 / .m4a) untuk di-transcribe oleh Whisper STT');
      
      const inputMode = (await readline.question('\nPilih mode [1/2] (default 1): ')).trim() || '1';
      let candidateAnswerText = '';

      if (inputMode === '2') {
        const audioFilePath = (await readline.question('Path file audio jawaban Anda: ')).trim();
        if (existsSync(audioFilePath)) {
          console.log('🎙️ Transcribing audio via Groq Whisper STT...');
          const audioBuffer = require('fs').readFileSync(audioFilePath);
          const sttResult = await groqStt.transcribe({
            audio: audioBuffer,
            fileName: 'candidate-answer.wav',
            mimeType: 'audio/wav',
          });
          candidateAnswerText = sttResult.text;
          console.log(`✅ Whisper STT Transcript: "${candidateAnswerText}"`);
        } else {
          console.log('❌ File audio tidak ditemukan. Silakan ketik teks jawaban.');
          candidateAnswerText = (await readline.question('Jawaban Anda: ')).trim();
        }
      } else {
        candidateAnswerText = (await readline.question('Jawaban Anda: ')).trim();
      }

      if (!candidateAnswerText || candidateAnswerText === ':quit') {
        console.log('Sesi dihentikan.');
        break;
      }

      // Evaluate turn via Gemini LLM
      console.log('\n🧠 [GEMINI LLM] Menganalisis jawaban kandidat...');
      const evalStart = Date.now();
      const llmInput = {
        companyContext: companyContext.snapshot,
        targetRole,
        mode: 'realistic',
        language: 'Bahasa Indonesia',
        rollingSummary,
        recentTurns: turns.slice(-6),
        latestQuestion: currentQuestion,
        latestAnswer: candidateAnswerText,
      };

      const evaluation = await geminiLlm.evaluateAnswer(llmInput);
      const evalLatency = Date.now() - evalStart;

      evaluations.push(evaluation);
      rollingSummary = summaryService.appendRollingSummary(rollingSummary, evaluation);

      console.log(`📊 [TURN METRICS] Score: ${evaluation.overallScore}/100 | Latency: ${evalLatency}ms`);
      console.log(`💡 Strengths: ${evaluation.strengths.join(', ')}`);
      console.log(`🎯 Improvement: ${evaluation.improvements.join(', ')}`);

      if (evaluation.shouldEndSession || turnIndex === maxTurns) {
        console.log('\n================================================================');
        console.log('                 SESI INTERVIEW SELESAI                         ');
        console.log('================================================================');
        const finalSummary = summaryService.buildFinalSummary(evaluations);
        console.log(`\nFINAL SCORE: ${finalSummary.overallScore}/100`);
        console.log(JSON.stringify(finalSummary, null, 2));
        break;
      }

      // Next Question Synthesis
      currentQuestion = evaluation.nextQuestion;
      console.log(`\n----------------------------------------------------------------`);
      console.log(`🎙️  [INTERVIEWER NEXT QUESTION] ${currentQuestion}`);
      console.log(`----------------------------------------------------------------`);

      console.log('🔊 Synthesizing question audio via Groq Orpheus TTS...');
      const questionAudio = await groqTts.synthesize({ text: currentQuestion, language: 'id' });
      const questionPath = resolve(process.cwd(), `turn-${turnIndex}-question.wav`);
      writeFileSync(questionPath, questionAudio.audio);
      console.log(`🎧 Question Audio Saved: ${questionPath}\n`);
    }
  } finally {
    readline.close();
  }
}

runInteractiveLiveSession().catch((err) => {
  console.error('❌ Live session test error:', err);
  process.exit(1);
});
