import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { StartInterviewSessionDto } from './dto/start-interview-session.dto';
import { SubmitInterviewTurnDto } from './dto/submit-interview-turn.dto';
import { InterviewService } from './interview.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('interview/sessions')
@UseGuards(SupabaseAuthGuard)
export class InterviewController {
  constructor(private readonly interviewService: InterviewService) {}

  @Post()
  startSession(
    @GetUser() user: AuthenticatedUser,
    @Body() input: StartInterviewSessionDto,
  ) {
    return this.interviewService.startSession(user.id, input);
  }

  @Get()
  listSessions(@GetUser() user: AuthenticatedUser) {
    return this.interviewService.listSessions(user.id);
  }

  @Post(':sessionId/turns')
  submitAnswer(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Body() input: SubmitInterviewTurnDto,
  ) {
    return this.interviewService.submitAnswer(user.id, sessionId, input);
  }

  @Get(':sessionId')
  getSession(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
  ) {
    return this.interviewService.getSession(user.id, sessionId);
  }

  @Post(':sessionId/complete')
  completeSession(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
  ) {
    return this.interviewService.completeSession(user.id, sessionId);
  }
}
