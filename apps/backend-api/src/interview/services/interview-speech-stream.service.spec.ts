import {
  InterviewSpeechStreamError,
  InterviewSpeechStreamService,
} from './interview-speech-stream.service';

describe('InterviewSpeechStreamService', () => {
  let service: InterviewSpeechStreamService;

  beforeEach(() => {
    service = new InterviewSpeechStreamService();
    service.startSession('socket:session');
  });

  it('wraps ordered PCM16 chunks in a valid mono 16 kHz WAV file', () => {
    service.appendAudioChunk('socket:session', chunk(0, [1, 0, 2, 0]));
    service.appendAudioChunk('socket:session', chunk(1, [3, 0, 4, 0]));

    const wav = service.finishAnswer('socket:session', 'answer-1', 1);

    expect(wav.subarray(0, 4).toString()).toBe('RIFF');
    expect(wav.subarray(8, 12).toString()).toBe('WAVE');
    expect(wav.readUInt16LE(22)).toBe(1);
    expect(wav.readUInt32LE(24)).toBe(16000);
    expect(wav.readUInt16LE(34)).toBe(16);
    expect(wav.readUInt32LE(40)).toBe(8);
    expect([...wav.subarray(44)]).toEqual([1, 0, 2, 0, 3, 0, 4, 0]);
  });

  it('rejects duplicate and missing sequence numbers', () => {
    service.appendAudioChunk('socket:session', chunk(0, [1, 0]));

    expect(() =>
      service.appendAudioChunk('socket:session', chunk(0, [2, 0])),
    ).toThrow(expectError('INVALID_SEQUENCE'));
    expect(() =>
      service.appendAudioChunk('socket:session', chunk(2, [2, 0])),
    ).toThrow(expectError('INVALID_SEQUENCE'));
  });

  it('rejects a second answer while capture is active', () => {
    service.appendAudioChunk('socket:session', chunk(0, [1, 0]));

    expect(() =>
      service.appendAudioChunk('socket:session', {
        ...chunk(1, [2, 0]),
        answerId: 'answer-2',
      }),
    ).toThrow(expectError('ANSWER_CONFLICT'));
  });

  it('starts the inactivity window with candidate audio, not question playback', () => {
    const now = jest.spyOn(Date, 'now').mockReturnValue(0);
    service.startSession('socket:session');

    now.mockReturnValue(20_000);
    expect(() =>
      service.appendAudioChunk('socket:session', chunk(0, [1, 0])),
    ).not.toThrow();

    now.mockReturnValue(36_000);
    expect(() =>
      service.appendAudioChunk('socket:session', chunk(1, [2, 0])),
    ).toThrow(expectError('CAPTURE_TIMEOUT'));
    now.mockRestore();
  });

  it('removes every raw capture owned by a disconnected socket', () => {
    service.clearClient('socket');

    expect(() =>
      service.appendAudioChunk('socket:session', chunk(0, [1, 0])),
    ).toThrow(expectError('SESSION_NOT_READY'));
  });

  it('resets cancelled capture while keeping the socket ready', () => {
    service.appendAudioChunk('socket:session', chunk(0, [1, 0]));

    expect(service.resetSession('socket:session')).toBe(true);
    expect(() =>
      service.appendAudioChunk('socket:session', {
        ...chunk(0, [2, 0]),
        answerId: 'answer-2',
      }),
    ).not.toThrow();
  });
});

function chunk(sequence: number, bytes: number[]) {
  return {
    answerId: 'answer-1',
    sequence,
    audio: Buffer.from(bytes).toString('base64'),
    encoding: 'pcm_s16le',
    sampleRateHz: 16000,
    channels: 1,
  };
}

function expectError(code: InterviewSpeechStreamError['code']) {
  return expect.objectContaining<Partial<InterviewSpeechStreamError>>({ code });
}
