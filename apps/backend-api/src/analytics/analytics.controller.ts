import { Controller, Get, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { AnalyticsService } from './analytics.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get()
  @UseGuards(SupabaseAuthGuard)
  getPerformanceAnalytics(@GetUser() user: AuthenticatedUser) {
    return this.analyticsService.getPerformanceAnalytics(user.id);
  }
}
