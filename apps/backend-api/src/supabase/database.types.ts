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

type DatabaseTable<Row> = {
  Row: Row;
  Insert: Partial<Row>;
  Update: Partial<Row>;
  Relationships: [];
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
          energy_balance: number;
          energy_refilled_on: string;
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
          energy_balance?: number;
          energy_refilled_on?: string;
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
          is_pro_exclusive: boolean;
        };
        Insert: TimestampedInsert & {
          id: string;
          type: string;
          name: string;
          description?: string;
          rarity: string;
          coin_price?: number;
          is_active?: boolean;
          is_pro_exclusive?: boolean;
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
      economy_policy_versions: DatabaseTable<{
        id: string;
        policy: Json;
        is_active: boolean;
        created_at: string;
      }>;
      energy_transactions: DatabaseTable<{
        id: string;
        user_id: string;
        delta: number;
        reason: string;
        reference_id: Nullable<string>;
        idempotency_key: string;
        balance_after: number;
        business_date: string;
        created_at: string;
      }>;
      energy_reservations: DatabaseTable<{
        id: string;
        user_id: string;
        mode: string;
        reference_id: string;
        idempotency_key: string;
        amount: number;
        status: string;
        reserve_transaction_id: Nullable<string>;
        release_transaction_id: Nullable<string>;
        expires_at: Nullable<string>;
        committed_at: Nullable<string>;
        released_at: Nullable<string>;
        release_reason: Nullable<string>;
        created_at: string;
      }>;
      pro_entitlement_periods: DatabaseTable<{
        id: string;
        user_id: string;
        plan_id: string;
        source: string;
        status: string;
        starts_at: string;
        ends_at: string;
        selected_skin_id: Nullable<string>;
        coin_transaction_id: Nullable<string>;
        idempotency_key: string;
        request_hash: string;
        created_at: string;
      }>;
      ad_reward_claims: DatabaseTable<{
        id: string;
        user_id: string;
        reward_type: string;
        placement_id: string;
        provider: string;
        provider_transaction_id: string;
        idempotency_key: string;
        business_date: string;
        amount_awarded: number;
        energy_transaction_id: Nullable<string>;
        coin_transaction_id: Nullable<string>;
        created_at: string;
      }>;
      interview_session_charges: DatabaseTable<{
        id: string;
        user_id: string;
        session_id: string;
        amount: number;
        idempotency_key: string;
        request_hash: string;
        coin_transaction_id: string;
        created_at: string;
      }>;
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
      learning_taxonomy_versions: DatabaseTable<{
        id: string;
        schema_version: number;
        content_version: string;
        approval_status: string;
        sme_approved: boolean;
        approver_reference: Nullable<string>;
        effective_at: string;
        created_at: string;
      }>;
      learning_skills: DatabaseTable<{
        taxonomy_version_id: string;
        skill_id: string;
        target: string;
        category: string;
        subcategory: Nullable<string>;
        label: string;
        enabled: boolean;
        disabled_reason: Nullable<string>;
        curriculum_weight: number;
        prerequisite_skill_ids: string[];
        is_required: boolean;
        created_at: string;
      }>;
      question_revisions: DatabaseTable<{
        id: string;
        question_id: string;
        revision: number;
        source_key: string;
        content_version: string;
        content_hash: string;
        target: string;
        category: string;
        subcategory: Nullable<string>;
        prompt: string;
        options: Json;
        correct_option_index: number;
        explanation: string;
        hint: Nullable<string>;
        difficulty: string;
        question_type: string;
        expected_time_ms: Nullable<number>;
        standard_time_limit_ms: number;
        curriculum_weight: number;
        assessment_eligible: boolean;
        quality_state: string;
        is_active: boolean;
        sme_approved: boolean;
        approved_at: Nullable<string>;
        approver_reference: Nullable<string>;
        created_at: string;
      }>;
      question_skill_mappings: DatabaseTable<{
        question_revision_id: string;
        taxonomy_version_id: string;
        skill_id: string;
        mapping_type: string;
        mapping_weight: number;
        approval_status: string;
        approved_at: Nullable<string>;
        approver_reference: Nullable<string>;
        provenance: string;
        created_at: string;
      }>;
      learner_question_exposures: DatabaseTable<{
        user_id: string;
        question_id: string;
        exposure_count: number;
        first_presented_at: string;
        last_presented_at: string;
        last_source: string;
        updated_at: string;
      }>;
      learning_fixture_runs: DatabaseTable<{
        id: string;
        run_key: string;
        user_id: string;
        target: string;
        scenario: string;
        status: string;
        metadata: Json;
        created_at: string;
        invalidated_at: Nullable<string>;
        invalidation_reason: Nullable<string>;
      }>;
      learning_backfill_runs: DatabaseTable<{
        id: string;
        run_key: string;
        source: string;
        dry_run: boolean;
        status: string;
        source_watermark: Json;
        report: Json;
        started_at: string;
        completed_at: Nullable<string>;
        error_message: Nullable<string>;
      }>;
      learning_recommendations: DatabaseTable<{
        id: string;
        user_id: string;
        target: string;
        taxonomy_version_id: Nullable<string>;
        calculation_version: string;
        evidence_classification_version: string;
        objective: string;
        mechanic_mode: string;
        question_selection_type: string;
        skill_ids: string[];
        delivery_policy_id: Nullable<string>;
        availability_runnable: boolean;
        availability_reason: Nullable<string>;
        execution_adapter: Nullable<string>;
        reason_headline: string;
        reason_description: string;
        reason_evidence: Json;
        input_as_of: string;
        input_snapshot: Json;
        generated_at: string;
        expires_at: string;
        status: string;
        created_at: string;
      }>;
      learning_attempts: DatabaseTable<{
        id: string;
        source: string;
        source_attempt_key: string;
        source_payload_hash: string;
        data_fidelity: string;
        fixture_run_id: Nullable<string>;
        user_id: string;
        target: string;
        source_session_key: Nullable<string>;
        recommendation_id: Nullable<string>;
        learning_objective: Nullable<string>;
        requested_mechanic_mode: Nullable<string>;
        effective_mechanic_mode: Nullable<string>;
        question_selection_type: Nullable<string>;
        delivery_policy_id: Nullable<string>;
        assessment_blueprint_version: Nullable<string>;
        pvp_mode: Nullable<string>;
        session_completion_state: Nullable<string>;
        question_id: Nullable<string>;
        question_revision_id: Nullable<string>;
        taxonomy_version_id: Nullable<string>;
        skill_id: Nullable<string>;
        content_version: Nullable<string>;
        category: Nullable<string>;
        subcategory: Nullable<string>;
        difficulty: Nullable<string>;
        expected_time_ms: Nullable<number>;
        standard_time_limit_ms: Nullable<number>;
        curriculum_weight: Nullable<number>;
        question_quality_state: Nullable<string>;
        selected_option_index: Nullable<number>;
        is_correct: Nullable<boolean>;
        hint_requested: Nullable<boolean>;
        timed_out: Nullable<boolean>;
        first_attempt: Nullable<boolean>;
        seen_before: Nullable<boolean>;
        exposure_count_before: Nullable<number>;
        perceived_difficulty: Nullable<string>;
        explanation_viewed: Nullable<boolean>;
        abandonment_context: Nullable<string>;
        opened_at: Nullable<string>;
        answered_at: Nullable<string>;
        deadline_at: Nullable<string>;
        client_active_response_time_ms: Nullable<number>;
        server_elapsed_time_ms: Nullable<number>;
        background_duration_ms: Nullable<number>;
        effective_response_time_ms: Nullable<number>;
        timing_invalidity_reason: Nullable<string>;
        source_event_at: string;
        ingested_at: string;
      }>;
      learning_attempt_classifications: DatabaseTable<{
        attempt_id: string;
        classification_version: string;
        classifier_input_hash: string;
        valid_for_activity_accuracy: boolean;
        valid_for_independent_accuracy: boolean;
        valid_for_unseen_independent_accuracy: boolean;
        valid_for_assisted_accuracy: boolean;
        valid_for_pace_analytics: boolean;
        valid_for_fluency_baseline: boolean;
        valid_for_retention: boolean;
        exclusion_reasons: string[];
        classified_at: string;
      }>;
      learning_attempt_invalidations: DatabaseTable<{
        id: string;
        attempt_id: Nullable<string>;
        question_revision_id: Nullable<string>;
        reason: string;
        invalidated_by: Nullable<string>;
        invalidated_at: string;
        metadata: Json;
      }>;
      learning_projection_jobs: DatabaseTable<{
        id: string;
        user_id: string;
        target: string;
        taxonomy_version_id: Nullable<string>;
        skill_id: Nullable<string>;
        reason: string;
        source_attempt_id: Nullable<string>;
        status: string;
        available_at: string;
        attempt_count: number;
        locked_at: Nullable<string>;
        locked_by: Nullable<string>;
        last_error: Nullable<string>;
        created_at: string;
        updated_at: string;
      }>;
      learner_skill_state: DatabaseTable<{
        user_id: string;
        target: string;
        taxonomy_version_id: string;
        skill_id: string;
        calculation_version: string;
        evidence_classification_version: string;
        status: string;
        activity_correct_count: number;
        activity_attempt_count: number;
        activity_accuracy: Nullable<number>;
        independent_correct_count: number;
        independent_attempt_count: number;
        independent_accuracy: Nullable<number>;
        unseen_correct_count: number;
        unseen_attempt_count: number;
        unique_question_count: number;
        unseen_independent_accuracy: Nullable<number>;
        smoothed_accuracy: Nullable<number>;
        assisted_correct_count: number;
        assisted_attempt_count: number;
        assisted_accuracy: Nullable<number>;
        hint_rate: Nullable<number>;
        independence_gap: Nullable<number>;
        evidence_confidence: string;
        difficulty_level_count: number;
        median_response_time_ms: Nullable<number>;
        pace_ratio: Nullable<number>;
        pace_baseline_type: Nullable<string>;
        pace_attempt_count: number;
        timeout_rate: Nullable<number>;
        trend_percentage_points: Nullable<number>;
        coverage_sufficient: boolean;
        recommended_mechanic: string;
        latest_eligible_at: Nullable<string>;
        last_practiced_at: Nullable<string>;
        latest_strong_evidence_at: Nullable<string>;
        input_as_of: string;
        attempt_watermark: Nullable<string>;
        created_at: string;
        updated_at: string;
      }>;
      retention_schedules: DatabaseTable<{
        id: string;
        user_id: string;
        target: string;
        taxonomy_version_id: string;
        skill_id: string;
        calculation_version: string;
        strong_evidence_at: string;
        review_due_at: string;
        status: string;
        satisfied_attempt_id: Nullable<string>;
        retention_correct_count: number;
        retention_attempt_count: number;
        retention_accuracy: Nullable<number>;
        created_at: string;
        updated_at: string;
      }>;
      recommendation_events: DatabaseTable<{
        id: string;
        recommendation_id: string;
        user_id: string;
        event_type: string;
        dismissal_reason: Nullable<string>;
        idempotency_key: string;
        event_source: string;
        source_session_key: Nullable<string>;
        result_snapshot: Nullable<Json>;
        occurred_at: string;
        created_at: string;
      }>;
      assessment_evidence: DatabaseTable<{
        id: string;
        source_attempt_key: string;
        user_id: string;
        target: string;
        assessment_session_key: string;
        blueprint_version: string;
        validation_status: string;
        score: Nullable<number>;
        correct_count: Nullable<number>;
        attempt_count: Nullable<number>;
        category_breakdown: Json;
        skill_breakdown: Json;
        occurred_at: string;
        ingested_at: string;
        raw_snapshot: Json;
      }>;
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
          recommendation_id: Nullable<string>;
          taxonomy_version_id: Nullable<string>;
          learning_objective: Nullable<string>;
          requested_mechanic_mode: Nullable<string>;
          effective_mechanic_mode: Nullable<string>;
          question_selection_type: Nullable<string>;
          evidence_capture_version: string;
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
          recommendation_id?: Nullable<string>;
          taxonomy_version_id?: Nullable<string>;
          learning_objective?: Nullable<string>;
          requested_mechanic_mode?: Nullable<string>;
          effective_mechanic_mode?: Nullable<string>;
          question_selection_type?: Nullable<string>;
          evidence_capture_version?: string;
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
          question_revision_id: Nullable<string>;
          taxonomy_version_id: Nullable<string>;
          skill_id: Nullable<string>;
          exposure_count_before: Nullable<number>;
          seen_before: Nullable<boolean>;
          hint_requested_at: Nullable<string>;
          hint_idempotency_key: Nullable<string>;
          opened_at: Nullable<string>;
        };
        Insert: {
          id?: string;
          session_id: string;
          question_id: string;
          question_order: number;
          created_at?: string;
          question_revision_id?: Nullable<string>;
          taxonomy_version_id?: Nullable<string>;
          skill_id?: Nullable<string>;
          exposure_count_before?: Nullable<number>;
          seen_before?: Nullable<boolean>;
          hint_requested_at?: Nullable<string>;
          hint_idempotency_key?: Nullable<string>;
          opened_at?: Nullable<string>;
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
          canonical_attempt_id: Nullable<string>;
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
          canonical_attempt_id?: Nullable<string>;
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
          last_streak_date: Nullable<string>;
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
      enqueue_learning_projection: {
        Args: {
          p_user_id: string;
          p_target: string;
          p_taxonomy_version_id?: Nullable<string>;
          p_skill_id?: Nullable<string>;
          p_reason: string;
          p_source_attempt_id?: Nullable<string>;
        };
        Returns: string;
      };
      create_practice_session_learning_v2: {
        Args: {
          p_user_id: string;
          p_category?: Nullable<string>;
          p_subcategory?: Nullable<string>;
          p_recommendation_id?: Nullable<string>;
        };
        Returns: Json;
      };
      request_practice_hint_learning_v2: {
        Args: {
          p_user_id: string;
          p_session_id: string;
          p_session_question_id: string;
          p_idempotency_key: string;
          p_requested_at?: string;
        };
        Returns: Json;
      };
      submit_practice_answer_learning_v2: {
        Args: {
          p_user_id: string;
          p_session_id: string;
          p_idempotency_key: string;
          p_session_question_id: string;
          p_selected_option_index: number;
          p_response_time_ms?: Nullable<number>;
          p_answered_at?: string;
        };
        Returns: Json;
      };
      finish_practice_session_learning_v2: {
        Args: {
          p_user_id: string;
          p_session_id: string;
          p_idempotency_key: string;
          p_completed_at?: string;
        };
        Returns: Json;
      };
      claim_learning_projection_jobs: {
        Args: {
          p_worker_id: string;
          p_limit?: number;
          p_now?: string;
        };
        Returns: Json;
      };
      ingest_pvp_learning_evidence: {
        Args: { p_match_result_id: string };
        Returns: Json;
      };
      reconcile_recent_pvp_learning_evidence: {
        Args: { p_since?: string; p_limit?: number };
        Returns: Json;
      };
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
      grant_beta_credit: {
        Args: {
          p_user_id: string;
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
      get_economy_state: {
        Args: { p_user_id: string; p_at?: string };
        Returns: Json;
      };
      purchase_energy_pack: {
        Args: {
          p_user_id: string;
          p_package_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      activate_pro_beta: {
        Args: {
          p_user_id: string;
          p_plan_id: string;
          p_skin_id: Nullable<string>;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      claim_verified_ad_reward: {
        Args: {
          p_user_id: string;
          p_reward_type: string;
          p_placement_id: string;
          p_provider: string;
          p_provider_transaction_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      create_interview_session_with_charge: {
        Args: {
          p_user_id: string;
          p_idempotency_key: string;
          p_company_id: string;
          p_target_role: string;
          p_mode: string;
          p_language: string;
          p_response_style: string;
          p_context_snapshot: Json;
          p_opening_question: string;
        };
        Returns: Json;
      };
      reserve_energy: {
        Args: {
          p_user_id: string;
          p_mode: string;
          p_reference_id: string;
          p_idempotency_key: string;
          p_ttl_seconds?: number;
          p_commit_immediately?: boolean;
        };
        Returns: Json;
      };
      commit_energy_reservation: {
        Args: {
          p_user_id: string;
          p_mode: string;
          p_reference_id?: Nullable<string>;
        };
        Returns: Json;
      };
      release_energy_reservation: {
        Args: {
          p_user_id: string;
          p_mode: string;
          p_reason: string;
          p_reference_id?: Nullable<string>;
        };
        Returns: Json;
      };
      release_expired_energy_reservations: {
        Args: {
          p_limit?: number;
        };
        Returns: number;
      };
      grant_completion_energy: {
        Args: {
          p_user_id: string;
          p_reference_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
