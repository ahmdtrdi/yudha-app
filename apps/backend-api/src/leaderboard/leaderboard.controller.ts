import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { LeaderboardService } from './leaderboard.service';
import type { LeaderboardQuery } from './leaderboard.types';

interface AuthenticatedUser {
  id: string;
}

@Controller('leaderboard')
export class LeaderboardController {
  constructor(private readonly leaderboardService: LeaderboardService) {}

  @Get()
  list(@Query() query: LeaderboardQuery) {
    return this.leaderboardService.list(query);
  }

  @Get('me')
  @UseGuards(SupabaseAuthGuard)
  getMyRank(@GetUser() user: AuthenticatedUser) {
    return this.leaderboardService.getMyRank(user.id);
  }
}
