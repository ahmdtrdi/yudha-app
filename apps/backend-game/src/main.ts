import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.enableCors();

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port);
  console.log(`Game Server running on http://localhost:${port}`);
}

void bootstrap();
