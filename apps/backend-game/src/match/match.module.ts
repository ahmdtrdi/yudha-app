import { Module } from '@nestjs/common';
import { MatchGateway } from './match.gateway';
import { MatchService } from './match.service';
import { SupabaseModule } from '../supabase/supabase.module';
import { GameEngine } from './engine/game-engine';
import { QuestionDealer } from './engine/question-dealer';
import { QuestionService } from './questions/question.service';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import { MatchLogBuffer } from './logs/match-log-buffer';

@Module({
  imports: [SupabaseModule],
  providers: [MatchGateway, MatchService, GameEngine, QuestionDealer, QuestionService, MatchResultService, RoomManager, MatchLogBuffer],
})
export class MatchModule {}
