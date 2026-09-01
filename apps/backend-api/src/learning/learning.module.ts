import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { LearningController } from './learning.controller';
import { LearningProjectionService } from './learning.projection.service';
import { LearningRepository } from './learning.repository';
import { LearningService } from './learning.service';
import { LearningProjectionWorker } from './learning.worker';

@Module({
  imports: [SupabaseModule],
  controllers: [LearningController],
  providers: [
    LearningService,
    LearningRepository,
    LearningProjectionService,
    LearningProjectionWorker,
  ],
  exports: [LearningService, LearningProjectionService],
})
export class LearningModule {}
