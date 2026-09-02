export interface PurchaseEnergyPayload {
  idempotencyKey?: unknown;
  packageId?: unknown;
}

export interface ClaimAdRewardPayload {
  idempotencyKey?: unknown;
  rewardType?: unknown;
  placementId?: unknown;
  proofToken?: unknown;
}

export type VerifiedAdReward = {
  provider: string;
  providerTransactionId: string;
};

export interface AdRewardVerifier {
  verify(input: {
    userId: string;
    rewardType: 'energy' | 'y_coin';
    placementId: string;
    proofToken: string;
  }): Promise<VerifiedAdReward>;
}

export const AD_REWARD_VERIFIER = Symbol('AD_REWARD_VERIFIER');
