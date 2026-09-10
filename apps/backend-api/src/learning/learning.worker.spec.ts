import { Logger } from '@nestjs/common';
import { LearningProjectionService } from './learning.projection.service';
import { LearningRepository } from './learning.repository';
import { LearningProjectionWorker } from './learning.worker';

describe('LearningProjectionWorker failure isolation', () => {
  const originalFlag = process.env.LEARNING_V2_ENABLED;
  beforeEach(() => {
    process.env.LEARNING_V2_ENABLED = 'true';
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
  });
  afterEach(() => {
    if (originalFlag === undefined) delete process.env.LEARNING_V2_ENABLED;
    else process.env.LEARNING_V2_ENABLED = originalFlag;
    jest.restoreAllMocks();
  });

  it('drains queued evidence even when recommendation expiry fails', async () => {
    const repository = {
      markDueRetentionAndQueue: jest.fn().mockResolvedValue(0),
      expireRecommendationsAndQueue: jest
        .fn()
        .mockRejectedValue(new Error('expiry failed')),
      reconcileRecentPvpEvidence: jest.fn().mockResolvedValue(0),
    };
    const projections = { drain: jest.fn().mockResolvedValue(2) };
    const worker = new LearningProjectionWorker(
      repository as unknown as LearningRepository,
      projections as unknown as LearningProjectionService,
    );
    await worker.run();
    expect(projections.drain).toHaveBeenCalledWith(50, expect.any(Date));
    expect(Logger.prototype.error).toHaveBeenCalledWith(
      'Learning recommendation expiry failed: expiry failed',
    );
    await worker.run();
    expect(projections.drain).toHaveBeenCalledTimes(2);
  });

  it('waits for maintenance to settle and prevents overlapping worker runs', async () => {
    let finish!: (value: number) => void;
    const pending = new Promise<number>((resolve) => {
      finish = resolve;
    });
    const repository = {
      markDueRetentionAndQueue: jest.fn().mockReturnValue(pending),
      expireRecommendationsAndQueue: jest
        .fn()
        .mockRejectedValue(new Error('expiry failed')),
      reconcileRecentPvpEvidence: jest.fn().mockResolvedValue(0),
    };
    const projections = { drain: jest.fn().mockResolvedValue(1) };
    const worker = new LearningProjectionWorker(
      repository as unknown as LearningRepository,
      projections as unknown as LearningProjectionService,
    );
    const first = worker.run();
    await worker.run();
    expect(repository.markDueRetentionAndQueue).toHaveBeenCalledTimes(1);
    expect(projections.drain).not.toHaveBeenCalled();
    finish(0);
    await first;
    expect(projections.drain).toHaveBeenCalledTimes(1);
  });
});
