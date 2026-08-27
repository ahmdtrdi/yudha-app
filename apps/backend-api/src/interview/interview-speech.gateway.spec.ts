import { ConfigService } from '@nestjs/config';
import { InterviewSpeechGateway } from './interview-speech.gateway';
import { InterviewSpeechStreamService } from './services/interview-speech-stream.service';
import { InterviewGuardrailService } from './services/interview-guardrail.service';

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
        auth: { getUser: jest.fn() },
      }),
    };
    repository = {
      getOwnedSession: jest.fn().mockResolvedValue({
        id: 'session-123',
        status: 'active',
        responseStyle: 'voice',
        language: 'id',
        targetRole: 'Analis',
        contextSnapshot: { companyName: 'YUDHA' },
      }),
    };
    interviewService = { submitAnswer: jest.fn() };
    speechStreamService = new InterviewSpeechStreamService();
    sttClient = { transcribe: jest.fn() };
    ttsClient = { synthesize: jest.fn() };
    const configService = {
      get: jest.fn((key: string, fallback?: string) => {
        const values: Record<string, string> = {
          INTERVIEW_LIVE_SPEECH_ENABLED: 'true',
          ENABLE_INTERVIEW_DEV_TOKENS: 'false',
          NODE_ENV: 'test',
        };
        return values[key] ?? fallback;
      }),
    } as unknown as ConfigService;

    gateway = new InterviewSpeechGateway(
      supabaseService,
      repository,
      interviewService,
      speechStreamService,
      new InterviewGuardrailService(),
      configService,
      sttClient,
      ttsClient,
    );
  });

  it('authenticates a verified Supabase token', async () => {
    const client = socket({ token: 'valid-token' });
    supabaseService.getClient().auth.getUser.mockResolvedValue({
      data: { user: { id: 'user-123' } },
      error: null,
    });

    await gateway.handleConnection(client);

    expect(client.data.userId).toBe('user-123');
    expect(client.disconnect).not.toHaveBeenCalled();
  });

  it('does not trust an unverified JWT payload', async () => {
    const unsignedPayload = Buffer.from(
      JSON.stringify({ sub: 'attacker-user' }),
    ).toString('base64url');
    const client = socket({ token: `x.${unsignedPayload}.x` });
    supabaseService.getClient().auth.getUser.mockResolvedValue({
      data: { user: null },
      error: { message: 'invalid token' },
    });

    await gateway.handleConnection(client);

    expect(client.data.userId).toBeUndefined();
    expect(client.disconnect).toHaveBeenCalledWith(true);
  });

  it('advertises the PCM contract for an owned voice session', async () => {
    const client = socket();
    client.data.userId = 'user-123';

    await gateway.handleStartSession(client, {
      commandId: 'start-1',
      sessionId: 'session-123',
    });

    expect(client.emit).toHaveBeenCalledWith(
      'session_ready',
      expect.objectContaining({
        commandId: 'start-1',
        sessionId: 'session-123',
        audioConfig: expect.objectContaining({
          encoding: 'pcm_s16le',
          sampleRateHz: 16000,
          channels: 1,
          maxChunkBytes: 65536,
        }),
      }),
    );
  });

  it('acknowledges ordered chunks and completes the speech turn', async () => {
    const client = socket();
    client.data.userId = 'user-123';
    await gateway.handleStartSession(client, {
      commandId: 'start-1',
      sessionId: 'session-123',
    });

    await gateway.handleAudioChunk(client, chunkPayload());
    sttClient.transcribe.mockResolvedValue({
      text: 'Saya siap berkontribusi.',
      provider: 'groq',
    });
    interviewService.submitAnswer.mockResolvedValue({
      status: 'active',
      evaluation: { overallScore: 80 },
      nextQuestion: { turnId: 'question-2', text: 'Apa kekuatan Anda?' },
    });
    ttsClient.synthesize.mockResolvedValue({
      audio: Buffer.from('audio'),
      contentType: 'audio/mpeg',
      fileExtension: 'mp3',
      provider: 'elevenlabs',
    });

    await gateway.handleFinishAnswer(client, {
      commandId: 'finish-1',
      sessionId: 'session-123',
      answerId: 'answer-1',
      finalSequence: 0,
    });

    expect(client.emit).toHaveBeenCalledWith(
      'audio_chunk_ack',
      expect.objectContaining({ answerId: 'answer-1', sequence: 0 }),
    );
    expect(sttClient.transcribe).toHaveBeenCalledWith(
      expect.objectContaining({
        fileName: 'answer.wav',
        mimeType: 'audio/wav',
        language: 'id',
      }),
    );
    const wav = sttClient.transcribe.mock.calls[0][0].audio as Buffer;
    expect(wav.subarray(0, 4).toString()).toBe('RIFF');
    expect(interviewService.submitAnswer).toHaveBeenCalledWith(
      'user-123',
      'session-123',
      expect.objectContaining({ idempotencyKey: 'answer-1' }),
    );
    expect(ttsClient.synthesize).toHaveBeenCalledWith({
      text: 'Apa kekuatan Anda?',
      language: 'id',
    });
    expect(client.emit).toHaveBeenCalledWith(
      'question_audio_start',
      expect.objectContaining({
        answerId: 'answer-1',
        contentType: 'audio/mpeg',
        provider: 'elevenlabs',
      }),
    );
    expect(client.emit).toHaveBeenCalledWith(
      'question_audio_end',
      expect.objectContaining({ finalSequence: 0 }),
    );
    expect(client.emit).toHaveBeenCalledWith(
      'turn_completed',
      expect.objectContaining({ answerId: 'answer-1' }),
    );

    client.emit.mockClear();
    await gateway.handleAudioChunk(
      client,
      chunkPayload({ commandId: 'chunk-2', answerId: 'answer-2' }),
    );
    expect(client.emit).toHaveBeenCalledWith(
      'audio_chunk_ack',
      expect.objectContaining({ answerId: 'answer-2', sequence: 0 }),
    );
  });

  it('rejects sequence gaps without acknowledging the chunk', async () => {
    const client = socket();
    client.data.userId = 'user-123';
    await gateway.handleStartSession(client, {
      commandId: 'start-1',
      sessionId: 'session-123',
    });

    await gateway.handleAudioChunk(client, chunkPayload({ sequence: 1 }));

    expect(client.emit).toHaveBeenCalledWith(
      'error',
      expect.objectContaining({
        error: expect.objectContaining({ code: 'INVALID_SEQUENCE' }),
      }),
    );
    expect(client.emit).not.toHaveBeenCalledWith(
      'audio_chunk_ack',
      expect.anything(),
    );
  });

  it('clears raw capture state on disconnect', async () => {
    const client = socket();
    client.data.userId = 'user-123';
    await gateway.handleStartSession(client, {
      commandId: 'start-1',
      sessionId: 'session-123',
    });
    await gateway.handleAudioChunk(client, chunkPayload());

    gateway.handleDisconnect(client);
    await gateway.handleAudioChunk(client, chunkPayload());

    expect(client.emit).toHaveBeenCalledWith(
      'error',
      expect.objectContaining({
        error: expect.objectContaining({ code: 'SESSION_NOT_READY' }),
      }),
    );
  });

  it('discards a cancelled answer and re-arms sequence zero', async () => {
    const client = socket();
    client.data.userId = 'user-123';
    await gateway.handleStartSession(client, {
      commandId: 'start-1',
      sessionId: 'session-123',
    });
    await gateway.handleAudioChunk(client, chunkPayload());

    gateway.handleCancel(client, {
      commandId: 'cancel-1',
      sessionId: 'session-123',
      answerId: 'answer-1',
    });
    await gateway.handleAudioChunk(
      client,
      chunkPayload({ commandId: 'chunk-2', answerId: 'answer-2' }),
    );

    expect(client.emit).toHaveBeenCalledWith(
      'cancelled',
      expect.objectContaining({ answerId: 'answer-1' }),
    );
    expect(client.emit).toHaveBeenCalledWith(
      'audio_chunk_ack',
      expect.objectContaining({ answerId: 'answer-2', sequence: 0 }),
    );
  });
});

function socket(auth: Record<string, string> = {}): any {
  return {
    id: 'socket-1',
    handshake: { auth, headers: {} },
    data: {},
    emit: jest.fn(),
    disconnect: jest.fn(),
  };
}

function chunkPayload(overrides: Record<string, unknown> = {}) {
  return {
    commandId: 'chunk-1',
    sessionId: 'session-123',
    answerId: 'answer-1',
    sequence: 0,
    audio: Buffer.from([1, 0, 2, 0]).toString('base64'),
    encoding: 'pcm_s16le',
    sampleRateHz: 16000,
    channels: 1,
    ...overrides,
  };
}
