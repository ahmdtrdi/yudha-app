import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { HiredPassService } from './hired-pass.service';
import type {
  ActivateHiredPassPayload,
  ClaimHiredPassPayload,
} from './hired-pass.types';

interface AuthenticatedUser {
  id: string;
}

@Controller('hired-pass')
@UseGuards(SupabaseAuthGuard)
export class HiredPassController {
  constructor(private readonly hiredPassService: HiredPassService) {}

  @Get()
  getStatus(@GetUser() user: AuthenticatedUser) {
    return this.hiredPassService.getStatus(user.id);
  }

  @Post('beta-activate')
  activateBeta(
    @GetUser() user: AuthenticatedUser,
    @Body() payload: ActivateHiredPassPayload,
  ) {
    return this.hiredPassService.activateBeta(user.id, payload);
  }

  @Post('rewards/:rewardId/claim')
  claimReward(
    @GetUser() user: AuthenticatedUser,
    @Param('rewardId') rewardId: string,
    @Body() payload: ClaimHiredPassPayload,
  ) {
    return this.hiredPassService.claimReward(user.id, rewardId, payload);
  }
}

