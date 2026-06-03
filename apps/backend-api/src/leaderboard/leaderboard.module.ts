import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardRepository } from './leaderboard.repository';
import { LeaderboardService } from './leaderboard.service';

@Module({
  imports: [SupabaseModule],
  controllers: [LeaderboardController],
  providers: [LeaderboardService, LeaderboardRepository],
})
export class LeaderboardModule {}
