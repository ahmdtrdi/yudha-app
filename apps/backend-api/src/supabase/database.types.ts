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
          draws: number;
          winrate: number;
          coins: number;
          equipped_avatar_id: Nullable<string>;
          equipped_arena_id: Nullable<string>;
          equipped_tower_id: Nullable<string>;
          hired_pass_expires_at: Nullable<string>;
          current_streak: number;
          best_streak: number;
          last_streak_date: Nullable<string>;
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
          draws?: number;
          winrate?: number;
          coins?: number;
          equipped_avatar_id?: Nullable<string>;
          equipped_arena_id?: Nullable<string>;
          equipped_tower_id?: Nullable<string>;
          hired_pass_expires_at?: Nullable<string>;
          current_streak?: number;
          best_streak?: number;
          last_streak_date?: Nullable<string>;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>;
        Relationships: [];
      };
      store_items: {
        Row: TimestampedRow & {
          id: string;
          type: string;
          name: string;
          description: string;
          rarity: string;
          coin_price: number;
          is_active: boolean;
          is_pass_exclusive: boolean;
        };
        Insert: TimestampedInsert & {
          id: string;
          type: string;
          name: string;
          description?: string;
          rarity: string;
          coin_price?: number;
          is_active?: boolean;
          is_pass_exclusive?: boolean;
        };
        Update: Partial<Database['public']['Tables']['store_items']['Insert']>;
        Relationships: [];
      };
      user_inventory: {
        Row: {
          user_id: string;
          item_id: string;
          source: string;
          source_ref: Nullable<string>;
          acquired_at: string;
        };
        Insert: {
          user_id: string;
          item_id: string;
          source: string;
          source_ref?: Nullable<string>;
          acquired_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['user_inventory']['Insert']
        >;
        Relationships: [];
      };
      store_purchases: {
        Row: {
          id: string;
          user_id: string;
          item_id: string;
          idempotency_key: string;
          price_paid: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          item_id: string;
          idempotency_key: string;
          price_paid: number;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['store_purchases']['Insert']
        >;
        Relationships: [];
      };
      coin_transactions: {
        Row: {
          id: string;
          user_id: string;
          delta: number;
          reason: string;
          reference_id: Nullable<string>;
          idempotency_key: string;
          balance_after: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          delta: number;
          reason: string;
          reference_id?: Nullable<string>;
          idempotency_key: string;
          balance_after: number;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['coin_transactions']['Insert']
        >;
        Relationships: [];
      };
      hired_pass_seasons: {
        Row: {
          id: string;
          name: string;
          starts_at: string;
          ends_at: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          name: string;
          starts_at: string;
          ends_at: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['hired_pass_seasons']['Insert']
        >;
        Relationships: [];
      };
      hired_pass_missions: {
        Row: {
          id: string;
          season_id: string;
          title: string;
          description: string;
          event_type: string;
          cadence: string;
          target_count: number;
          points_reward: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id: string;
          season_id: string;
          title: string;
          description: string;
          event_type: string;
          cadence: string;
          target_count: number;
          points_reward: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['hired_pass_missions']['Insert']
        >;
        Relationships: [];
      };
      hired_pass_rewards: {
        Row: {
          id: string;
          season_id: string;
          track: string;
          points_required: number;
          label: string;
          coins_reward: number;
          item_id: Nullable<string>;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id: string;
          season_id: string;
          track: string;
          points_required: number;
          label: string;
          coins_reward?: number;
          item_id?: Nullable<string>;
          is_active?: boolean;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['hired_pass_rewards']['Insert']
        >;
        Relationships: [];
      };
      user_hired_pass_progress: {
        Row: {
          user_id: string;
          season_id: string;
          pass_points: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          season_id: string;
          pass_points?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['user_hired_pass_progress']['Insert']
        >;
        Relationships: [];
      };
      user_hired_pass_mission_progress: {
        Row: {
          user_id: string;
          mission_id: string;
          period_start: string;
          progress_count: number;
          completed_at: Nullable<string>;
          points_awarded_at: Nullable<string>;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          mission_id: string;
          period_start: string;
          progress_count?: number;
          completed_at?: Nullable<string>;
          points_awarded_at?: Nullable<string>;
          updated_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['user_hired_pass_mission_progress']['Insert']
        >;
        Relationships: [];
      };
      user_hired_pass_reward_claims: {
        Row: {
          user_id: string;
          reward_id: string;
          coins_awarded: number;
          item_id: Nullable<string>;
          claimed_at: string;
        };
        Insert: {
          user_id: string;
          reward_id: string;
          coins_awarded?: number;
          item_id?: Nullable<string>;
          claimed_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['user_hired_pass_reward_claims']['Insert']
        >;
        Relationships: [];
      };
      questions: {
        Row: TimestampedRow & {
          id: string;
          source_key: string;
          content_hash: Nullable<string>;
          target: string;
          category: string;
          subcategory: Nullable<string>;
          prompt: string;
          options: Json;
          correct_option_index: number;
          explanation: string;
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
          source_key: string;
          content_hash?: Nullable<string>;
          target?: string;
          category: string;
          subcategory?: Nullable<string>;
          prompt: string;
          options: Json;
          correct_option_index: number;
          explanation: string;
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
          idempotency_key: Nullable<string>;
          score_gained: number;
          correct_option_index_snapshot: Nullable<number>;
          explanation_snapshot: Nullable<string>;
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
          idempotency_key?: Nullable<string>;
          score_gained?: number;
          correct_option_index_snapshot?: Nullable<number>;
          explanation_snapshot?: Nullable<string>;
        };
        Update: Partial<
          Database['public']['Tables']['practice_answers']['Insert']
        >;
        Relationships: [];
      };
      api_idempotency_records: {
        Row: {
          id: string;
          user_id: string;
          operation: string;
          idempotency_key: string;
          request_hash: string;
          response: Json;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          operation: string;
          idempotency_key: string;
          request_hash: string;
          response: Json;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['api_idempotency_records']['Insert']
        >;
        Relationships: [];
      };
      rank_point_transactions: {
        Row: {
          id: string;
          user_id: string;
          applied_delta: number;
          requested_delta: number;
          source: string;
          source_id: string;
          idempotency_key: string;
          balance_after: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          applied_delta: number;
          requested_delta: number;
          source: string;
          source_id: string;
          idempotency_key: string;
          balance_after: number;
          created_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['rank_point_transactions']['Insert']
        >;
        Relationships: [];
      };
      daily_mission_progress: {
        Row: {
          user_id: string;
          mission_key: string;
          business_date: string;
          source_type: string;
          source_id: string;
          completed_at: string;
          reward_rank_points: number;
          rank_transaction_id: string;
        };
        Insert: Database['public']['Tables']['daily_mission_progress']['Row'];
        Update: Partial<
          Database['public']['Tables']['daily_mission_progress']['Row']
        >;
        Relationships: [];
      };
      daily_learning_activity: {
        Row: {
          user_id: string;
          business_date: string;
          source_type: string;
          source_id: string;
          completed_at: string;
        };
        Insert: Database['public']['Tables']['daily_learning_activity']['Row'];
        Update: Partial<
          Database['public']['Tables']['daily_learning_activity']['Row']
        >;
        Relationships: [];
      };
      practice_session_completions: {
        Row: {
          session_id: string;
          user_id: string;
          completed_at: string;
          response: Json;
          daily_mission_reward: Nullable<number>;
          rank_points_after: number;
          current_streak: number;
          best_streak: number;
          last_streak_date: string;
          hired_pass_activity_applied: boolean;
        };
        Insert: Database['public']['Tables']['practice_session_completions']['Row'];
        Update: Partial<
          Database['public']['Tables']['practice_session_completions']['Row']
        >;
        Relationships: [];
      };
      notification_preferences: {
        Row: TimestampedRow & {
          user_id: string;
          enabled: boolean;
          morning_enabled: boolean;
          morning_time: string;
          rescue_enabled: boolean;
          rescue_time: string;
        };
        Insert: TimestampedInsert & {
          user_id: string;
          enabled?: boolean;
          morning_enabled?: boolean;
          morning_time?: string;
          rescue_enabled?: boolean;
          rescue_time?: string;
        };
        Update: Partial<
          Database['public']['Tables']['notification_preferences']['Insert']
        >;
        Relationships: [];
      };
      push_installations: {
        Row: TimestampedRow & {
          user_id: string;
          installation_id: string;
          fcm_token: string;
          platform: string;
          time_zone: string;
          authorized: boolean;
          active: boolean;
          last_seen_at: string;
        };
        Insert: TimestampedInsert & {
          user_id: string;
          installation_id: string;
          fcm_token: string;
          platform: string;
          time_zone: string;
          authorized?: boolean;
          active?: boolean;
          last_seen_at?: string;
        };
        Update: Partial<
          Database['public']['Tables']['push_installations']['Insert']
        >;
        Relationships: [];
      };
      notification_deliveries: {
        Row: TimestampedRow & {
          id: string;
          user_id: string;
          installation_id: string;
          kind: string;
          local_date: string;
          business_date: string;
          status: string;
          attempt_count: number;
          next_attempt_at: string;
          lease_until: Nullable<string>;
          expires_at: string;
          fcm_message_id: Nullable<string>;
          last_error: Nullable<string>;
          sent_at: Nullable<string>;
          opened_at: Nullable<string>;
        };
        Insert: TimestampedInsert & {
          id?: string;
          user_id: string;
          installation_id: string;
          kind: string;
          local_date: string;
          business_date: string;
          status?: string;
          attempt_count?: number;
          next_attempt_at?: string;
          lease_until?: Nullable<string>;
          expires_at: string;
          fcm_message_id?: Nullable<string>;
          last_error?: Nullable<string>;
          sent_at?: Nullable<string>;
          opened_at?: Nullable<string>;
        };
        Update: Partial<
          Database['public']['Tables']['notification_deliveries']['Insert']
        >;
        Relationships: [];
      };
      interview_company_profiles: {
        Row: TimestampedRow & {
          id: string;
          name: string;
          summary: string;
          content_version: string;
          default_role: Nullable<string>;
        };
        Insert: TimestampedInsert & {
          id: string;
          name: string;
          summary: string;
          content_version?: string;
          default_role?: Nullable<string>;
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
    Functions: {
      claim_due_notification_deliveries: {
        Args: { p_now?: string; p_limit?: number };
        Returns: Array<{
          delivery_id: string;
          user_id: string;
          installation_id: string;
          fcm_token: string;
          platform: string;
          time_zone: string;
          kind: string;
          local_date: string;
          business_date: string;
          current_streak: number;
          remaining_mission_keys: string[];
          expires_at: string;
          attempt_count: number;
        }>;
      };
      purchase_store_item: {
        Args: {
          p_user_id: string;
          p_item_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      set_profile_loadout: {
        Args: {
          p_user_id: string;
          p_avatar_id?: Nullable<string>;
          p_tower_id?: Nullable<string>;
          p_arena_id?: Nullable<string>;
        };
        Returns: Json;
      };
      grant_beta_credit: {
        Args: {
          p_user_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      claim_hired_pass_reward: {
        Args: {
          p_user_id: string;
          p_reward_id: string;
        };
        Returns: Json;
      };
      claim_hired_pass_reward_idempotent: {
        Args: {
          p_user_id: string;
          p_reward_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      activate_hired_pass_beta: {
        Args: {
          p_user_id: string;
          p_season_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      record_hired_pass_activity: {
        Args: {
          p_user_id: string;
          p_event_type: string;
          p_source_id: string;
          p_occurred_at?: string;
        };
        Returns: Json;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
