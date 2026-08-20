import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { RedisIoAdapter } from './redis/redis-io.adapter';
import { RedisService } from './redis/redis.service';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.enableShutdownHooks();

  const redis = app.get(RedisService);
  await redis.connect();
  app.useWebSocketAdapter(new RedisIoAdapter(app, redis));

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port);
  console.log(`Game Server running on http://localhost:${port}`);
}

void bootstrap();
