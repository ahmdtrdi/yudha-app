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
}

export interface SessionQuestionDetail {
  sessionQuestion: PracticeSessionQuestionRow;
  question: PracticeQuestionRow;
  answer: PracticeAnswerRow | null;
}
