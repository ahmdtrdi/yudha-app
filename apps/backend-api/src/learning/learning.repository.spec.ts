import { SupabaseService } from '../supabase/supabase.service';
import { LearningRepository } from './learning.repository';

describe('LearningRepository recommendation expiry', () => {
  function setup() {
    const calls: string[] = [];
    const query: any = {};
    query.select = jest.fn(() => query);
    query.eq = jest.fn(() => query);
    query.lte = jest.fn(() => query);
    query.limit = jest.fn().mockResolvedValue({
      data: [{ id: 'recommendation-1', user_id: 'user-1', target: 'cpns' }],
      error: null,
    });
    query.update = jest.fn(() => {
      calls.push('expire');
      return query;
    });
    const rpc = jest.fn(async (_name: string, args: any) => {
      calls.push('queue');
      if (
        (args.p_taxonomy_version_id === null) !==
        (args.p_skill_id === null)
      ) {
        return {
          error: { message: 'taxonomy and skill must be supplied together' },
        };
      }
      return { data: 'job-1', error: null };
    });
    const repository = new LearningRepository({
      getClient: () => ({ from: () => query, rpc }),
    } as unknown as SupabaseService);
    return { repository, query, rpc, calls };
  }

  it('queues a whole-user rebuild before expiring the recommendation', async () => {
    const { repository, rpc, calls } = setup();
    await expect(
      repository.expireRecommendationsAndQueue(new Date()),
    ).resolves.toBe(1);
    expect(rpc).toHaveBeenCalledWith('enqueue_learning_projection', {
      p_user_id: 'user-1',
      p_target: 'cpns',
      p_taxonomy_version_id: null,
      p_skill_id: null,
      p_reason: 'recommendation_expired',
      p_source_attempt_id: null,
    });
    expect(calls).toEqual(['queue', 'expire']);
  });

  it('leaves the recommendation active for retry if enqueue fails', async () => {
    const { repository, rpc, query } = setup();
    rpc.mockResolvedValueOnce({ error: { message: 'queue unavailable' } });
    await expect(
      repository.expireRecommendationsAndQueue(new Date()),
    ).rejects.toThrow('queue unavailable');
    expect(query.update).not.toHaveBeenCalled();
  });
});
