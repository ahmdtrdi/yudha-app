import { IoAdapter } from '@nestjs/platform-socket.io';
import type { INestApplicationContext } from '@nestjs/common';
import { createAdapter } from '@socket.io/redis-adapter';
import type { Server, ServerOptions } from 'socket.io';
import { RedisService } from './redis.service';

export class RedisIoAdapter extends IoAdapter {
  constructor(
    app: INestApplicationContext,
    private readonly redis: RedisService,
  ) {
    super(app);
  }

  createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;
    const publisher = this.redis.socketPublisher;
    const subscriber = this.redis.socketSubscriber;
    if (publisher && subscriber) {
      server.adapter(
        createAdapter(publisher, subscriber, {
          key: this.redis.key('socket.io'),
          publishOnSpecificResponseChannel: true,
        }),
      );
    }
    return server;
  }
}
