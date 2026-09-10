import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { learningV2Enabled } from './learning.constants';
import { LearningProjectionService } from './learning.projection.service';
import { LearningRepository } from './learning.repository';

@Injectable()
export class LearningProjectionWorker {
  private readonly logger = new Logger(LearningProjectionWorker.name);
  private running = false;

  constructor(
    private readonly repository: LearningRepository,
    private readonly projections: LearningProjectionService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async run(): Promise<void> {
    if (!learningV2Enabled() || this.running) return;
    this.running = true;
    try {
      const now = new Date();
      const maintenance = await Promise.allSettled([
        this.repository.markDueRetentionAndQueue(now),
        this.repository.expireRecommendationsAndQueue(now),
        this.repository.reconcileRecentPvpEvidence(now),
      ]);
      const labels = ['retention', 'recommendation expiry', 'PvP ingestion'];
      const [due, expired, pvpAttempts] = maintenance.map((result, index) => {
        if (result.status === 'fulfilled') return result.value;
        this.logger.error(
          `Learning ${labels[index]} failed: ${
            result.reason instanceof Error
              ? result.reason.message
              : String(result.reason)
          }`,
        );
        return 0;
      });
      const projected = await this.projections.drain(50, now);
      if (due + expired + pvpAttempts + projected > 0) {
        this.logger.log(
          `Learning worker: ${due} reviews due, ${expired} recommendations expired, ${pvpAttempts} PvP attempts ingested, ${projected} jobs processed.`,
        );
      }
    } catch (error) {
      this.logger.error(
        error instanceof Error ? error.message : 'Learning worker failed.',
      );
    } finally {
      this.running = false;
    }
  }
}
