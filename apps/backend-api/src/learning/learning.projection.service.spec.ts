import { Logger } from '@nestjs/common';
import { LearningProjectionService } from './learning.projection.service';
import { LearningRepository } from './learning.repository';

describe('background learning refresh', () => {
  it('returns immediately, coalesces requests, and refreshes again for new work', async () => {
    const service = new LearningProjectionService({} as LearningRepository);
    let finish!: () => void;
    const pending = new Promise<void>((resolve) => { finish = resolve; });
    const rebuild = jest.spyOn(service, 'rebuildUserTarget')
      .mockReturnValueOnce(pending).mockResolvedValue(undefined);

    expect(service.scheduleUserRebuild('user-1', 'cpns')).toBeUndefined();
    service.scheduleUserRebuild('user-1', 'cpns');
    service.scheduleUserRebuild('user-1', 'cpns');
    expect(rebuild).toHaveBeenCalledTimes(1);
    finish();
    await pending;
    await Promise.resolve();
    expect(rebuild).toHaveBeenCalledTimes(2);
  });

  it('handles projection failures without rejecting a committed answer', async () => {
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => {});
    try {
      const service = new LearningProjectionService({} as LearningRepository);
      const rebuild = jest.spyOn(service, 'rebuildUserTarget')
        .mockRejectedValueOnce(new Error('database unavailable'))
        .mockResolvedValue(undefined);
      service.scheduleUserRebuild('user-1', 'cpns');
      await Promise.resolve();
      await Promise.resolve();
      expect(warn).toHaveBeenCalled();
      service.scheduleUserRebuild('user-1', 'cpns');
      expect(rebuild).toHaveBeenCalledTimes(2);
      await Promise.resolve();
    } finally {
      warn.mockRestore();
    }
  });

  it('keeps durable jobs for the worker and lets analytics await the refresh', async () => {
    const completeQueuedJobsForUser = jest.fn().mockResolvedValue(undefined);
    const service = new LearningProjectionService({ completeQueuedJobsForUser } as unknown as LearningRepository);
    let finish!: () => void;
    const pending = new Promise<void>((resolve) => { finish = resolve; });
    jest.spyOn(service, 'rebuildUserTarget').mockReturnValue(pending);
    service.scheduleUserRebuild('user-1', 'cpns');
    let settled = false;
    const dashboardWait = service.waitForUserRebuild('user-1', 'cpns').then(() => { settled = true; });
    await Promise.resolve();
    expect(settled).toBe(false);
    finish();
    await dashboardWait;
    expect(settled).toBe(true);
    expect(completeQueuedJobsForUser).not.toHaveBeenCalled();
  });
});
