import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { RedisService } from './redis.service';

export type RoutedRoomOperation =
  | 'reconnect'
  | 'disconnect'
  | 'open_card'
  | 'play_card'
  | 'surrender'
  | 'join_private_room';

export type RoutedRoomCommand = {
  operation: RoutedRoomOperation;
  userId: string;
  socketId: string;
  payload?: unknown;
};

type RequestEnvelope = RoutedRoomCommand & {
  type: 'request';
  correlationId: string;
  sourceInstanceId: string;
};

type ResponseEnvelope = {
  type: 'response';
  correlationId: string;
  result?: unknown;
  error?: string;
};

@Injectable()
export class RoomCommandRouterService
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(RoomCommandRouterService.name);
  private readonly pending = new Map<
    string,
    {
      resolve: (value: unknown) => void;
      reject: (error: Error) => void;
      timer: ReturnType<typeof setTimeout>;
    }
  >();
  private handler?: (command: RoutedRoomCommand) => Promise<unknown>;
  private subscribed = false;

  constructor(private readonly redis: RedisService) {}

  setHandler(handler: (command: RoutedRoomCommand) => Promise<unknown>): void {
    this.handler = handler;
  }

  async onApplicationBootstrap(): Promise<void> {
    const subscriber = this.redis.routingSubscriber;
    if (!subscriber || !this.redis.enabled) return;
    subscriber.on('message', (channel, message) => {
      void this.onMessage(channel, message);
    });
    subscriber.on('ready', () => void this.subscribe());
    await this.subscribe();
  }

  async route<T>(instanceId: string, command: RoutedRoomCommand): Promise<T> {
    if (instanceId === this.redis.instanceId) {
      if (!this.handler)
        throw new Error('Room command handler is unavailable.');
      return (await this.handler(command)) as T;
    }
    const publisher = this.redis.command;
    if (!this.redis.isReady() || !publisher) {
      throw new Error('Redis room routing is unavailable.');
    }
    const correlationId = randomUUID();
    const envelope: RequestEnvelope = {
      type: 'request',
      correlationId,
      sourceInstanceId: this.redis.instanceId,
      ...command,
    };
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(correlationId);
        reject(new Error('Room owner did not respond in time.'));
      }, 5_000);
      timer.unref?.();
      this.pending.set(correlationId, {
        resolve: (value) => resolve(value as T),
        reject,
        timer,
      });
      void publisher
        .publish(this.requestChannel(instanceId), JSON.stringify(envelope))
        .catch((error: unknown) => {
          clearTimeout(timer);
          this.pending.delete(correlationId);
          reject(error instanceof Error ? error : new Error(String(error)));
        });
    });
  }

  onApplicationShutdown(): void {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error('Game instance is shutting down.'));
    }
    this.pending.clear();
  }

  private async onMessage(channel: string, message: string): Promise<void> {
    let envelope: RequestEnvelope | ResponseEnvelope;
    try {
      envelope = JSON.parse(message) as RequestEnvelope | ResponseEnvelope;
    } catch {
      return;
    }

    if (channel === this.responseChannel(this.redis.instanceId)) {
      const response = envelope as ResponseEnvelope;
      const pending = this.pending.get(response.correlationId);
      if (!pending) return;
      clearTimeout(pending.timer);
      this.pending.delete(response.correlationId);
      if (response.error) pending.reject(new Error(response.error));
      else pending.resolve(response.result);
      return;
    }

    const request = envelope as RequestEnvelope;
    const publisher = this.redis.command;
    if (!publisher || !this.handler) return;
    try {
      const result = await this.handler(request);
      await publisher.publish(
        this.responseChannel(request.sourceInstanceId),
        JSON.stringify({
          type: 'response',
          correlationId: request.correlationId,
          result,
        } satisfies ResponseEnvelope),
      );
    } catch (error) {
      await publisher.publish(
        this.responseChannel(request.sourceInstanceId),
        JSON.stringify({
          type: 'response',
          correlationId: request.correlationId,
          error: error instanceof Error ? error.message : String(error),
        } satisfies ResponseEnvelope),
      );
    }
  }

  private async subscribe(): Promise<void> {
    const subscriber = this.redis.routingSubscriber;
    if (!subscriber || subscriber.status !== 'ready' || this.subscribed) return;
    try {
      await subscriber.subscribe(
        this.requestChannel(this.redis.instanceId),
        this.responseChannel(this.redis.instanceId),
      );
      this.subscribed = true;
      this.logger.log(
        `Room command routing ready for instance ${this.redis.instanceId}.`,
      );
    } catch (error) {
      this.subscribed = false;
      this.logger.error(
        `Failed to subscribe to room routing: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private requestChannel(instanceId: string): string {
    return this.redis.key('route', 'request', instanceId);
  }

  private responseChannel(instanceId: string): string {
    return this.redis.key('route', 'response', instanceId);
  }
}
