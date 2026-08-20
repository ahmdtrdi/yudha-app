import type { ConfigService } from '@nestjs/config';
import { EventEmitter } from 'node:events';

type FakeClient = EventEmitter & {
  status: string;
  connect: jest.Mock;
  ping: jest.Mock;
  quit: jest.Mock;
  disconnect: jest.Mock;
};

const mockClients: FakeClient[] = [];

jest.mock('ioredis', () => ({
  __esModule: true,
  default: jest.fn().mockImplementation(() => {
    const emitter = new EventEmitter() as FakeClient;
    emitter.status = 'wait';
    emitter.connect = jest.fn(async () => {
      emitter.status = 'ready';
      emitter.emit('ready');
    });
    emitter.ping = jest.fn().mockResolvedValue('PONG');
    emitter.quit = jest.fn(async () => {
      emitter.status = 'end';
    });
    emitter.disconnect = jest.fn();
    mockClients.push(emitter);
    return emitter;
  }),
}));

import { RedisService } from './redis.service';

describe('RedisService lifecycle', () => {
  const previousIntegration = process.env.REDIS_INTEGRATION_TEST;

  beforeEach(() => {
    mockClients.length = 0;
    process.env.REDIS_INTEGRATION_TEST = '1';
  });

  afterAll(() => {
    if (previousIntegration === undefined) {
      delete process.env.REDIS_INTEGRATION_TEST;
    } else {
      process.env.REDIS_INTEGRATION_TEST = previousIntegration;
    }
  });

  it('connects four independent clients and closes all of them', async () => {
    const service = createService();

    await expect(service.connect()).resolves.toBe(true);
    expect(mockClients).toHaveLength(4);
    expect(
      mockClients.every((client) => client.connect.mock.calls.length === 1),
    ).toBe(true);
    await expect(service.ping()).resolves.toBe(true);

    await service.onApplicationShutdown();
    expect(
      mockClients.every((client) => client.quit.mock.calls.length === 1),
    ).toBe(true);
  });

  it('requires a TLS Redis URL', () => {
    expect(() => createService('redis://not-tls.example')).toThrow(
      'REDIS_URL must use the rediss:// TLS scheme.',
    );
  });

  function createService(url = 'rediss://default:secret@example.invalid:6379') {
    const values: Record<string, string> = {
      REDIS_URL: url,
      REDIS_KEY_PREFIX: 'yudha:test:unit',
      GAME_INSTANCE_ID: 'unit-instance',
      NODE_ENV: 'test',
    };
    return new RedisService({
      get: (key: string) => values[key],
    } as ConfigService);
  }
});
