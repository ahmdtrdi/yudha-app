import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { PvpAnalyticsController } from './pvp-analytics.controller';
import { PvpAnalyticsRepository } from './pvp-analytics.repository';
import { PvpAnalyticsService } from './pvp-analytics.service';

@Module({
  imports: [SupabaseModule],
  controllers: [PvpAnalyticsController],
  providers: [PvpAnalyticsService, PvpAnalyticsRepository],
  exports: [PvpAnalyticsService],
})
export class PvpAnalyticsModule {}
