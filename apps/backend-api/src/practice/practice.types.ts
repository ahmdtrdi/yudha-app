import type { Json } from '../supabase/database.types';

export const PRACTICE_QUESTION_COUNT = 5;

export type PracticeTarget = 'cpns' | 'bumn' | 'kedinasan';

export interface PracticeSessionRow {
  id: string;
  user_id: string;
  target: PracticeTarget;
  category: string | null;
  subcategory: string | null;
  total_questions: number;
  correct_count: number;
  total_score: number;
  accuracy: number;
  started_at: string;
  finished_at: string | null;
  recommendation_id?: string | null;
  taxonomy_version_id?: string | null;
  learning_objective?: string | null;
  requested_mechanic_mode?: string | null;
  effective_mechanic_mode?: string | null;
  question_selection_type?: string | null;
  evidence_capture_version?: string;
}

export interface PracticeQuestionRow {
  id: string;
  target: PracticeTarget;
  category: string;
  subcategory: string | null;
  prompt: string;
  options: Json;
  correct_option_index: number;
  explanation: string | null;
  difficulty: string;
  weight: number;
  effect: string;
  damage_value: number;
  heal_value: number;
  time_limit_seconds: number;
  hint: string | null;
}

export interface PracticeSessionQuestionRow {
  id: string;
  session_id: string;
  question_id: string;
  question_order: number;
  created_at: string;
  question_revision_id?: string | null;
  taxonomy_version_id?: string | null;
  skill_id?: string | null;
  exposure_count_before?: number | null;
  seen_before?: boolean | null;
  hint_requested_at?: string | null;
  hint_idempotency_key?: string | null;
  opened_at?: string | null;
}

export interface PracticeAnswerRow {
  id: string;
  session_id: string;
  user_id: string;
  session_question_id: string | null;
  question_id: string | null;
  question_order: number | null;
  selected_option_index: number | null;
  is_correct: boolean;
  used_hint: boolean;
  response_time_ms: number | null;
  answered_at: string;
  created_at: string;
  canonical_attempt_id?: string | null;
}

export interface SessionQuestionDetail {
  sessionQuestion: PracticeSessionQuestionRow;
  question: PracticeQuestionRow;
  answer: PracticeAnswerRow | null;
}
