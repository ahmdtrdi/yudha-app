import { randomUUID } from 'node:crypto';
import { stdin as input, stdout as output } from 'node:process';
import { createInterface } from 'node:readline/promises';
import type { Interface as ReadlineInterface } from 'node:readline/promises';
import { ConfigService } from '@nestjs/config';
import {
  CompanyContextSnapshot,
  InterviewEvaluation,
  InterviewLlmInput,
  InterviewTurn,
} from '../interview.types';
import { GeminiLlmService } from '../services/gemini-llm.service';
import { GroqLlmService } from '../services/groq-llm.service';
import { FallbackLlmService } from '../services/fallback-llm.service';
import { InterviewEvaluationValidator } from '../services/interview-evaluation-validator.service';
import { InterviewPromptService } from '../services/interview-prompt.service';
import { InterviewSummaryService } from '../services/interview-summary.service';
import {
  listLocalCompanies,
  loadLocalCompanyContext,
  LoadedLocalCompanyContext,
} from './local-company-context.loader';

type HarnessMode = 'realistic' | 'coaching';

interface HarnessOptions {
  mode: HarnessMode;
  maxTurns: number;
  showPrompt: boolean;
  dryRun: boolean;
  companyId?: string;
  targetRole?: string;
  candidateName?: string;
}

async function main(): Promise<void> {
  const configService = new ConfigService(process.env);
  const options = parseOptions(configService);
  const promptService = new InterviewPromptService(configService);
  const summaryService = new InterviewSummaryService();
  const readline = options.dryRun
    ? undefined
    : createInterface({ input, output });

  try {
    const companyContext = await resolveCompanyContext(options, readline);
    const targetRole = options.targetRole ?? companyContext.defaultTargetRole;
    const candidateName =
      options.candidateName ||
      (options.dryRun ? 'Rudi' : (await readline?.question('\nMasukkan nama Anda (default: Rudi): '))?.trim() || 'Rudi');
    const openingQuestion = buildOpeningQuestion(
      companyContext.snapshot.companyName,
      targetRole,
      candidateName,
    );

    printHarnessHeader(options, companyContext, targetRole, candidateName, openingQuestion);

    if (options.dryRun) {
      printPromptPreview(
        promptService,
        options,
        companyContext.snapshot,
        targetRole,
        openingQuestion,
      );
      return;
    }

    if (!readline) {
      throw new Error('Interactive input is unavailable.');
    }

    const llmProvider = (
      configService.get<string>('INTERVIEW_LLM_PROVIDER', 'gemini')
    ).toLowerCase();
    const evaluationValidator = new InterviewEvaluationValidator();
    const geminiService = new GeminiLlmService(configService, promptService, evaluationValidator);
    const groqService = new GroqLlmService(configService, promptService, evaluationValidator);
    const isGroqPrimary = llmProvider === 'groq';
    const llmService = new FallbackLlmService(
      isGroqPrimary ? groqService : geminiService,
      isGroqPrimary ? geminiService : groqService,
      isGroqPrimary ? 'groq' : 'gemini',
      isGroqPrimary ? 'gemini' : 'groq',
    );
    const turns: InterviewTurn[] = [createTurn('question', openingQuestion)];
    const evaluations: InterviewEvaluation[] = [];
    let rollingSummary = '';

    for (let index = 0; index < options.maxTurns; index += 1) {
      const latestQuestion = turns.at(-1)?.content ?? openingQuestion;
      const answer = (await readline.question('\nJawaban kamu: ')).trim();

      if (answer === ':quit') {
        break;
      }

      if (!answer) {
        console.log('Jawaban kosong. Isi jawaban atau ketik :quit.');
        index -= 1;
        continue;
      }

      const answerTurn = createTurn('answer', answer);
      const llmInput = buildLlmInput(
        options,
        companyContext.snapshot,
        targetRole,
        turns,
        rollingSummary,
        latestQuestion,
        answer,
      );

      if (options.showPrompt) {
        printMessages(promptService.buildEvaluationMessages(llmInput));
      }

      const evalStart = Date.now();
      const evaluation = await llmService.evaluateAnswer(llmInput);
      const evalLatency = Date.now() - evalStart;
      const metrics = (evaluation as any)._metrics;
      const promptTokens = metrics?.promptTokens ?? 'N/A';
      const outputTokens = metrics?.completionTokens ?? 'N/A';
      const totalTokens = metrics?.totalTokens ?? 'N/A';
      const modelName = metrics?.model ?? metrics?.provider ?? 'unknown';

      console.log(
        `\n📊 [PERFORMANCE MONITOR] Turn ${index + 1} | Latency: ${evalLatency}ms | LLM: ${modelName} | Tokens -> Prompt: ${promptTokens}, Output: ${outputTokens}, Total: ${totalTokens}`,
      );

      evaluations.push(evaluation);
      turns.push(answerTurn);
      rollingSummary = summaryService.appendRollingSummary(
        rollingSummary,
        evaluation,
      );

      if (options.mode === 'coaching') {
        printEvaluation(evaluation);
      }

      if (evaluation.shouldEndSession || index === options.maxTurns - 1) {
        break;
      }

      turns.push(createTurn('question', evaluation.nextQuestion));
      console.log(`\nInterviewer: ${evaluation.nextQuestion}`);
    }

    if (evaluations.length === 0) {
      console.log('\nSesi selesai tanpa evaluasi.');
      return;
    }

    console.log('\n=== FINAL SUMMARY ===');
    console.log(
      JSON.stringify(summaryService.buildFinalSummary(evaluations), null, 2),
    );
  } finally {
    readline?.close();
  }
}

function parseOptions(configService: ConfigService): HarnessOptions {
  const modeValue = getArgumentValue('--mode') ?? 'realistic';
  if (modeValue !== 'realistic' && modeValue !== 'coaching') {
    throw new Error('--mode must be realistic or coaching.');
  }

  const maxTurnsValue = Number(
    getArgumentValue('--turns') ??
      configService.get<string>('INTERVIEW_MAX_TURNS', '5'),
  );
  if (!Number.isInteger(maxTurnsValue) || maxTurnsValue <= 0) {
    throw new Error('--turns must be a positive integer.');
  }

  return {
    mode: modeValue,
    maxTurns: maxTurnsValue,
    showPrompt: process.argv.includes('--show-prompt'),
    dryRun: process.argv.includes('--dry-run'),
    companyId: getArgumentValue('--company'),
    targetRole: getArgumentValue('--role'),
    candidateName: getArgumentValue('--name'),
  };
}

function getArgumentValue(name: string): string | undefined {
  const prefix = `${name}=`;
  return process.argv
    .find((argument) => argument.startsWith(prefix))
    ?.slice(prefix.length);
}

function buildLlmInput(
  options: HarnessOptions,
  companyContext: CompanyContextSnapshot,
  targetRole: string,
  turns: InterviewTurn[],
  rollingSummary: string,
  latestQuestion: string,
  latestAnswer: string,
): InterviewLlmInput {
  return {
    companyContext,
    targetRole,
    mode: options.mode,
    language: 'Bahasa Indonesia',
    rollingSummary,
    recentTurns: turns.slice(-6),
    latestQuestion,
    latestAnswer,
  };
}

function createTurn(
  role: InterviewTurn['role'],
  content: string,
): InterviewTurn {
  return {
    id: randomUUID(),
    sessionId: 'local-harness',
    role,
    content,
    idempotencyKey: null,
    parentTurnId: null,
    processingStatus: role === 'answer' ? 'completed' : null,
    evaluation: null,
    createdAt: new Date().toISOString(),
  };
}

function buildOpeningQuestion(
  companyName: string,
  targetRole: string,
  candidateName?: string,
): string {
  const greeting = candidateName ? `Halo ${candidateName}! ` : 'Halo! ';
  return [
    `${greeting}Selamat datang di simulasi wawancara ${companyName}.`,
    `Saya adalah AI Interviewer Anda untuk posisi ${targetRole}.`,
    `Senang bisa berdiskusi dengan Anda hari ini. Sebagai permulaan, silakan perkenalkan diri Anda dan jelaskan latar belakang serta motivasi Anda melamar posisi ini.`,
  ].join(' ');
}

function printHarnessHeader(
  options: HarnessOptions,
  companyContext: LoadedLocalCompanyContext,
  targetRole: string,
  candidateName: string,
  openingQuestion: string,
): void {
  console.log('=== LOCAL INTERVIEW HARNESS ===');
  console.log(`Kandidat: ${candidateName}`);
  console.log(`Mode: ${options.mode}`);
  console.log(`Turns: ${options.maxTurns}`);
  console.log(`Company: ${companyContext.snapshot.companyName}`);
  console.log(`Target role: ${targetRole}`);
  console.log('Ketik :quit untuk menghentikan sesi.');
  console.log(`\nInterviewer: ${openingQuestion}`);
}

function printPromptPreview(
  promptService: InterviewPromptService,
  options: HarnessOptions,
  companyContext: CompanyContextSnapshot,
  targetRole: string,
  openingQuestion: string,
): void {
  console.log('\n=== DRY RUN PROMPT PREVIEW ===');
  printMessages(
    promptService.buildEvaluationMessages(
      buildLlmInput(
        options,
        companyContext,
        targetRole,
        [createTurn('question', openingQuestion)],
        '',
        openingQuestion,
        'Nama saya Rani. Saya mahasiswa semester akhir Teknik Informatika dan aktif mengikuti kompetisi analisis bisnis.',
      ),
    ),
  );
}

async function resolveCompanyContext(
  options: HarnessOptions,
  readline?: ReadlineInterface,
): Promise<LoadedLocalCompanyContext> {
  if (options.companyId) {
    return loadLocalCompanyContext(options.companyId);
  }

  const companies = await listLocalCompanies();
  if (options.dryRun) {
    return loadLocalCompanyContext(companies[0].id);
  }

  if (!readline) {
    throw new Error('Interactive input is unavailable.');
  }

  console.log('Pilih perusahaan untuk simulasi:');
  for (const [index, company] of companies.entries()) {
    console.log(`${index + 1}. ${company.name}`);
  }

  const answer = (await readline.question('Pilihan [1-3]: ')).trim();
  const selectedCompany = companies[Number(answer) - 1];
  if (!selectedCompany) {
    throw new Error('Pilihan perusahaan tidak valid.');
  }

  return loadLocalCompanyContext(selectedCompany.id);
}

function printMessages(
  messages: ReturnType<InterviewPromptService['buildEvaluationMessages']>,
): void {
  console.log('\n=== PROMPT MESSAGES ===');
  for (const message of messages) {
    console.log(`\n[${message.role.toUpperCase()}]\n${message.content}`);
  }
}

function printEvaluation(evaluation: InterviewEvaluation): void {
  console.log('\n=== COACHING FEEDBACK ===');
  console.log(JSON.stringify(evaluation, null, 2));
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
