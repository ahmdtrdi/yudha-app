import { Module } from '@nestjs/common';
import { ProfileService } from './profile.service';
import { ProfileController } from './profile.controller';
import { SupabaseModule } from '../supabase/supabase.module'; // Import this!

@Module({
  imports: [SupabaseModule], // Add to imports array!
  controllers: [ProfileController],
  providers: [ProfileService],
})
export class ProfileModule {}