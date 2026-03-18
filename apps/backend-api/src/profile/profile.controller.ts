import { Controller, Get, UseGuards } from '@nestjs/common';
import { SupabaseAuthGuard } from 'src/auth/guards/supabase-auth.guard';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { ProfileService } from './profile.service';

@Controller('profile')
@UseGuards(SupabaseAuthGuard) // 🛡️ Locks this entire controller!
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  getMyProfile(@GetUser() user: any) {
    // We completely ignore the URL or Body. 
    // We grab the ID directly from the cryptographically verified token.
    const userId = user.id; 
    
    return this.profileService.getProfile(userId);
  }
}