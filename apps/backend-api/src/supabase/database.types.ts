export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

type Nullable<T> = T | null;

type TimestampedRow = {
  created_at: string;
  updated_at: string;
};

type TimestampedInsert = {
  created_at?: string;
  updated_at?: string;
};

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          username: Nullable<string>;
          full_name: Nullable<string>;
          target: string;
          rank_points: number;
          total_matches: number;
          wins: number;
          losses: number;
          winrate: number;
          coins: number;
          equipped_avatar_id: Nullable<string>;
          equipped_arena_id: Nullable<string>;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          username?: Nullable<string>;
          full_name?: Nullable<string>;
          target?: string;
          rank_points?: number;
          total_matches?: number;
          wins?: number;
          losses?: number;
          winrate?: number;
          coins?: number;
          equipped_avatar_id?: Nullable<string>;
          equipped_arena_id?: Nullable<string>;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>;
        Relationships: [];
      };
      questions: {
        Row: TimestampedRow & {
          id: string;
          target: string;
          category: string;
          subcategory: Nullable<string>;
          prompt: string;
          options: Json;
          correct_option_index: number;
          explanation: Nullable<string>;
          difficulty: string;
          weight: number;
          effect: string;
          damage_value: number;
          heal_value: number;
          time_limit_seconds: number;
          hint: Nullable<string>;
          is_active: boolean;
        };
        Insert: TimestampedInsert & {
          id?: string;
          target?: string;
          category: string;
          subcategory?: Nullable<string>;
          prompt: string;
          options: Json;
          correct_option_index: number;
          explanation?: Nullable<string>;
          difficulty?: string;
          weight?: number;
          effect?: string;
          damage_value?: number;
          heal_value?: number;
          time_limit_seconds?: number;
          hint?: Nullable<string>;
          is_active?: boolean;
        };
        Update: Partial<Database['public']['Tables']['questions']['Insert']>;
        Relationships: [];
      };
      practice_sessions: {
        Row: {
          id: string;
          user_id: string;
          target: string;
          category: Nullable<string>;
          subcategory: Nullable<string>;
          total_questions: number;
          correct_count: number;
          total_score: number;
          accuracy: number;
          started_at: string;
          finished_at: Nullable<string>;
        };
        Insert: {
          id?: string;
          user_id: string;
          target?: string;
          category?: Nullable<string>;
          subcategory?: Nullable<string>;
          total_questions?: number;
          correct_count?: number;
          total_score?: number;
          accuracy?: number;
          started_at?: string;
          finished_at?: Nullable<string>;
        };
        Update: Partial<
          Database['public']['Tables']['practice_sessions']['Insert']
        >;
        Relationships: [];
      };
      practice_session_questions: {
        Row: {
          id: string;
          session_id: string;
          question_id: string;
          question_order: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          session_id: string;
          question_id: string;
          question_order: number;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['practice_session_questions']['Insert']
        >;
        Relationships: [];
      };
      practice_answers: {
        Row: {
          id: string;
          session_id: string;
          user_id: string;
          session_question_id: Nullable<string>;
          question_id: Nullable<string>;
          question_order: Nullable<number>;
          selected_option_index: Nullable<number>;
          player_answer: Nullable<string>;
          is_correct: boolean;
          used_hint: boolean;
          response_time_ms: Nullable<number>;
          answered_at: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          session_id: string;
          user_id: string;
          session_question_id?: Nullable<string>;
          question_id?: Nullable<string>;
          question_order?: Nullable<number>;
          selected_option_index?: Nullable<number>;
          player_answer?: Nullable<string>;
          is_correct?: boolean;
          used_hint?: boolean;
          response_time_ms?: Nullable<number>;
          answered_at?: string;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['practice_answers']['Insert']
        >;
        Relationships: [];
      };
      interview_company_profiles: {
        Row: TimestampedRow & {
          id: string;
          name: string;
          summary: string;
          content_version: string;
        };
        Insert: TimestampedInsert & {
          id: string;
          name: string;
          summary: string;
          content_version?: string;
        };
        Update: Partial<
          Database['public']['Tables']['interview_company_profiles']['Insert']
        >;
        Relationships: [];
      };
      interview_company_contexts: {
        Row: TimestampedRow & {
          id: string;
          company_id: string;
          category: string;
          content: string;
          priority: number;
        };
        Insert: TimestampedInsert & {
          id?: string;
          company_id: string;
          category: string;
          content: string;
          priority?: number;
        };
        Update: Partial<
          Database['public']['Tables']['interview_company_contexts']['Insert']
        >;
        Relationships: [];
      };
      interview_sessions: {
        Row: TimestampedRow & {
          id: string;
          user_id: string;
          company_id: string;
          target_role: string;
          mode: string;
          language: string;
          response_style: string;
          status: string;
          context_snapshot: Json;
          rolling_summary: string;
          final_summary: Nullable<Json>;
        };
        Insert: TimestampedInsert & {
          id?: string;
          user_id: string;
          company_id: string;
          target_role: string;
          mode: string;
          language?: string;
          response_style?: string;
          status?: string;
          context_snapshot: Json;
          rolling_summary?: string;
          final_summary?: Nullable<Json>;
        };
        Update: Partial<
          Database['public']['Tables']['interview_sessions']['Insert']
        >;
        Relationships: [];
      };
      interview_turns: {
        Row: {
          id: string;
          session_id: string;
          role: string;
          content: string;
          idempotency_key: Nullable<string>;
          parent_turn_id: Nullable<string>;
          processing_status: Nullable<string>;
          evaluation: Nullable<Json>;
          created_at: string;
        };
        Insert: {
          id?: string;
          session_id: string;
          role: string;
          content: string;
          idempotency_key?: Nullable<string>;
          parent_turn_id?: Nullable<string>;
          processing_status?: Nullable<string>;
          evaluation?: Nullable<Json>;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['interview_turns']['Insert']
        >;
        Relationships: [];
      };
    };
    Views: {
      public_questions: {
        Row: {
          id: string;
          target: string;
          category: string;
          subcategory: Nullable<string>;
          prompt: string;
          options: Json;
          difficulty: string;
          weight: number;
          effect: string;
          damage_value: number;
          heal_value: number;
          time_limit_seconds: number;
          hint: Nullable<string>;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
    };
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
