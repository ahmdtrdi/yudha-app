import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { LearningDashboardQueryDto } from './dto/learning-dashboard-query.dto';
import { RecommendationEventDto } from './dto/recommendation-event.dto';
import { LearningService } from './learning.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('learning')
@UseGuards(SupabaseAuthGuard)
export class LearningController {
  constructor(private readonly learningService: LearningService) {}

  @Get('dashboard')
  getDashboard(
    @GetUser() user: AuthenticatedUser,
    @Query() query: LearningDashboardQueryDto,
  ) {
    return this.learningService.getDashboard(user.id, query.window);
  }

  @Get('recommendations/current')
  getCurrentRecommendation(@GetUser() user: AuthenticatedUser) {
    return this.learningService.getCurrentRecommendation(user.id);
  }

  @Post('recommendations/:recommendationId/events')
  recordRecommendationEvent(
    @GetUser() user: AuthenticatedUser,
    @Param('recommendationId') recommendationId: string,
    @Body() input: RecommendationEventDto,
  ) {
    return this.learningService.recordRecommendationEvent(
      user.id,
      recommendationId,
      input,
    );
  }
}
