import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { StoreController } from './store.controller';
import { StoreService } from './store.service';

@Module({
  imports: [SupabaseModule],
  controllers: [StoreController],
  providers: [StoreService],
})
export class StoreModule {}

