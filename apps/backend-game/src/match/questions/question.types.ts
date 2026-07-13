import type { CardEffect, PublicQuestionCard } from '../../../../../contracts/question-card';

export type InternalCard = PublicQuestionCard & {
  correctOptionIndex: number;
  explanation?: string;
  damageValue: number;
  healValue: number;
  timeLimitSeconds: number;
};

/** Shape of a row from the Supabase `questions` table (server-side read) */
export type SupabaseQuestionRow = {
  id: string;
  category: string;
  subcategory?: string;
  prompt: string;
  options: string[];
  correct_option_index: number;
  explanation?: string;
  difficulty?: number;
  weight: number;
  effect: CardEffect;
  damage_value: number;
  heal_value: number;
  time_limit_seconds: number;
  hint?: string;
  target: 'cpns' | 'bumn';
  is_active: boolean;
};

/** Category distribution config for building balanced match pools */
export type CategoryDistribution = {
  TWK: number;
  TIU: number;
  TKP: number;
};
