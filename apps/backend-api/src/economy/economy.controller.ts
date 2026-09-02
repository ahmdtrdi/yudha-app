import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { EconomyService } from './economy.service';
import type {
  ClaimAdRewardPayload,
  PurchaseEnergyPayload,
} from './economy.types';

@Controller('economy')
@UseGuards(SupabaseAuthGuard)
export class EconomyController {
  constructor(private readonly economy: EconomyService) {}

  @Get()
  getState(@GetUser() user: { id: string }) {
    return this.economy.getState(user.id);
  }

  @Get('catalog')
  getCatalog() {
    return this.economy.getCatalog();
  }

  @Post('energy-purchases')
  purchaseEnergy(
    @GetUser() user: { id: string },
    @Body() payload: PurchaseEnergyPayload,
  ) {
    return this.economy.purchaseEnergy(user.id, payload);
  }

  @Post('ad-rewards/claims')
  claimAdReward(
    @GetUser() user: { id: string },
    @Body() payload: ClaimAdRewardPayload,
  ) {
    return this.economy.claimAdReward(user.id, payload);
  }
}
