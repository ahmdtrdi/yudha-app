import { Global, Module } from '@nestjs/common';
import { RedisService } from './redis.service';
import { GameCoordinationService } from './game-coordination.service';
import { RoomCommandRouterService } from './room-command-router.service';

@Global()
@Module({
  providers: [RedisService, GameCoordinationService, RoomCommandRouterService],
  exports: [RedisService, GameCoordinationService, RoomCommandRouterService],
})
export class RedisModule {}
