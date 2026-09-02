import {
  BadRequestException,
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class SoloRepository {
  constructor(private readonly supabaseService: SupabaseService) {}

  createSession(input: {
    userId: string;
    idempotencyKey: string;
    mechanicMode: string;
    questionSelection: string;
    questionCount: number;
    characterId: string;
  }) {
    return this.call('create_solo_session', {
      p_user_id: input.userId,
      p_idempotency_key: input.idempotencyKey,
      p_mechanic_mode: input.mechanicMode,
      p_question_selection: input.questionSelection,
      p_question_count: input.questionCount,
      p_character_id: input.characterId,
    });
  }

  getSession(userId: string, sessionId: string) {
    return this.call('solo_session_payload', {
      p_user_id: userId,
      p_session_id: sessionId,
    });
  }

  getActiveSession(userId: string) {
    return this.call('get_active_solo_session', { p_user_id: userId });
  }

  openQuestion(
    userId: string,
    sessionId: string,
    sessionQuestionId: string,
    idempotencyKey: string,
  ) {
    return this.call('open_solo_question', {
      p_user_id: userId,
      p_session_id: sessionId,
      p_session_question_id: sessionQuestionId,
      p_idempotency_key: idempotencyKey,
    });
  }

  requestHint(
    userId: string,
    sessionId: string,
    sessionQuestionId: string,
    idempotencyKey: string,
  ) {
    return this.call('request_solo_hint', {
      p_user_id: userId,
      p_session_id: sessionId,
      p_session_question_id: sessionQuestionId,
      p_idempotency_key: idempotencyKey,
      p_requested_at: new Date().toISOString(),
    });
  }

  async submitAnswer(input: {
    userId: string;
    sessionId: string;
    idempotencyKey: string;
    sessionQuestionId: string;
    selectedOptionIndex: number | null;
    clientActiveResponseTimeMs: number | null;
    backgroundDurationMs: number | null;
  }) {
    try {
      return await this.call('submit_solo_answer', {
        p_user_id: input.userId,
        p_session_id: input.sessionId,
        p_idempotency_key: input.idempotencyKey,
        p_session_question_id: input.sessionQuestionId,
        p_selected_option_index: input.selectedOptionIndex,
        p_client_active_response_time_ms: input.clientActiveResponseTimeMs,
        p_background_duration_ms: input.backgroundDurationMs,
      });
    } catch (error) {
      if (!this.isMissingAlignedAnswerRpc(error)) throw error;
      return this.call('submit_solo_answer', {
        p_user_id: input.userId,
        p_session_id: input.sessionId,
        p_idempotency_key: input.idempotencyKey,
        p_session_question_id: input.sessionQuestionId,
        p_selected_option_index: input.selectedOptionIndex,
        p_used_hint: false,
      });
    }
  }

  finishSession(userId: string, sessionId: string, idempotencyKey: string) {
    return this.call('finish_solo_session', {
      p_user_id: userId,
      p_session_id: sessionId,
      p_idempotency_key: idempotencyKey,
    });
  }

  private async call(name: string, parameters: Record<string, unknown>) {
    const { data, error } = await (this.supabaseService.getClient() as any).rpc(
      name,
      parameters,
    );
    if (error) this.throwRpcError(error.message);
    if (!data || Array.isArray(data) || typeof data !== 'object') {
      throw new InternalServerErrorException(`${name} returned invalid data.`);
    }
    return data as Record<string, unknown>;
  }

  private throwRpcError(message: string): never {
    if (message.includes('IDEMPOTENCY_KEY_REUSED')) {
      throw new ConflictException('IDEMPOTENCY_KEY_REUSED');
    }
    if (message.includes('NOT_FOUND')) throw new NotFoundException(message);
    if (message.includes('CONFLICT') || message.includes('ACTION_REJECTED')) {
      throw new ConflictException(message);
    }
    if (message.includes('VALIDATION_FAILED')) {
      throw new BadRequestException(message);
    }
    throw new InternalServerErrorException(message);
  }

  private isMissingAlignedAnswerRpc(error: unknown): boolean {
    if (!(error instanceof InternalServerErrorException)) return false;
    const message = error.message.toLowerCase();
    return (
      message.includes('submit_solo_answer') &&
      (message.includes('schema cache') || message.includes('could not find'))
    );
  }
}
