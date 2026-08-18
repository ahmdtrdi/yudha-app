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
import { CreatePracticeSessionDto } from './dto/create-practice-session.dto';
import { FinishPracticeSessionDto } from './dto/finish-practice-session.dto';
import { PracticeHistoryQueryDto } from './dto/practice-history-query.dto';
import { SubmitPracticeAnswerDto } from './dto/submit-practice-answer.dto';
import { PracticeService } from './practice.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('practice')
@UseGuards(SupabaseAuthGuard)
export class PracticeController {
  constructor(private readonly practiceService: PracticeService) {}

  @Get('dashboard')
  getDashboard(@GetUser() user: AuthenticatedUser) {
    return this.practiceService.getDashboard(user.id);
  }

  @Get('history')
  getHistory(
    @GetUser() user: AuthenticatedUser,
    @Query() query: PracticeHistoryQueryDto,
  ) {
    return this.practiceService.getHistory(user.id, query);
  }

  @Post('sessions')
  createSession(
    @GetUser() user: AuthenticatedUser,
    @Body() input: CreatePracticeSessionDto,
  ) {
    return this.practiceService.createSession(user.id, input);
  }

  @Get('sessions/:sessionId')
  getSession(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
  ) {
    return this.practiceService.getSession(user.id, sessionId);
  }

  @Post('sessions/:sessionId/answers')
  submitAnswer(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Body() input: SubmitPracticeAnswerDto,
  ) {
    return this.practiceService.submitAnswer(user.id, sessionId, input);
  }

  @Post('sessions/:sessionId/finish')
  finishSession(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Body() input: FinishPracticeSessionDto,
  ) {
    return this.practiceService.finishSession(user.id, sessionId, input);
  }
}
