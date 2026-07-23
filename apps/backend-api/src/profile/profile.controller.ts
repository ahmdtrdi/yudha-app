import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import type { User } from '@supabase/supabase-js';
import { GetUser } from '../auth/decorators/get-user.decorator';
import {
  ProfileService,
  type UpdateLoadoutPayload,
  type UpdateProfilePayload,
} from './profile.service';

@Controller('profile')
@UseGuards(SupabaseAuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  getMyProfile(@GetUser() user: User) {
    return this.profileService.getProfile(user.id);
  }

  @Patch()
  updateMyProfile(@GetUser() user: User, @Body() payload: UpdateProfilePayload) {
    return this.profileService.updateProfile(user.id, payload);
  }

  @Patch('loadout')
  updateMyLoadout(
    @GetUser() user: User,
    @Body() payload: UpdateLoadoutPayload,
  ) {
    return this.profileService.updateLoadout(user.id, payload);
  }
}
