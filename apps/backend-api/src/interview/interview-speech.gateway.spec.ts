import { InterviewSpeechGateway } from './interview-speech.gateway';
import { InterviewSpeechStreamService } from './services/interview-speech-stream.service';

describe('InterviewSpeechGateway', () => {
  let gateway: InterviewSpeechGateway;
  let supabaseService: any;
  let repository: any;
  let interviewService: any;
  let speechStreamService: InterviewSpeechStreamService;
  let sttClient: any;
  let ttsClient: any;

  beforeEach(() => {
    supabaseService = {
      getClient: jest.fn().mockReturnValue({
        auth: {
          getUser: jest.fn(),
        },
      }),
    };

    repository = {
      getOwnedSession: jest.fn(),
    };

    interviewService = {
      submitAnswer: jest.fn(),
    };

    speechStreamService = new InterviewSpeechStreamService();

    sttClient = {
      transcribe: jest.fn(),
    };

    ttsClient = {
      synthesize: jest.fn(),
    };

    gateway = new InterviewSpeechGateway(
      supabaseService,
      repository,
      interviewService,
      speechStreamService,
      sttClient,
      ttsClient,
    );
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });

  describe('handleConnection', () => {
    it('authenticates valid token and stores userId on socket', async () => {
      const mockClient: any = {
        id: 'socket-1',
        handshake: {
          auth: { token: 'valid-jwt-token' },
        },
        data: {},
        disconnect: jest.fn(),
      };

      supabaseService.getClient().auth.getUser.mockResolvedValue({
        data: { user: { id: 'user-123' } },
        error: null,
      });

      await gateway.handleConnection(mockClient);

      expect(mockClient.data.userId).toBe('user-123');
      expect(mockClient.disconnect).not.toHaveBeenCalled();
    });

    it('disconnects unauthenticated client missing token', async () => {
      const mockClient: any = {
        id: 'socket-2',
        handshake: { auth: {} },
        data: {},
        disconnect: jest.fn(),
      };

      await gateway.handleConnection(mockClient);

      expect(mockClient.disconnect).toHaveBeenCalledWith(true);
    });
  });

  describe('handleStartSession', () => {
    it('emits session_ready for an active owned session', async () => {
      const mockClient: any = {
        data: { userId: 'user-123' },
        emit: jest.fn(),
      };

      repository.getOwnedSession.mockResolvedValue({
        id: 'session-123',
        status: 'active',
      });

      await gateway.handleStartSession(mockClient, {
        commandId: 'cmd-1',
        sessionId: 'session-123',
      });

      expect(mockClient.emit).toHaveBeenCalledWith('session_ready', {
        commandId: 'cmd-1',
        sessionId: 'session-123',
        status: 'ready',
      });
    });
  });

  describe('handleAudioChunk and handleFinishAnswer', () => {
    it('accumulates chunks and processes finish_answer flow', async () => {
      const mockClient: any = {
        data: { userId: 'user-123' },
        emit: jest.fn(),
      };

      repository.getOwnedSession.mockResolvedValue({
        id: 'session-123',
        status: 'active',
      });

      await gateway.handleStartSession(mockClient, {
        commandId: 'cmd-1',
        sessionId: 'session-123',
      });

      await gateway.handleAudioChunk(mockClient, {
        commandId: 'cmd-2',
        sessionId: 'session-123',
        sequence: 0,
        audio: Buffer.from('audio-data-chunk-1').toString('base64'),
      });

      sttClient.transcribe.mockResolvedValue({
        text: 'Saya lulusan S1 Akuntansi.',
      });

      interviewService.submitAnswer.mockResolvedValue({
        status: 'active',
        evaluation: null,
        nextQuestion: {
          turnId: 'turn-q-2',
          text: 'Apa motivasi utama Anda?',
        },
      });

      ttsClient.synthesize.mockResolvedValue({
        audio: Buffer.from('synthesized-audio-bytes'),
      });

      await gateway.handleFinishAnswer(mockClient, {
        commandId: 'cmd-3',
        sessionId: 'session-123',
      });

      const emittedEvents = mockClient.emit.mock.calls.map(
        (call: any) => call[0],
      );

      expect(emittedEvents).toContain('transcript_final');
      expect(emittedEvents).toContain('question_text');
      expect(emittedEvents).toContain('question_audio_chunk');
      expect(emittedEvents).toContain('turn_completed');
    });
  });
});
