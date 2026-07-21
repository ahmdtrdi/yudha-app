import { ConfigService } from '@nestjs/config';
import { GroqTtsService } from './groq-tts.service';

describe('GroqTtsService', () => {
  let service: GroqTtsService;

  beforeEach(() => {
    const configService = new ConfigService({
      GROQ_API_KEY: 'test-groq-key',
    });

    service = new GroqTtsService(configService);
  });

  it('instantiates cleanly with valid config', () => {
    expect(service).toBeDefined();
  });
});
