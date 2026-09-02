import { Module } from '@nestjs/common';
import { AnalyticsModule } from '../analytics/analytics.module';
import { EconomyModule } from '../economy/economy.module';
import { ProfileModule } from '../profile/profile.module';
import { SupabaseModule } from '../supabase/supabase.module';
import { LearningModule } from '../learning/learning.module';
import { LobbyController } from './lobby.controller';
import { LobbyService } from './lobby.service';

@Module({
  imports: [
    SupabaseModule,
    ProfileModule,
    AnalyticsModule,
    EconomyModule,
    LearningModule,
  ],
  controllers: [LobbyController],
  providers: [LobbyService],
})
export class LobbyModule {}
