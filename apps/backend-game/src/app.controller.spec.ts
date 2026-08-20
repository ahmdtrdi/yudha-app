import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { RedisService } from './redis/redis.service';

describe('AppController', () => {
  let appController: AppController;
  const ping = jest.fn<Promise<boolean>, []>();

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService, { provide: RedisService, useValue: { ping } }],
    }).compile();

    appController = app.get<AppController>(AppController);
    ping.mockResolvedValue(true);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(appController.getHello()).toBe('Hello World!');
    });
  });

  describe('health', () => {
    it('reports liveness', () => {
      expect(appController.getLiveness()).toEqual({ status: 'ok' });
    });

    it('reports Redis readiness', async () => {
      await expect(appController.getReadiness()).resolves.toEqual({
        status: 'ok',
        dependencies: { redis: 'up' },
      });
    });

    it('reports unready while Redis is unavailable', async () => {
      ping.mockResolvedValue(false);
      await expect(appController.getReadiness()).rejects.toMatchObject({
        status: 503,
      });
    });
  });
});
