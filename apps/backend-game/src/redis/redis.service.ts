import { Injectable, Logger, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { hostname } from 'node:os';
import { randomUUID } from 'node:crypto';

type ManagedRedisClient =
  | 'command'
  | 'socket-publisher'
  | 'socket-subscriber'
  | 'routing-subscriber';

@Injectable()
export class RedisService implements OnApplicationShutdown {
  private readonly logger = new Logger(RedisService.name);
  private readonly clients = new Map<ManagedRedisClient, Redis>();
  private connectionPromise: Promise<boolean> | null = null;

  readonly enabled: boolean;
  readonly keyPrefix: string;
  readonly instanceId: string;

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>('REDIS_URL')?.trim();
    const testDisabled =
      process.env.NODE_ENV === 'test' &&
      process.env.REDIS_INTEGRATION_TEST !== '1';

    this.enabled = Boolean(url) && !testDisabled;
    this.keyPrefix =
      this.config.get<string>('REDIS_KEY_PREFIX')?.trim() ||
      `yudha:game:${this.config.get<string>('NODE_ENV') || 'development'}`;
    this.instanceId =
      this.config.get<string>('GAME_INSTANCE_ID')?.trim() ||
      `${hostname()}:${process.pid}:${randomUUID().slice(0, 8)}`;

    if (!this.enabled) return;
    if (!url?.startsWith('rediss://')) {
      throw new Error('REDIS_URL must use the rediss:// TLS scheme.');
    }

    this.clients.set('command', this.createClient(url, 'command'));
    this.clients.set(
      'socket-publisher',
      this.createClient(url, 'socket-publisher'),
    );
    this.clients.set(
      'socket-subscriber',
      this.createClient(url, 'socket-subscriber'),
    );
    this.clients.set(
      'routing-subscriber',
      this.createClient(url, 'routing-subscriber'),
    );
  }

  get command(): Redis | undefined {
    return this.clients.get('command');
  }

  get socketPublisher(): Redis | undefined {
    return this.clients.get('socket-publisher');
  }

  get socketSubscriber(): Redis | undefined {
    return this.clients.get('socket-subscriber');
  }

  get routingSubscriber(): Redis | undefined {
    return this.clients.get('routing-subscriber');
  }

  key(...parts: string[]): string {
    return [this.keyPrefix, ...parts].join(':');
  }

  isReady(): boolean {
    return (
      this.enabled &&
      [...this.clients.values()].every((client) => client.status === 'ready')
    );
  }

  async connect(): Promise<boolean> {
    if (!this.enabled) return false;
    if (this.isReady()) return true;
    if (this.connectionPromise) return this.connectionPromise;

    this.connectionPromise = Promise.all(
      [...this.clients.values()].map(async (client) => {
        if (client.status === 'wait') await client.connect();
      }),
    )
      .then(() => {
        this.logger.log(
          `Redis clients ready for game instance ${this.instanceId}.`,
        );
        return this.isReady();
      })
      .catch((error: unknown) => {
        this.logger.error(
          `Redis initial connection failed: ${this.errorMessage(error)}`,
        );
        return false;
      })
      .finally(() => {
        this.connectionPromise = null;
      });

    return this.connectionPromise;
  }

  async ping(): Promise<boolean> {
    if (!this.command || this.command.status !== 'ready') return false;
    try {
      return (await this.command.ping()) === 'PONG';
    } catch {
      return false;
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled(
      [...this.clients.values()].map(async (client) => {
        if (client.status === 'end') return;
        try {
          await client.quit();
        } catch {
          client.disconnect(false);
        }
      }),
    );
  }

  private createClient(url: string, name: ManagedRedisClient): Redis {
    const client = new Redis(url, {
      lazyConnect: true,
      enableOfflineQueue: false,
      maxRetriesPerRequest: 1,
      connectTimeout: 5_000,
      commandTimeout: 2_000,
      connectionName: `yudha-game:${this.instanceId}:${name}`,
      retryStrategy: (attempt) => Math.min(250 * 2 ** (attempt - 1), 5_000),
    });
    client.on('ready', () =>
      this.logger.log(`Redis ${name} connection ready.`),
    );
    client.on('close', () =>
      this.logger.warn(`Redis ${name} connection closed.`),
    );
    client.on('error', (error) =>
      this.logger.error(`Redis ${name} error: ${this.errorMessage(error)}`),
    );
    return client;
  }

  private errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }
}
