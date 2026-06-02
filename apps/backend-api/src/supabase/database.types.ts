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
          rank_points: number;
          total_matches: number;
          wins: number;
          losses: number;
          winrate: number;
          coins: number;
          equipped_avatar_id: Nullable<string>;
          equipped_arena_id: Nullable<string>;
        };
        Insert: {
          id: string;
          username?: Nullable<string>;
          rank_points?: number;
          total_matches?: number;
          wins?: number;
          losses?: number;
          winrate?: number;
          coins?: number;
          equipped_avatar_id?: Nullable<string>;
          equipped_arena_id?: Nullable<string>;
        };
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>;
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
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
