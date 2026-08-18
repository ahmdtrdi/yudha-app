import { Module } from '@nestjs/common';
import { AnalyticsModule } from '../analytics/analytics.module';
import { HiredPassModule } from '../hired-pass/hired-pass.module';
import { ProfileModule } from '../profile/profile.module';
import { SupabaseModule } from '../supabase/supabase.module';
import { LobbyController } from './lobby.controller';
import { LobbyService } from './lobby.service';

@Module({
  imports: [SupabaseModule, ProfileModule, AnalyticsModule, HiredPassModule],
  controllers: [LobbyController],
  providers: [LobbyService],
})
export class LobbyModule {}
