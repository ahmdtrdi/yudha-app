import { Module } from '@nestjs/common';
import { AdminContentQualityController } from './admin-content-quality.controller';
import { AdminContentQualityService } from './admin-content-quality.service';
import { AdminAuthGuard } from './guards/admin-auth.guard';
import { SupabaseModule } from '../supabase/supabase.module';

@Module({
  imports: [SupabaseModule],
  controllers: [AdminContentQualityController],
  providers: [AdminContentQualityService, AdminAuthGuard],
  exports: [AdminContentQualityService],
})
export class AdminModule {}
