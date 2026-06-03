import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import type { Database, Json } from '../../supabase/database.types';
import {
  CompanyContextSnapshot,
  InterviewEvaluation,
  InterviewFinalSummary,
  InterviewSession,
  InterviewSessionStatus,
  InterviewTurn,
} from '../interview.types';

interface InterviewSessionRow {
  id: string;
  user_id: string;
  company_id: string;
  target_role: string;
  mode: string;
  language: string;
  response_style: string;
  status: InterviewSessionStatus;
  context_snapshot: unknown;
  rolling_summary: string;
  final_summary: unknown;
  created_at: string;
  updated_at: string;
}

interface InterviewTurnRow {
  id: string;
  session_id: string;
  role: 'question' | 'answer';
  content: string;
  idempotency_key: string | null;
  parent_turn_id: string | null;
  processing_status: 'pending' | 'completed' | 'failed' | null;
  evaluation: unknown;
  created_at: string;
}

interface CreateSessionInput {
  userId: string;
  companyId: string;
  targetRole: string;
  mode: string;
  language: string;
  responseStyle: string;
  contextSnapshot: CompanyContextSnapshot;
}

type InterviewSessionUpdate =
  Database['public']['Tables']['interview_sessions']['Update'];
type InterviewTurnInsert =
  Database['public']['Tables']['interview_turns']['Insert'];
type InterviewTurnUpdate =
  Database['public']['Tables']['interview_turns']['Update'];

@Injectable()
export class InterviewSessionRepository {
  constructor(private readonly supabaseService: SupabaseService) {}

  async createSession(input: CreateSessionInput): Promise<InterviewSession> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_sessions')
      .insert({
        user_id: input.userId,
        company_id: input.companyId,
        target_role: input.targetRole,
        mode: input.mode,
        language: input.language,
        response_style: input.responseStyle,
        context_snapshot: input.contextSnapshot as unknown as Json,
      })
      .select()
      .single<InterviewSessionRow>();

    if (error || !data) {
      throw new InternalServerErrorException(
        error?.message ?? 'Failed to create interview session.',
      );
    }

    return this.mapSession(data);
  }

  async getOwnedSession(
    sessionId: string,
    userId: string,
  ): Promise<InterviewSession> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_sessions')
      .select()
      .eq('id', sessionId)
      .eq('user_id', userId)
      .single<InterviewSessionRow>();

    if (error || !data) {
      if (error?.code === 'PGRST116') {
        throw new NotFoundException('Interview session not found.');
      }

      throw new InternalServerErrorException(
        error?.message ?? 'Failed to load interview session.',
      );
    }

    return this.mapSession(data);
  }

  async listOwnedSessions(userId: string): Promise<InterviewSession[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_sessions')
      .select()
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .returns<InterviewSessionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return (data ?? []).map((session) => this.mapSession(session));
  }

  async addQuestion(
    sessionId: string,
    content: string,
    parentTurnId: string | null = null,
  ): Promise<InterviewTurn> {
    try {
      return await this.insertTurn({
        session_id: sessionId,
        role: 'question',
        content,
        parent_turn_id: parentTurnId,
      });
    } catch (error) {
      if (error instanceof ConflictException && parentTurnId) {
        const existing = await this.getQuestionForAnswer(parentTurnId);
        if (existing) {
          return existing;
        }
      }

      throw error;
    }
  }

  async claimAnswer(
    sessionId: string,
    content: string,
    idempotencyKey: string,
  ): Promise<{ turn: InterviewTurn; isNew: boolean }> {
    const existing = await this.findAnswerByIdempotencyKey(
      sessionId,
      idempotencyKey,
    );

    if (existing) {
      return { turn: existing, isNew: false };
    }

    try {
      const turn = await this.insertTurn({
        session_id: sessionId,
        role: 'answer',
        content,
        idempotency_key: idempotencyKey,
        processing_status: 'pending',
      });

      return { turn, isNew: true };
    } catch (error) {
      if (error instanceof ConflictException) {
        const claimed = await this.findAnswerByIdempotencyKey(
          sessionId,
          idempotencyKey,
        );

        if (claimed) {
          return { turn: claimed, isNew: false };
        }
      }

      throw error;
    }
  }

  async completeAnswer(
    answerTurnId: string,
    evaluation: InterviewEvaluation,
  ): Promise<void> {
    await this.updateTurn(answerTurnId, {
      processing_status: 'completed',
      evaluation: evaluation as unknown as Json,
    });
  }

  async failAnswer(answerTurnId: string): Promise<void> {
    await this.updateTurn(answerTurnId, {
      processing_status: 'failed',
    });
  }

  async listTurns(sessionId: string, limit = 100): Promise<InterviewTurn[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .select()
      .eq('session_id', sessionId)
      .order('created_at', { ascending: true })
      .limit(limit)
      .returns<InterviewTurnRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return (data ?? []).map((turn) => this.mapTurn(turn));
  }

  async listRecentTurns(
    sessionId: string,
    limit = 6,
  ): Promise<InterviewTurn[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .select()
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .limit(limit)
      .returns<InterviewTurnRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return (data ?? []).reverse().map((turn) => this.mapTurn(turn));
  }

  async getQuestionForAnswer(
    answerTurnId: string,
  ): Promise<InterviewTurn | null> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .select()
      .eq('parent_turn_id', answerTurnId)
      .eq('role', 'question')
      .limit(1)
      .maybeSingle<InterviewTurnRow>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ? this.mapTurn(data) : null;
  }

  async getSessionTurn(
    sessionId: string,
    turnId: string,
  ): Promise<InterviewTurn> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .select()
      .eq('session_id', sessionId)
      .eq('id', turnId)
      .single<InterviewTurnRow>();

    if (error || !data) {
      if (error?.code === 'PGRST116') {
        throw new NotFoundException('Interview turn not found.');
      }

      throw new InternalServerErrorException(
        error?.message ?? 'Failed to load interview turn.',
      );
    }

    return this.mapTurn(data);
  }

  async updateSessionSummary(
    sessionId: string,
    rollingSummary: string,
  ): Promise<void> {
    await this.updateSession(sessionId, { rolling_summary: rollingSummary });
  }

  async completeSession(
    sessionId: string,
    finalSummary: InterviewFinalSummary,
  ): Promise<void> {
    await this.updateSession(sessionId, {
      status: 'completed',
      final_summary: finalSummary as unknown as Json,
    });
  }

  private async findAnswerByIdempotencyKey(
    sessionId: string,
    idempotencyKey: string,
  ): Promise<InterviewTurn | null> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .select()
      .eq('session_id', sessionId)
      .eq('idempotency_key', idempotencyKey)
      .eq('role', 'answer')
      .maybeSingle<InterviewTurnRow>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ? this.mapTurn(data) : null;
  }

  private async insertTurn(
    values: InterviewTurnInsert,
  ): Promise<InterviewTurn> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .insert(values)
      .select()
      .single<InterviewTurnRow>();

    if (error || !data) {
      if (error?.code === '23505') {
        throw new ConflictException(
          'Interview turn conflicts with an existing turn.',
        );
      }

      throw new InternalServerErrorException(
        error?.message ?? 'Failed to save interview turn.',
      );
    }

    return this.mapTurn(data);
  }

  private async updateTurn(
    turnId: string,
    values: InterviewTurnUpdate,
  ): Promise<void> {
    const { error } = await this.supabaseService
      .getClient()
      .from('interview_turns')
      .update(values)
      .eq('id', turnId);

    if (error) {
      throw new InternalServerErrorException(error.message);
    }
  }

  private async updateSession(
    sessionId: string,
    values: InterviewSessionUpdate,
  ): Promise<void> {
    const { error } = await this.supabaseService
      .getClient()
      .from('interview_sessions')
      .update(values)
      .eq('id', sessionId);

    if (error) {
      throw new InternalServerErrorException(error.message);
    }
  }

  private mapSession(row: InterviewSessionRow): InterviewSession {
    return {
      id: row.id,
      userId: row.user_id,
      companyId: row.company_id,
      targetRole: row.target_role,
      mode: row.mode,
      language: row.language,
      responseStyle: row.response_style,
      status: row.status,
      contextSnapshot: row.context_snapshot as CompanyContextSnapshot,
      rollingSummary: row.rolling_summary,
      finalSummary: row.final_summary as InterviewFinalSummary | null,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private mapTurn(row: InterviewTurnRow): InterviewTurn {
    return {
      id: row.id,
      sessionId: row.session_id,
      role: row.role,
      content: row.content,
      idempotencyKey: row.idempotency_key,
      parentTurnId: row.parent_turn_id,
      processingStatus: row.processing_status,
      evaluation: row.evaluation as InterviewEvaluation | null,
      createdAt: row.created_at,
    };
  }
}
