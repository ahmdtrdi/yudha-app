import { ForbiddenException, Injectable } from '@nestjs/common';
import type { AdRewardVerifier } from './economy.types';

@Injectable()
export class DisabledAdRewardVerifier implements AdRewardVerifier {
  verify(): Promise<never> {
    throw new ForbiddenException(
      'FEATURE_DISABLED: Rewarded-ad verification is not configured.',
    );
  }
}
