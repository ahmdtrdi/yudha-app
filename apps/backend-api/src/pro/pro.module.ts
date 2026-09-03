import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { ProController } from './pro.controller';
import { ProService } from './pro.service';

@Module({
  imports: [SupabaseModule],
  controllers: [ProController],
  providers: [ProService],
  exports: [ProService],
})
export class ProModule {}
