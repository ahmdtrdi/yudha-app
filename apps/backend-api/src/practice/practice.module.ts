import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { LearningModule } from '../learning/learning.module';
import { PracticeController } from './practice.controller';
import { PracticeRepository } from './practice.repository';
import { PracticeService } from './practice.service';

@Module({
  imports: [SupabaseModule, LearningModule],
  controllers: [PracticeController],
  providers: [PracticeService, PracticeRepository],
})
export class PracticeModule {}
