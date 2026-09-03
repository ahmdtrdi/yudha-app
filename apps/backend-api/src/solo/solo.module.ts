import { Module } from '@nestjs/common';
import { LearningModule } from '../learning/learning.module';
import { SupabaseModule } from '../supabase/supabase.module';
import { SoloController } from './solo.controller';
import { SoloRepository } from './solo.repository';
import { SoloService } from './solo.service';

@Module({
  imports: [SupabaseModule, LearningModule],
  controllers: [SoloController],
  providers: [SoloService, SoloRepository],
})
export class SoloModule {}
