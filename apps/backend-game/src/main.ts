import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Enable CORS so Flutter and Postman can connect to the sockets
  app.enableCors(); 
  
  // Change this to 3001!
  await app.listen(3001); 
  console.log('🎮 Game Server running on http://localhost:3001');
}
bootstrap();