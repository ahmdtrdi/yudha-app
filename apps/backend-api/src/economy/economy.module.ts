import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { DisabledAdRewardVerifier } from './disabled-ad-reward-verifier';
import { EconomyController } from './economy.controller';
import { EconomyService } from './economy.service';
import { AD_REWARD_VERIFIER } from './economy.types';

@Module({
  imports: [SupabaseModule],
  controllers: [EconomyController],
  providers: [
    EconomyService,
    DisabledAdRewardVerifier,
    {
      provide: AD_REWARD_VERIFIER,
      useExisting: DisabledAdRewardVerifier,
    },
  ],
  exports: [EconomyService],
})
export class EconomyModule {}
