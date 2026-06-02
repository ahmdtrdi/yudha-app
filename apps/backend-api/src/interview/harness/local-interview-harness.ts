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
import { GroqLlmService } from '../services/groq-llm.service';
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
    const openingQuestion = buildOpeningQuestion();

    printHarnessHeader(options, companyContext, targetRole, openingQuestion);

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

    const llmService = new GroqLlmService(
      configService,
      promptService,
      new InterviewEvaluationValidator(),
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

      const evaluation = await llmService.evaluateAnswer(llmInput);
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

function buildOpeningQuestion(): string {
  return [
    'Selamat datang. Ceritakan tentang diri Anda terlebih dahulu.',
    'Apa aktivitas atau status Anda saat ini?',
  ].join(' ');
}

function printHarnessHeader(
  options: HarnessOptions,
  companyContext: LoadedLocalCompanyContext,
  targetRole: string,
  openingQuestion: string,
): void {
  console.log('=== LOCAL GROQ INTERVIEW HARNESS ===');
  console.log(`Mode: ${options.mode}`);
  console.log(`Turns: ${options.maxTurns}`);
  console.log(`Company: ${companyContext.snapshot.companyName}`);
  console.log(`Target role: ${targetRole}`);
  console.log(
    `Context source: local JSON fixture (${companyContext.sources.length} official sources), no Supabase`,
  );
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

  const companies = listLocalCompanies();
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
