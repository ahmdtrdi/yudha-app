import { SupabaseService } from '../supabase/supabase.service';
import { SoloRepository } from './solo.repository';

describe('SoloRepository session recovery', () => {
  it('uses the stable payload RPC so pre-alignment sessions remain resumable', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { sessionId: 'solo-1', status: 'active' },
      error: null,
    });
    const supabase = {
      getClient: () => ({ rpc }),
    } as unknown as SupabaseService;
    const repository = new SoloRepository(supabase);

    await repository.getSession('user-1', 'solo-1');

    expect(rpc).toHaveBeenCalledWith('solo_session_payload', {
      p_user_id: 'user-1',
      p_session_id: 'solo-1',
    });
  });

  it('falls back to the pre-alignment answer RPC when the new signature is absent', async () => {
    const rpc = jest
      .fn()
      .mockResolvedValueOnce({
        data: null,
        error: {
          message:
            'Could not find the function public.submit_solo_answer in the schema cache',
        },
      })
      .mockResolvedValueOnce({
        data: { answerResult: { timedOut: true } },
        error: null,
      });
    const supabase = {
      getClient: () => ({ rpc }),
    } as unknown as SupabaseService;
    const repository = new SoloRepository(supabase);

    await repository.submitAnswer({
      userId: 'user-1',
      sessionId: 'solo-1',
      idempotencyKey: 'timeout-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: null,
      clientActiveResponseTimeMs: null,
      backgroundDurationMs: null,
    });

    expect(rpc).toHaveBeenNthCalledWith(
      2,
      'submit_solo_answer',
      expect.objectContaining({ p_used_hint: false }),
    );
  });

  it('supplies every argument required by the Solo hint RPC signature', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { hint: 'Mulai dari selisih.' },
      error: null,
    });
    const supabase = {
      getClient: () => ({ rpc }),
    } as unknown as SupabaseService;
    const repository = new SoloRepository(supabase);

    await repository.requestHint('user-1', 'solo-1', 'sq-2', 'hint-1');

    expect(rpc).toHaveBeenCalledTimes(1);
    const [rpcName, parameters] = rpc.mock.calls[0] as unknown as [
      string,
      Record<string, unknown>,
    ];
    expect(rpcName).toBe('request_solo_hint');
    expect(parameters).toMatchObject({
      p_user_id: 'user-1',
      p_session_id: 'solo-1',
      p_session_question_id: 'sq-2',
      p_idempotency_key: 'hint-1',
    });
    expect(typeof parameters.p_requested_at).toBe('string');
  });
});
