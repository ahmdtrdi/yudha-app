import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import {
  CreateSoloSessionDto,
  FinishSoloSessionDto,
  OpenSoloQuestionDto,
  RequestSoloHintDto,
  SubmitSoloAnswerDto,
} from './solo.dto';
import { SoloService } from './solo.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('solo')
@UseGuards(SupabaseAuthGuard)
export class SoloController {
  constructor(private readonly service: SoloService) {}

  @Post('sessions')
  create(
    @GetUser() user: AuthenticatedUser,
    @Body() input: CreateSoloSessionDto,
  ) {
    return this.service.createSession(user.id, input);
  }

  @Post('sessions/:sessionId/questions/:sessionQuestionId/hint')
  hint(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Param('sessionQuestionId') sessionQuestionId: string,
    @Body() input: RequestSoloHintDto,
  ) {
    return this.service.requestHint(
      user.id,
      sessionId,
      sessionQuestionId,
      input,
    );
  }

  @Get('sessions/:sessionId')
  get(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
  ) {
    return this.service.getSession(user.id, sessionId);
  }

  @Get('active-session')
  active(@GetUser() user: AuthenticatedUser) {
    return this.service.getActiveSession(user.id);
  }

  @Post('sessions/:sessionId/questions/:sessionQuestionId/open')
  open(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Param('sessionQuestionId') sessionQuestionId: string,
    @Body() input: OpenSoloQuestionDto,
  ) {
    return this.service.openQuestion(
      user.id,
      sessionId,
      sessionQuestionId,
      input,
    );
  }

  @Post('sessions/:sessionId/answers')
  answer(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Body() input: SubmitSoloAnswerDto,
  ) {
    return this.service.submitAnswer(user.id, sessionId, input);
  }

  @Post('sessions/:sessionId/finish')
  finish(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Body() input: FinishSoloSessionDto,
  ) {
    return this.service.finishSession(user.id, sessionId, input);
  }
}
