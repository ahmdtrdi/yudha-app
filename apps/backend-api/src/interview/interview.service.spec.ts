import { ConfigService } from '@nestjs/config';
import { InterviewService } from './interview.service';
import { InterviewSessionRepository } from './repositories/interview-session.repository';
import { CompanyContextService } from './services/company-context.service';
import { InterviewGuardrailService } from './services/interview-guardrail.service';
import { InterviewInputValidator } from './services/interview-input-validator.service';
import { InterviewSummaryService } from './services/interview-summary.service';
import { InterviewLlmClient } from './interview.types';

describe('InterviewService', () => {
  let service: InterviewService;
  let repository: jest.Mocked<InterviewSessionRepository>;
  let companyContextService: jest.Mocked<CompanyContextService>;
  let inputValidator: InterviewInputValidator;
  let summaryService: InterviewSummaryService;
  let llmClient: jest.Mocked<InterviewLlmClient>;
  let configService: ConfigService;

  beforeEach(() => {
    configService = new ConfigService({
      INTERVIEW_MAX_TURNS: '5',
      INTERVIEW_RESPONSE_LANGUAGE: 'id',
    });

    repository = {
      createSession: jest.fn(),
      listOwnedSessions: jest.fn(),
      getOwnedSession: jest.fn(),
      claimAnswer: jest.fn(),
      listTurns: jest.fn(),
      listRecentTurns: jest.fn(),
      addQuestion: jest.fn(),
      completeAnswer: jest.fn(),
      failAnswer: jest.fn(),
      updateSessionSummary: jest.fn(),
      completeSession: jest.fn(),
    } as any;

    companyContextService = {
      resolveSnapshot: jest.fn(),
    } as any;

    inputValidator = new InterviewInputValidator(new InterviewGuardrailService());
    summaryService = new InterviewSummaryService();

    llmClient = {
      evaluateAnswer: jest.fn(),
    };

    service = new InterviewService(
      repository,
      companyContextService,
      inputValidator,
      summaryService,
      configService,
      llmClient,
    );
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('submitAnswerStream', () => {
    const mockUser = 'user-123';
    const mockSessionId = 'session-456';
    const mockInput = {
      idempotencyKey: 'idemp-key-789',
      answer: {
        type: 'text',
        text: 'Saya memiliki pengalaman 2 tahun di bidang analisis keuangan.',
      },
    };

    const mockSession = {
      id: mockSessionId,
      userId: mockUser,
      companyId: 'mandiri',
      targetRole: 'Financial Analyst',
      mode: 'realistic',
      language: 'id',
      responseStyle: 'text',
      status: 'active' as const,
      contextSnapshot: {
        companyId: 'mandiri',
        companyName: 'Bank Mandiri',
        contentVersion: '1.0',
        briefing: 'Mandiri Briefing',
      },
      rollingSummary: '',
      finalSummary: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    let mockResponse: {
      setHeader: jest.Mock;
      write: jest.Mock;
      end: jest.Mock;
      flushHeaders: jest.Mock;
    };

    beforeEach(() => {
      mockResponse = {
        setHeader: jest.fn(),
        write: jest.fn(),
        end: jest.fn(),
        flushHeaders: jest.fn(),
      };
    });

    it('streams events for a new turn submission', async () => {
      repository.getOwnedSession.mockResolvedValue(mockSession);
      repository.claimAnswer.mockResolvedValue({
        isNew: true,
        turn: {
          id: 'turn-ans-1',
          sessionId: mockSessionId,
          role: 'answer',
          content: mockInput.answer.text,
          idempotencyKey: mockInput.idempotencyKey,
          parentTurnId: 'turn-q-0',
          processingStatus: 'pending',
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
      });

      repository.listTurns.mockResolvedValue([
        {
          id: 'turn-q-0',
          sessionId: mockSessionId,
          role: 'question',
          content: 'Ceritakan latar belakang Anda.',
          idempotencyKey: null,
          parentTurnId: null,
          processingStatus: null,
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
        {
          id: 'turn-ans-1',
          sessionId: mockSessionId,
          role: 'answer',
          content: mockInput.answer.text,
          idempotencyKey: mockInput.idempotencyKey,
          parentTurnId: 'turn-q-0',
          processingStatus: 'pending',
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
      ]);
      repository.listRecentTurns.mockResolvedValue([]);

      const mockEvaluation = {
        overallScore: 85,
        dimensions: {
          relevance: 4,
          clarity: 4,
          structure: 4,
          confidence: 4,
          impact: 4,
          authenticity: 4,
        },
        candidateFacts: ['Punya 2 tahun pengalaman'],
        strengths: ['Jawaban relevan'],
        improvements: ['Tambahkan metrik pencapaian'],
        suggestedRewrite: 'Saya bekerja selama dua tahun...',
        nextQuestion: 'Apa pencapaian terbesar Anda?',
        shouldEndSession: false,
      };

      llmClient.evaluateAnswer.mockResolvedValue(mockEvaluation);
      repository.addQuestion.mockResolvedValue({
        id: 'turn-q-1',
        sessionId: mockSessionId,
        role: 'question',
        content: mockEvaluation.nextQuestion,
        idempotencyKey: null,
        parentTurnId: 'turn-ans-1',
        processingStatus: null,
        evaluation: null,
        createdAt: new Date().toISOString(),
      });

      await service.submitAnswerStream(
        mockUser,
        mockSessionId,
        mockInput,
        mockResponse as any,
      );

      expect(mockResponse.setHeader).toHaveBeenCalledWith(
        'Content-Type',
        'text/event-stream',
      );
      expect(mockResponse.write).toHaveBeenCalled();
      expect(mockResponse.end).toHaveBeenCalled();

      const writtenEvents = mockResponse.write.mock.calls.map(
        (call) => call[0] as string,
      );

      expect(writtenEvents.some((e) => e.includes('event: started'))).toBe(true);
      expect(writtenEvents.some((e) => e.includes('event: delta'))).toBe(true);
      expect(writtenEvents.some((e) => e.includes('event: question'))).toBe(true);
      expect(writtenEvents.some((e) => e.includes('event: completed'))).toBe(true);
    });

    it('streams evaluation event in coaching mode', async () => {
      const coachingSession = { ...mockSession, mode: 'coaching' };
      repository.getOwnedSession.mockResolvedValue(coachingSession);
      repository.claimAnswer.mockResolvedValue({
        isNew: true,
        turn: {
          id: 'turn-ans-2',
          sessionId: mockSessionId,
          role: 'answer',
          content: mockInput.answer.text,
          idempotencyKey: mockInput.idempotencyKey,
          parentTurnId: 'turn-q-0',
          processingStatus: 'pending',
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
      });

      repository.listTurns.mockResolvedValue([
        {
          id: 'turn-q-0',
          sessionId: mockSessionId,
          role: 'question',
          content: 'Pertanyaan pertama',
          idempotencyKey: null,
          parentTurnId: null,
          processingStatus: null,
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
        {
          id: 'turn-ans-2',
          sessionId: mockSessionId,
          role: 'answer',
          content: mockInput.answer.text,
          idempotencyKey: mockInput.idempotencyKey,
          parentTurnId: 'turn-q-0',
          processingStatus: 'pending',
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
      ]);
      repository.listRecentTurns.mockResolvedValue([]);

      const mockEvaluation = {
        overallScore: 90,
        dimensions: {
          relevance: 5,
          clarity: 5,
          structure: 4,
          confidence: 4,
          impact: 4,
          authenticity: 5,
        },
        candidateFacts: [],
        strengths: ['Hebat'],
        improvements: [],
        suggestedRewrite: 'Bagus',
        nextQuestion: 'Pertanyaan selanjutnya',
        shouldEndSession: false,
      };

      llmClient.evaluateAnswer.mockResolvedValue(mockEvaluation);
      repository.addQuestion.mockResolvedValue({
        id: 'turn-q-2',
        sessionId: mockSessionId,
        role: 'question',
        content: mockEvaluation.nextQuestion,
        idempotencyKey: null,
        parentTurnId: 'turn-ans-2',
        processingStatus: null,
        evaluation: null,
        createdAt: new Date().toISOString(),
      });

      await service.submitAnswerStream(
        mockUser,
        mockSessionId,
        mockInput,
        mockResponse as any,
      );

      const writtenEvents = mockResponse.write.mock.calls.map(
        (call) => call[0] as string,
      );
      expect(writtenEvents.some((e) => e.includes('event: evaluation'))).toBe(
        true,
      );
    });

    it('emits error event when evaluation fails', async () => {
      repository.getOwnedSession.mockResolvedValue(mockSession);
      repository.claimAnswer.mockResolvedValue({
        isNew: true,
        turn: {
          id: 'turn-ans-3',
          sessionId: mockSessionId,
          role: 'answer',
          content: mockInput.answer.text,
          idempotencyKey: mockInput.idempotencyKey,
          parentTurnId: 'turn-q-0',
          processingStatus: 'pending',
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
      });

      repository.listTurns.mockResolvedValue([
        {
          id: 'turn-q-0',
          sessionId: mockSessionId,
          role: 'question',
          content: 'Pertanyaan',
          idempotencyKey: null,
          parentTurnId: null,
          processingStatus: null,
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
        {
          id: 'turn-ans-3',
          sessionId: mockSessionId,
          role: 'answer',
          content: mockInput.answer.text,
          idempotencyKey: mockInput.idempotencyKey,
          parentTurnId: 'turn-q-0',
          processingStatus: 'pending',
          evaluation: null,
          createdAt: new Date().toISOString(),
        },
      ]);
      repository.listRecentTurns.mockResolvedValue([]);
      llmClient.evaluateAnswer.mockRejectedValue(
        new Error('LLM model connection timeout'),
      );

      await service.submitAnswerStream(
        mockUser,
        mockSessionId,
        mockInput,
        mockResponse as any,
      );

      expect(repository.failAnswer).toHaveBeenCalledWith('turn-ans-3');
      const writtenEvents = mockResponse.write.mock.calls.map(
        (call) => call[0] as string,
      );
      expect(writtenEvents.some((e) => e.includes('event: error'))).toBe(true);
    });
  });
});
