import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { LobbyService } from './lobby.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('lobby')
@UseGuards(SupabaseAuthGuard)
export class LobbyController {
  constructor(private readonly lobbyService: LobbyService) {}

  @Get('summary')
  getSummary(@GetUser() user: AuthenticatedUser) {
    return this.lobbyService.getSummary(user.id);
  }

  @Post('beta-welcome/acknowledge')
  acknowledgeBetaWelcome(@GetUser() user: AuthenticatedUser) {
    return this.lobbyService.acknowledgeBetaWelcome(user.id);
  }
}
