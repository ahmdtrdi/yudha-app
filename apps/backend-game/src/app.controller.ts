import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { AppService } from './app.service';
import { RedisService } from './redis/redis.service';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly redis: RedisService,
  ) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health/live')
  getLiveness(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Get('health/ready')
  async getReadiness(): Promise<{
    status: 'ok';
    dependencies: { redis: 'up' };
  }> {
    if (!(await this.redis.ping())) {
      throw new ServiceUnavailableException({
        status: 'unavailable',
        dependencies: { redis: 'down' },
      });
    }
    return { status: 'ok', dependencies: { redis: 'up' } };
  }
}
