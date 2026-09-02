import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { PvpAnalyticsService } from './pvp-analytics.service';
import type { PvpAnalyticsQuery } from './pvp-analytics.types';

interface AuthenticatedUser {
  id: string;
}

@Controller('pvp')
@UseGuards(SupabaseAuthGuard)
export class PvpAnalyticsController {
  constructor(private readonly service: PvpAnalyticsService) {}

  @Get('analytics')
  getDashboard(
    @GetUser() user: AuthenticatedUser,
    @Query() query: PvpAnalyticsQuery,
  ) {
    return this.service.getDashboard(user.id, query);
  }
}
