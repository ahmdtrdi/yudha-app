import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { HiredPassController } from './hired-pass.controller';
import { HiredPassService } from './hired-pass.service';

@Module({
  imports: [SupabaseModule],
  controllers: [HiredPassController],
  providers: [HiredPassService],
  exports: [HiredPassService],
})
export class HiredPassModule {}
