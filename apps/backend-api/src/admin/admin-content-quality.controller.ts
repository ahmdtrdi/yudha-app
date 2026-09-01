import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import { AdminAuthGuard } from './guards/admin-auth.guard';
import {
  AdminContentQualityService,
  AdminQuestionItem,
  AdminReviewCase,
} from './admin-content-quality.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin/content-quality')
@UseGuards(AdminAuthGuard)
export class AdminContentQualityController {
  constructor(
    private readonly adminService: AdminContentQualityService,
  ) {}

  @Get('questions')
  async getQuestions(
    @Query('target') target?: string,
    @Query('category') category?: string,
    @Query('qualityState') qualityState?: string,
  ): Promise<{ data: AdminQuestionItem[] }> {
    const data = await this.adminService.getQuestions({
      target,
      category,
      qualityState,
    });
    return { data };
  }

  @Get('questions/:questionId')
  async getQuestionById(
    @Param('questionId') questionId: string,
  ): Promise<{ data: AdminQuestionItem }> {
    const data = await this.adminService.getQuestionById(questionId);
    return { data };
  }

  @Post('questions/:questionId/deactivate')
  async deactivateQuestion(
    @Param('questionId') questionId: string,
    @Body() body: { reason: string; invalidateRevision?: boolean },
    @Req() req: AuthenticatedRequest,
  ): Promise<{ success: boolean; question: AdminQuestionItem }> {
    const adminEmail = req.user?.email || 'admin@yudha.app';
    return this.adminService.deactivateQuestion(
      questionId,
      body.reason,
      adminEmail,
      body.invalidateRevision,
    );
  }

  @Post('questions/:questionId/reactivate')
  async reactivateQuestion(
    @Param('questionId') questionId: string,
    @Body() body: { reason: string },
  ): Promise<{ success: boolean; question: AdminQuestionItem }> {
    return this.adminService.reactivateQuestion(questionId, body.reason);
  }

  @Get('review-cases')
  async getReviewCases(
    @Query('status') status?: string,
  ): Promise<{ data: AdminReviewCase[] }> {
    const data = await this.adminService.getReviewCases({ status });
    return { data };
  }

  @Post('review-cases')
  async createReviewCase(
    @Body()
    body: {
      questionId: string;
      priority: 'low' | 'medium' | 'high' | 'critical';
      reason: string;
      signals?: string[];
    },
    @Req() req: AuthenticatedRequest,
  ): Promise<{ data: AdminReviewCase }> {
    const adminEmail = req.user?.email || 'admin@yudha.app';
    const data = await this.adminService.createReviewCase(body, adminEmail);
    return { data };
  }

  @Patch('review-cases/:caseId')
  async updateReviewCase(
    @Param('caseId') caseId: string,
    @Body()
    body: {
      status?: 'open' | 'in_review' | 'resolved' | 'dismissed';
      disposition?: string;
      note?: string;
    },
    @Req() req: AuthenticatedRequest,
  ): Promise<{ data: AdminReviewCase }> {
    const adminEmail = req.user?.email || 'admin@yudha.app';
    const data = await this.adminService.updateReviewCase(caseId, body, adminEmail);
    return { data };
  }
}
