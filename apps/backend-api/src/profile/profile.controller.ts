import { Controller, Get, UseGuards } from '@nestjs/common';
import type { User } from '@supabase/supabase-js';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { ProfileService } from './profile.service';

@Controller('profile')
@UseGuards(SupabaseAuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  getMyProfile(@GetUser() user: User) {
    return this.profileService.getProfile(user.id);
  }
}
