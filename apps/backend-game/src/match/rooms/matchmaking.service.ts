import { Injectable } from '@nestjs/common';
import { RoomManager } from './room-manager';

@Injectable()
export class MatchmakingService {
  constructor(readonly rooms: RoomManager) {}
}
