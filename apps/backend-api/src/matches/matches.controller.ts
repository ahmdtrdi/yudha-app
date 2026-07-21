import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { MatchesService } from './matches.service';
import type { MatchHistoryQuery } from './matches.types';

interface AuthenticatedUser {
  id: string;
}

@Controller('matches')
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Get()
  @UseGuards(SupabaseAuthGuard)
  getHistory(@GetUser() user: AuthenticatedUser, @Query() query: MatchHistoryQuery) {
    return this.matchesService.getHistory(user.id, query);
  }
}
