import {
  BadRequestException,
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import type { Database } from '../supabase/database.types';
import type {
  PracticeAnswerRow,
  PracticeQuestionRow,
  PracticeSessionQuestionRow,
  PracticeSessionRow,
  PracticeTarget,
} from './practice.types';

type PracticeSessionInsert =
  Database['public']['Tables']['practice_sessions']['Insert'];
type PracticeSessionUpdate =
  Database['public']['Tables']['practice_sessions']['Update'];
type PracticeSessionQuestionInsert =
  Database['public']['Tables']['practice_session_questions']['Insert'];
type PracticeAnswerInsert =
  Database['public']['Tables']['practice_answers']['Insert'];

@Injectable()
export class PracticeRepository {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getUserTarget(userId: string): Promise<PracticeTarget> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('profiles')
      .select('target')
      .eq('id', userId)
      .single<{ target: PracticeTarget }>();

    if (error || !data) {
      if (error?.code === 'PGRST116') {
        throw new NotFoundException('Profile not found.');
      }
      throw new InternalServerErrorException(
        error?.message ?? 'Failed to load profile target.',
      );
    }

    return data.target;
  }

  async createTransactionalSession(
    userId: string,
    category: string | null,
    subcategory: string | null,
  ): Promise<Record<string, any>> {
    return this.callJsonRpc('create_practice_session', {
      p_user_id: userId,
      p_category: category,
      p_subcategory: subcategory,
    });
  }

  async submitTransactionalAnswer(input: {
    userId: string;
    sessionId: string;
    idempotencyKey: string;
    sessionQuestionId: string;
    selectedOptionIndex: number;
    responseTimeMs: number | null;
    usedHint: boolean;
  }): Promise<Record<string, any>> {
    return this.callJsonRpc('submit_practice_answer', {
      p_user_id: input.userId,
      p_session_id: input.sessionId,
      p_idempotency_key: input.idempotencyKey,
      p_session_question_id: input.sessionQuestionId,
      p_selected_option_index: input.selectedOptionIndex,
      p_response_time_ms: input.responseTimeMs,
      p_used_hint: input.usedHint,
    });
  }

  async finishTransactionalSession(
    userId: string,
    sessionId: string,
    idempotencyKey: string,
  ): Promise<Record<string, any>> {
    return this.callJsonRpc('finish_practice_session', {
      p_user_id: userId,
      p_session_id: sessionId,
      p_idempotency_key: idempotencyKey,
    });
  }

  async listActiveQuestions(
    target: PracticeTarget,
    category?: string,
    subcategory?: string | null,
  ): Promise<PracticeQuestionRow[]> {
    let query = this.supabaseService
      .getClient()
      .from('questions')
      .select(
        [
          'id',
          'target',
          'category',
          'subcategory',
          'prompt',
          'options',
          'correct_option_index',
          'explanation',
          'difficulty',
          'weight',
          'effect',
          'damage_value',
          'heal_value',
          'time_limit_seconds',
          'hint',
        ].join(', '),
      )
      .eq('is_active', true)
      .eq('target', target);

    if (category) {
      query = query.eq('category', category);
    }

    if (subcategory !== undefined) {
      query =
        subcategory === null
          ? query.is('subcategory', null)
          : query.eq('subcategory', subcategory);
    }

    const { data, error } = await query.returns<PracticeQuestionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? [];
  }

  async createSession(
    values: PracticeSessionInsert,
  ): Promise<PracticeSessionRow> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_sessions')
      .insert(values)
      .select()
      .single<PracticeSessionRow>();

    if (error || !data) {
      throw new InternalServerErrorException(
        error?.message ?? 'Failed to create practice session.',
      );
    }

    return data;
  }

  async addSessionQuestions(
    values: PracticeSessionQuestionInsert[],
  ): Promise<PracticeSessionQuestionRow[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_session_questions')
      .insert(values)
      .select()
      .returns<PracticeSessionQuestionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return (data ?? []).sort(
      (left, right) => left.question_order - right.question_order,
    );
  }

  async getOwnedSession(
    sessionId: string,
    userId: string,
  ): Promise<PracticeSessionRow> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_sessions')
      .select()
      .eq('id', sessionId)
      .eq('user_id', userId)
      .single<PracticeSessionRow>();

    if (error || !data) {
      if (error?.code === 'PGRST116') {
        throw new NotFoundException('Practice session not found.');
      }
      throw new InternalServerErrorException(
        error?.message ?? 'Failed to load practice session.',
      );
    }

    return data;
  }

  async listSessionQuestions(
    sessionId: string,
  ): Promise<PracticeSessionQuestionRow[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_session_questions')
      .select()
      .eq('session_id', sessionId)
      .order('question_order', { ascending: true })
      .returns<PracticeSessionQuestionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? [];
  }

  async listQuestionsByIds(
    questionIds: string[],
  ): Promise<PracticeQuestionRow[]> {
    if (questionIds.length === 0) {
      return [];
    }

    const { data, error } = await this.supabaseService
      .getClient()
      .from('questions')
      .select(
        [
          'id',
          'target',
          'category',
          'subcategory',
          'prompt',
          'options',
          'correct_option_index',
          'explanation',
          'difficulty',
          'weight',
          'effect',
          'damage_value',
          'heal_value',
          'time_limit_seconds',
          'hint',
        ].join(', '),
      )
      .in('id', questionIds)
      .returns<PracticeQuestionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? [];
  }

  async listAnswersForSession(
    sessionId: string,
    userId: string,
  ): Promise<PracticeAnswerRow[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_answers')
      .select()
      .eq('session_id', sessionId)
      .eq('user_id', userId)
      .returns<PracticeAnswerRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? [];
  }

  async insertAnswer(values: PracticeAnswerInsert): Promise<PracticeAnswerRow> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_answers')
      .insert(values)
      .select()
      .single<PracticeAnswerRow>();

    if (error || !data) {
      if (error?.code === '23505') {
        throw new ConflictException('Practice question already answered.');
      }
      throw new InternalServerErrorException(
        error?.message ?? 'Failed to save practice answer.',
      );
    }

    return data;
  }

  async updateOwnedSession(
    sessionId: string,
    userId: string,
    values: PracticeSessionUpdate,
  ): Promise<void> {
    const { error } = await this.supabaseService
      .getClient()
      .from('practice_sessions')
      .update(values)
      .eq('id', sessionId)
      .eq('user_id', userId);

    if (error) {
      throw new InternalServerErrorException(error.message);
    }
  }

  async listOwnedSessions(
    userId: string,
    target: PracticeTarget,
    options: {
      category?: string;
      subcategory?: string;
      limit: number;
      offset: number;
    },
  ): Promise<PracticeSessionRow[]> {
    let query = this.supabaseService
      .getClient()
      .from('practice_sessions')
      .select()
      .eq('user_id', userId)
      .eq('target', target);

    if (options.category) {
      query = query.eq('category', options.category);
    }

    if (options.subcategory) {
      query = query.eq('subcategory', options.subcategory);
    }

    const { data, error } = await query
      .order('started_at', { ascending: false })
      .range(options.offset, options.offset + options.limit - 1)
      .returns<PracticeSessionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? [];
  }

  async listRecentOwnedSessions(
    userId: string,
    target: PracticeTarget,
    limit: number,
  ): Promise<PracticeSessionRow[]> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_sessions')
      .select()
      .eq('user_id', userId)
      .eq('target', target)
      .order('started_at', { ascending: false })
      .limit(limit)
      .returns<PracticeSessionRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? [];
  }

  async countOwnedSessions(
    userId: string,
    target: PracticeTarget,
    options: { category?: string; subcategory?: string },
  ): Promise<number> {
    let query = this.supabaseService
      .getClient()
      .from('practice_sessions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('target', target);
    if (options.category) query = query.eq('category', options.category);
    if (options.subcategory)
      query = query.eq('subcategory', options.subcategory);
    const { count, error } = await query;
    if (error) throw new InternalServerErrorException(error.message);
    return count ?? 0;
  }

  async getActiveOwnedSession(
    userId: string,
    target: PracticeTarget,
  ): Promise<PracticeSessionRow | null> {
    const { data, error } = await this.supabaseService
      .getClient()
      .from('practice_sessions')
      .select()
      .eq('user_id', userId)
      .eq('target', target)
      .is('finished_at', null)
      .order('started_at', { ascending: false })
      .limit(1)
      .maybeSingle<PracticeSessionRow>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return data ?? null;
  }

  private async callJsonRpc(
    name: string,
    parameters: Record<string, unknown>,
  ): Promise<Record<string, any>> {
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
}
