import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { ProService } from './pro.service';
import type { ActivateProPayload } from './pro.types';

@Controller('pro')
@UseGuards(SupabaseAuthGuard)
export class ProController {
  constructor(private readonly pro: ProService) {}

  @Get()
  getStatus(@GetUser() user: { id: string }) {
    return this.pro.getStatus(user.id);
  }

  @Post('beta-activate')
  activateBeta(
    @GetUser() user: { id: string },
    @Body() payload: ActivateProPayload,
  ) {
    return this.pro.activateBeta(user.id, payload);
  }
}
