-- Learning Analytics + Recommendation V2, Phase 1.
--
-- This migration is intentionally additive. It creates the canonical evidence,
-- versioned projection, and recommendation storage required by PRD Section 11
-- without enabling the unresolved Gate 5 Solo delivery policy.

begin;

do $$
declare
  v_missing text[] := array[]::text[];
begin
  if to_regclass('public.profiles') is null then
    v_missing := array_append(v_missing, 'public.profiles');
  end if;
  if to_regclass('public.questions') is null then
    v_missing := array_append(v_missing, 'public.questions');
  end if;
  if to_regclass('public.practice_sessions') is null then
    v_missing := array_append(v_missing, 'public.practice_sessions');
  end if;
  if to_regclass('public.practice_session_questions') is null then
    v_missing := array_append(v_missing, 'public.practice_session_questions');
  end if;
  if to_regclass('public.practice_answers') is null then
    v_missing := array_append(v_missing, 'public.practice_answers');
  end if;
  if to_regprocedure('public.valid_question_options(jsonb)') is null then
    v_missing := array_append(v_missing, 'public.valid_question_options(jsonb)');
  end if;
  if to_regprocedure('public.set_updated_at()') is null then
    v_missing := array_append(v_missing, 'public.set_updated_at()');
  end if;
  if cardinality(v_missing) > 0 then
    raise exception using
      errcode = 'P0001',
      message = 'LEARNING_V2_PRECHECK_FAILED: missing prerequisite tables ' || array_to_string(v_missing, ', ');
  end if;
end;
$$;

create table if not exists public.learning_taxonomy_versions (
  id uuid primary key default gen_random_uuid(),
  schema_version integer not null,
  content_version text not null,
  approval_status text not null,
  sme_approved boolean not null default false,
  approver_reference text,
  effective_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint learning_taxonomy_schema_version_check check (schema_version > 0),
  constraint learning_taxonomy_content_version_check check (btrim(content_version) <> ''),
  constraint learning_taxonomy_approval_status_check check (
    approval_status in ('development', 'sme_approved')
  ),
  constraint learning_taxonomy_approval_consistency_check check (
    (sme_approved and approval_status = 'sme_approved' and nullif(btrim(approver_reference), '') is not null)
    or (not sme_approved and approval_status = 'development')
  ),
  constraint learning_taxonomy_content_version_unique unique (content_version)
);

create table if not exists public.learning_skills (
  taxonomy_version_id uuid not null references public.learning_taxonomy_versions(id) on delete restrict,
  skill_id text not null,
  target text not null,
  category text not null,
  subcategory text,
  label text not null,
  enabled boolean not null default true,
  disabled_reason text,
  curriculum_weight numeric(8,4) not null default 1,
  prerequisite_skill_ids text[] not null default '{}',
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (taxonomy_version_id, skill_id),
  constraint learning_skills_id_check check (btrim(skill_id) <> ''),
  constraint learning_skills_target_check check (target in ('cpns', 'bumn')),
  constraint learning_skills_category_check check (btrim(category) <> ''),
  constraint learning_skills_label_check check (btrim(label) <> ''),
  constraint learning_skills_weight_check check (curriculum_weight > 0),
  constraint learning_skills_disabled_reason_check check (
    enabled or nullif(btrim(disabled_reason), '') is not null
  )
);

create index if not exists learning_skills_target_enabled_idx
  on public.learning_skills(taxonomy_version_id, target, enabled, category, subcategory, skill_id);

create table if not exists public.question_revisions (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete restrict,
  revision integer not null,
  source_key text not null,
  content_version text not null,
  content_hash text not null,
  target text not null,
  category text not null,
  subcategory text,
  prompt text not null,
  options jsonb not null,
  correct_option_index integer not null,
  explanation text not null,
  hint text,
  difficulty text not null,
  question_type text not null default 'multiple_choice',
  expected_time_ms integer,
  standard_time_limit_ms integer not null,
  curriculum_weight numeric(8,4) not null default 1,
  assessment_eligible boolean not null default false,
  quality_state text not null default 'development',
  is_active boolean not null default true,
  sme_approved boolean not null default false,
  approved_at timestamptz,
  approver_reference text,
  created_at timestamptz not null default now(),
  constraint question_revisions_revision_check check (revision > 0),
  constraint question_revisions_source_key_check check (btrim(source_key) <> ''),
  constraint question_revisions_content_version_check check (btrim(content_version) <> ''),
  constraint question_revisions_content_hash_check check (btrim(content_hash) <> ''),
  constraint question_revisions_target_check check (target in ('cpns', 'bumn')),
  constraint question_revisions_category_check check (btrim(category) <> ''),
  constraint question_revisions_prompt_check check (btrim(prompt) <> ''),
  constraint question_revisions_options_check check (public.valid_question_options(options)),
  constraint question_revisions_correct_option_check check (
    correct_option_index >= 0 and correct_option_index < jsonb_array_length(options)
  ),
  constraint question_revisions_explanation_check check (btrim(explanation) <> ''),
  constraint question_revisions_difficulty_check check (difficulty in ('easy', 'medium', 'hard')),
  constraint question_revisions_question_type_check check (btrim(question_type) <> ''),
  constraint question_revisions_expected_time_check check (expected_time_ms is null or expected_time_ms > 0),
  constraint question_revisions_standard_limit_check check (standard_time_limit_ms > 0),
  constraint question_revisions_curriculum_weight_check check (curriculum_weight > 0),
  constraint question_revisions_quality_state_check check (
    quality_state in ('development', 'approved', 'under_review', 'invalidated', 'disabled')
  ),
  constraint question_revisions_approval_consistency_check check (
    (
      sme_approved
      and quality_state = 'approved'
      and approved_at is not null
      and nullif(btrim(approver_reference), '') is not null
    )
    or (
      not sme_approved
      and approved_at is null
      and approver_reference is null
      and quality_state <> 'approved'
    )
  ),
  constraint question_revisions_question_revision_unique unique (question_id, revision),
  constraint question_revisions_question_hash_unique unique (question_id, content_hash)
);

create index if not exists question_revisions_question_created_idx
  on public.question_revisions(question_id, revision desc, created_at desc);

create table if not exists public.question_skill_mappings (
  question_revision_id uuid not null references public.question_revisions(id) on delete restrict,
  taxonomy_version_id uuid not null,
  skill_id text not null,
  mapping_type text not null,
  mapping_weight numeric(8,4) not null default 1,
  approval_status text not null default 'development',
  approved_at timestamptz,
  approver_reference text,
  provenance text not null default 'content_sync',
  created_at timestamptz not null default now(),
  primary key (question_revision_id, taxonomy_version_id, skill_id, mapping_type),
  constraint question_skill_mappings_skill_fkey
    foreign key (taxonomy_version_id, skill_id)
    references public.learning_skills(taxonomy_version_id, skill_id)
    on delete restrict,
  constraint question_skill_mappings_type_check check (mapping_type in ('primary', 'prerequisite')),
  constraint question_skill_mappings_weight_check check (mapping_weight > 0),
  constraint question_skill_mappings_approval_check check (
    approval_status in ('development', 'sme_approved')
  ),
  constraint question_skill_mappings_approval_consistency_check check (
    (
      approval_status = 'sme_approved'
      and approved_at is not null
      and nullif(btrim(approver_reference), '') is not null
    )
    or (
      approval_status = 'development'
      and approved_at is null
      and approver_reference is null
    )
  ),
  constraint question_skill_mappings_provenance_check check (btrim(provenance) <> '')
);

create unique index if not exists question_skill_mappings_one_primary_idx
  on public.question_skill_mappings(question_revision_id)
  where mapping_type = 'primary';

create index if not exists question_skill_mappings_skill_idx
  on public.question_skill_mappings(taxonomy_version_id, skill_id, mapping_type);

create table if not exists public.learner_question_exposures (
  user_id uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  exposure_count integer not null,
  first_presented_at timestamptz not null,
  last_presented_at timestamptz not null,
  last_source text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, question_id),
  constraint learner_question_exposure_count_check check (exposure_count > 0),
  constraint learner_question_exposure_time_check check (last_presented_at >= first_presented_at),
  constraint learner_question_exposure_source_check check (last_source in ('solo', 'pvp', 'assessment'))
);

create table if not exists public.learning_fixture_runs (
  id uuid primary key default gen_random_uuid(),
  run_key text not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  scenario text not null,
  status text not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  invalidated_at timestamptz,
  invalidation_reason text,
  constraint learning_fixture_runs_key_check check (btrim(run_key) <> ''),
  constraint learning_fixture_runs_target_check check (target in ('cpns', 'bumn')),
  constraint learning_fixture_runs_scenario_check check (btrim(scenario) <> ''),
  constraint learning_fixture_runs_status_check check (status in ('active', 'invalidated')),
  constraint learning_fixture_runs_invalidation_check check (
    (status = 'active' and invalidated_at is null and invalidation_reason is null)
    or (status = 'invalidated' and invalidated_at is not null and nullif(btrim(invalidation_reason), '') is not null)
  ),
  constraint learning_fixture_runs_metadata_check check (jsonb_typeof(metadata) = 'object'),
  constraint learning_fixture_runs_user_key_unique unique (user_id, run_key)
);

create table if not exists public.learning_backfill_runs (
  id uuid primary key default gen_random_uuid(),
  run_key text not null,
  source text not null,
  dry_run boolean not null default true,
  status text not null default 'running',
  source_watermark jsonb not null default '{}'::jsonb,
  report jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  error_message text,
  constraint learning_backfill_runs_key_check check (btrim(run_key) <> ''),
  constraint learning_backfill_runs_source_check check (source in ('legacy_solo', 'legacy_pvp')),
  constraint learning_backfill_runs_status_check check (status in ('running', 'completed', 'failed')),
  constraint learning_backfill_runs_completion_check check (
    (status = 'running' and completed_at is null)
    or (status in ('completed', 'failed') and completed_at is not null)
  ),
  constraint learning_backfill_runs_json_check check (
    jsonb_typeof(source_watermark) = 'object' and jsonb_typeof(report) = 'object'
  ),
  constraint learning_backfill_runs_key_unique unique (run_key)
);

create table if not exists public.learning_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  taxonomy_version_id uuid references public.learning_taxonomy_versions(id) on delete restrict,
  calculation_version text not null,
  evidence_classification_version text not null,
  objective text not null,
  mechanic_mode text not null,
  question_selection_type text not null,
  skill_ids text[] not null,
  delivery_policy_id text,
  availability_runnable boolean not null default false,
  availability_reason text,
  execution_adapter text,
  reason_headline text not null,
  reason_description text not null,
  reason_evidence jsonb not null default '[]'::jsonb,
  input_as_of timestamptz not null,
  input_snapshot jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  constraint learning_recommendations_target_check check (target in ('cpns', 'bumn')),
  constraint learning_recommendations_calculation_version_check check (btrim(calculation_version) <> ''),
  constraint learning_recommendations_classification_version_check check (btrim(evidence_classification_version) <> ''),
  constraint learning_recommendations_objective_check check (
    objective in ('repair_accuracy', 'spaced_review', 'collect_evidence', 'build_fluency', 'maintain_coverage')
  ),
  constraint learning_recommendations_mechanic_check check (mechanic_mode in ('focus', 'standard', 'speed')),
  constraint learning_recommendations_selection_check check (
    question_selection_type in ('balanced', 'recommended', 'custom')
  ),
  constraint learning_recommendations_skill_ids_check check (cardinality(skill_ids) > 0),
  constraint learning_recommendations_availability_reason_check check (
    availability_runnable or nullif(btrim(availability_reason), '') is not null
  ),
  constraint learning_recommendations_reason_check check (
    btrim(reason_headline) <> '' and btrim(reason_description) <> ''
  ),
  constraint learning_recommendations_reason_evidence_check check (jsonb_typeof(reason_evidence) = 'array'),
  constraint learning_recommendations_input_snapshot_check check (jsonb_typeof(input_snapshot) = 'object'),
  constraint learning_recommendations_expiry_check check (expires_at > generated_at),
  constraint learning_recommendations_status_check check (
    status in ('active', 'expired', 'superseded', 'dismissed', 'completed')
  )
);

create unique index if not exists learning_recommendations_one_active_idx
  on public.learning_recommendations(user_id, target)
  where status = 'active';

create index if not exists learning_recommendations_user_recent_idx
  on public.learning_recommendations(user_id, target, generated_at desc);

create index if not exists learning_recommendations_expiry_idx
  on public.learning_recommendations(status, expires_at)
  where status = 'active';

create table if not exists public.learning_attempts (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  source_attempt_key text not null,
  source_payload_hash text not null,
  data_fidelity text not null,
  fixture_run_id uuid references public.learning_fixture_runs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  source_session_key text,
  recommendation_id uuid references public.learning_recommendations(id) on delete set null,
  learning_objective text,
  requested_mechanic_mode text,
  effective_mechanic_mode text,
  question_selection_type text,
  delivery_policy_id text,
  assessment_blueprint_version text,
  pvp_mode text,
  session_completion_state text,
  question_id uuid references public.questions(id) on delete set null,
  question_revision_id uuid references public.question_revisions(id) on delete restrict,
  taxonomy_version_id uuid,
  skill_id text,
  content_version text,
  category text,
  subcategory text,
  difficulty text,
  expected_time_ms integer,
  standard_time_limit_ms integer,
  curriculum_weight numeric(8,4),
  question_quality_state text,
  selected_option_index integer,
  is_correct boolean,
  hint_requested boolean,
  timed_out boolean,
  first_attempt boolean,
  seen_before boolean,
  exposure_count_before integer,
  perceived_difficulty text,
  explanation_viewed boolean,
  abandonment_context text,
  opened_at timestamptz,
  answered_at timestamptz,
  deadline_at timestamptz,
  client_active_response_time_ms integer,
  server_elapsed_time_ms integer,
  background_duration_ms integer,
  effective_response_time_ms integer,
  timing_invalidity_reason text,
  source_event_at timestamptz not null,
  ingested_at timestamptz not null default now(),
  constraint learning_attempts_source_check check (source in ('solo', 'pvp', 'assessment')),
  constraint learning_attempts_source_key_check check (btrim(source_attempt_key) <> ''),
  constraint learning_attempts_payload_hash_check check (btrim(source_payload_hash) <> ''),
  constraint learning_attempts_data_fidelity_check check (
    data_fidelity in (
      'v2_complete', 'compatibility_solo', 'legacy_solo', 'legacy_pvp',
      'assessment_import', 'synthetic_fixture'
    )
  ),
  constraint learning_attempts_fixture_check check (
    (data_fidelity = 'synthetic_fixture' and fixture_run_id is not null)
    or (data_fidelity <> 'synthetic_fixture' and fixture_run_id is null)
  ),
  constraint learning_attempts_target_check check (target in ('cpns', 'bumn')),
  constraint learning_attempts_objective_check check (
    learning_objective is null or learning_objective in (
      'repair_accuracy', 'spaced_review', 'collect_evidence', 'build_fluency', 'maintain_coverage'
    )
  ),
  constraint learning_attempts_requested_mechanic_check check (
    requested_mechanic_mode is null or requested_mechanic_mode in ('focus', 'standard', 'speed')
  ),
  constraint learning_attempts_effective_mechanic_check check (
    effective_mechanic_mode is null or effective_mechanic_mode in ('focus', 'standard', 'speed')
  ),
  constraint learning_attempts_selection_check check (
    question_selection_type is null or question_selection_type in ('balanced', 'recommended', 'custom')
  ),
  constraint learning_attempts_pvp_mode_check check (
    pvp_mode is null or pvp_mode in ('casual', 'ranked', 'private')
  ),
  constraint learning_attempts_completion_state_check check (
    session_completion_state is null or session_completion_state in (
      'in_progress', 'compatibility_completed', 'policy_completed',
      'user_stopped', 'question_inventory_exhausted', 'abandoned'
    )
  ),
  constraint learning_attempts_difficulty_check check (
    difficulty is null or difficulty in ('easy', 'medium', 'hard')
  ),
  constraint learning_attempts_quality_state_check check (
    question_quality_state is null or question_quality_state in (
      'development', 'approved', 'under_review', 'invalidated', 'disabled'
    )
  ),
  constraint learning_attempts_selected_option_check check (
    selected_option_index is null or selected_option_index between 0 and 5
  ),
  constraint learning_attempts_exposure_check check (
    exposure_count_before is null or exposure_count_before >= 0
  ),
  constraint learning_attempts_expected_time_check check (expected_time_ms is null or expected_time_ms > 0),
  constraint learning_attempts_standard_limit_check check (
    standard_time_limit_ms is null or standard_time_limit_ms > 0
  ),
  constraint learning_attempts_curriculum_weight_check check (
    curriculum_weight is null or curriculum_weight > 0
  ),
  constraint learning_attempts_timing_values_check check (
    (client_active_response_time_ms is null or client_active_response_time_ms >= 0)
    and (server_elapsed_time_ms is null or server_elapsed_time_ms >= 0)
    and (background_duration_ms is null or background_duration_ms >= 0)
    and (effective_response_time_ms is null or effective_response_time_ms >= 0)
  ),
  constraint learning_attempts_timeout_answer_check check (
    timed_out is distinct from true
    or (selected_option_index is null and is_correct is false)
  ),
  constraint learning_attempts_event_time_check check (
    (opened_at is null or answered_at is null or answered_at >= opened_at)
    and (opened_at is null or deadline_at is null or deadline_at >= opened_at)
  ),
  constraint learning_attempts_optional_text_check check (
    (perceived_difficulty is null or btrim(perceived_difficulty) <> '')
    and (abandonment_context is null or btrim(abandonment_context) <> '')
    and (timing_invalidity_reason is null or btrim(timing_invalidity_reason) <> '')
  ),
  constraint learning_attempts_skill_pair_check check (
    (taxonomy_version_id is null and skill_id is null)
    or (taxonomy_version_id is not null and nullif(btrim(skill_id), '') is not null)
  ),
  constraint learning_attempts_skill_fkey
    foreign key (taxonomy_version_id, skill_id)
    references public.learning_skills(taxonomy_version_id, skill_id)
    on delete restrict,
  constraint learning_attempts_source_unique unique (source, source_attempt_key)
);

create index if not exists learning_attempts_user_source_event_idx
  on public.learning_attempts(user_id, target, source, source_event_at desc);

create index if not exists learning_attempts_user_skill_event_idx
  on public.learning_attempts(user_id, target, taxonomy_version_id, skill_id, source_event_at desc)
  where skill_id is not null;

create index if not exists learning_attempts_question_user_event_idx
  on public.learning_attempts(user_id, question_id, source_event_at desc)
  where question_id is not null;

create index if not exists learning_attempts_fixture_idx
  on public.learning_attempts(fixture_run_id, source_event_at)
  where fixture_run_id is not null;

create table if not exists public.learning_attempt_classifications (
  attempt_id uuid not null references public.learning_attempts(id) on delete cascade,
  classification_version text not null,
  classifier_input_hash text not null,
  valid_for_activity_accuracy boolean not null default false,
  valid_for_independent_accuracy boolean not null default false,
  valid_for_unseen_independent_accuracy boolean not null default false,
  valid_for_assisted_accuracy boolean not null default false,
  valid_for_pace_analytics boolean not null default false,
  valid_for_fluency_baseline boolean not null default false,
  valid_for_retention boolean not null default false,
  exclusion_reasons text[] not null default '{}',
  classified_at timestamptz not null default now(),
  primary key (attempt_id, classification_version),
  constraint learning_attempt_classification_version_check check (btrim(classification_version) <> ''),
  constraint learning_attempt_classification_hash_check check (btrim(classifier_input_hash) <> ''),
  constraint learning_attempt_classification_hierarchy_check check (
    not valid_for_unseen_independent_accuracy or valid_for_independent_accuracy
  ),
  constraint learning_attempt_classification_assisted_check check (
    not valid_for_assisted_accuracy or not valid_for_independent_accuracy
  )
);

create index if not exists learning_attempt_classifications_version_idx
  on public.learning_attempt_classifications(classification_version, classified_at desc);

create table if not exists public.learning_attempt_invalidations (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid references public.learning_attempts(id) on delete cascade,
  question_revision_id uuid references public.question_revisions(id) on delete restrict,
  reason text not null,
  invalidated_by uuid references public.profiles(id) on delete set null,
  invalidated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint learning_attempt_invalidations_target_check check (
    num_nonnulls(attempt_id, question_revision_id) = 1
  ),
  constraint learning_attempt_invalidations_reason_check check (btrim(reason) <> ''),
  constraint learning_attempt_invalidations_metadata_check check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists learning_attempt_invalidations_attempt_unique_idx
  on public.learning_attempt_invalidations(attempt_id)
  where attempt_id is not null;

create unique index if not exists learning_attempt_invalidations_revision_unique_idx
  on public.learning_attempt_invalidations(question_revision_id)
  where question_revision_id is not null;

create table if not exists public.learning_projection_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  taxonomy_version_id uuid references public.learning_taxonomy_versions(id) on delete restrict,
  skill_id text,
  reason text not null,
  source_attempt_id uuid references public.learning_attempts(id) on delete set null,
  status text not null default 'pending',
  available_at timestamptz not null default now(),
  attempt_count integer not null default 0,
  locked_at timestamptz,
  locked_by text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learning_projection_jobs_target_check check (target in ('cpns', 'bumn')),
  constraint learning_projection_jobs_skill_pair_check check (
    (taxonomy_version_id is null and skill_id is null)
    or (taxonomy_version_id is not null and nullif(btrim(skill_id), '') is not null)
  ),
  constraint learning_projection_jobs_skill_fkey
    foreign key (taxonomy_version_id, skill_id)
    references public.learning_skills(taxonomy_version_id, skill_id)
    on delete restrict,
  constraint learning_projection_jobs_reason_check check (
    reason in (
      'attempt_ingested', 'attempt_invalidated', 'revision_invalidated',
      'backfill', 'fixture_seeded', 'fixture_invalidated', 'retention_due',
      'recommendation_expired', 'pvp_ingested', 'manual_rebuild'
    )
  ),
  constraint learning_projection_jobs_status_check check (
    status in ('pending', 'processing', 'completed', 'failed')
  ),
  constraint learning_projection_jobs_attempt_count_check check (attempt_count >= 0)
);

create unique index if not exists learning_projection_jobs_pending_unique_idx
  on public.learning_projection_jobs(
    user_id,
    target,
    coalesce(taxonomy_version_id::text, ''),
    coalesce(skill_id, ''),
    reason
  )
  where status = 'pending';

create index if not exists learning_projection_jobs_claim_idx
  on public.learning_projection_jobs(status, available_at, created_at)
  where status in ('pending', 'failed');

create table if not exists public.learner_skill_state (
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  taxonomy_version_id uuid not null,
  skill_id text not null,
  calculation_version text not null,
  evidence_classification_version text not null,
  status text not null,
  activity_correct_count integer not null default 0,
  activity_attempt_count integer not null default 0,
  activity_accuracy numeric(6,2),
  independent_correct_count integer not null default 0,
  independent_attempt_count integer not null default 0,
  independent_accuracy numeric(6,2),
  unseen_correct_count integer not null default 0,
  unseen_attempt_count integer not null default 0,
  unique_question_count integer not null default 0,
  unseen_independent_accuracy numeric(6,2),
  smoothed_accuracy numeric(6,2),
  assisted_correct_count integer not null default 0,
  assisted_attempt_count integer not null default 0,
  assisted_accuracy numeric(6,2),
  hint_rate numeric(6,2),
  independence_gap numeric(7,2),
  evidence_confidence text not null,
  median_response_time_ms integer,
  pace_ratio numeric(8,4),
  pace_baseline_type text,
  pace_attempt_count integer not null default 0,
  timeout_rate numeric(6,2),
  trend_percentage_points numeric(7,2),
  coverage_sufficient boolean not null default false,
  recommended_mechanic text not null,
  latest_eligible_at timestamptz,
  last_practiced_at timestamptz,
  input_as_of timestamptz not null,
  attempt_watermark timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, target, taxonomy_version_id, skill_id, calculation_version),
  constraint learner_skill_state_skill_fkey
    foreign key (taxonomy_version_id, skill_id)
    references public.learning_skills(taxonomy_version_id, skill_id)
    on delete restrict,
  constraint learner_skill_state_target_check check (target in ('cpns', 'bumn')),
  constraint learner_skill_state_status_check check (
    status in ('collecting_data', 'needs_repair', 'developing', 'needs_review', 'needs_fluency', 'secure')
  ),
  constraint learner_skill_state_version_check check (
    btrim(calculation_version) <> '' and btrim(evidence_classification_version) <> ''
  ),
  constraint learner_skill_state_counts_check check (
    activity_correct_count between 0 and activity_attempt_count
    and independent_correct_count between 0 and independent_attempt_count
    and unseen_correct_count between 0 and unseen_attempt_count
    and assisted_correct_count between 0 and assisted_attempt_count
    and unique_question_count >= 0
    and pace_attempt_count >= 0
  ),
  constraint learner_skill_state_percentages_check check (
    (activity_accuracy is null or activity_accuracy between 0 and 100)
    and (independent_accuracy is null or independent_accuracy between 0 and 100)
    and (unseen_independent_accuracy is null or unseen_independent_accuracy between 0 and 100)
    and (smoothed_accuracy is null or smoothed_accuracy between 0 and 100)
    and (assisted_accuracy is null or assisted_accuracy between 0 and 100)
    and (hint_rate is null or hint_rate between 0 and 100)
    and (timeout_rate is null or timeout_rate between 0 and 100)
    and (independence_gap is null or independence_gap between -100 and 100)
    and (trend_percentage_points is null or trend_percentage_points between -100 and 100)
  ),
  constraint learner_skill_state_pace_check check (
    (median_response_time_ms is null or median_response_time_ms >= 0)
    and (pace_ratio is null or pace_ratio >= 0)
    and (pace_baseline_type is null or pace_baseline_type in ('personal', 'calibrated'))
  ),
  constraint learner_skill_state_confidence_check check (evidence_confidence in ('low', 'medium', 'high')),
  constraint learner_skill_state_mechanic_check check (recommended_mechanic in ('focus', 'standard', 'speed'))
);

create index if not exists learner_skill_state_dashboard_idx
  on public.learner_skill_state(user_id, target, calculation_version, status, skill_id);

create table if not exists public.retention_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  taxonomy_version_id uuid not null,
  skill_id text not null,
  calculation_version text not null,
  strong_evidence_at timestamptz not null,
  review_due_at timestamptz not null,
  status text not null default 'scheduled',
  satisfied_attempt_id uuid references public.learning_attempts(id) on delete set null,
  retention_correct_count integer not null default 0,
  retention_attempt_count integer not null default 0,
  retention_accuracy numeric(6,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint retention_schedules_skill_fkey
    foreign key (taxonomy_version_id, skill_id)
    references public.learning_skills(taxonomy_version_id, skill_id)
    on delete restrict,
  constraint retention_schedules_target_check check (target in ('cpns', 'bumn')),
  constraint retention_schedules_version_check check (btrim(calculation_version) <> ''),
  constraint retention_schedules_due_check check (review_due_at > strong_evidence_at),
  constraint retention_schedules_status_check check (status in ('scheduled', 'due', 'completed', 'cancelled')),
  constraint retention_schedules_counts_check check (
    retention_correct_count between 0 and retention_attempt_count
  ),
  constraint retention_schedules_accuracy_check check (
    retention_accuracy is null or retention_accuracy between 0 and 100
  ),
  constraint retention_schedules_unique unique (
    user_id, target, taxonomy_version_id, skill_id, calculation_version, strong_evidence_at
  )
);

create index if not exists retention_schedules_due_idx
  on public.retention_schedules(status, review_due_at)
  where status in ('scheduled', 'due');

create table if not exists public.recommendation_events (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null references public.learning_recommendations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  dismissal_reason text,
  idempotency_key text not null,
  event_source text not null,
  source_session_key text,
  result_snapshot jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint recommendation_events_type_check check (
    event_type in (
      'shown', 'accepted', 'dismissed', 'session_started', 'session_completed',
      'immediate_result_attached', 'delayed_result_attached'
    )
  ),
  constraint recommendation_events_dismissal_check check (
    (event_type = 'dismissed' and dismissal_reason in (
      'prefer_another_skill', 'too_difficult', 'too_easy', 'not_enough_time',
      'do_not_like_timed_mode', 'other'
    ))
    or (event_type <> 'dismissed' and dismissal_reason is null)
  ),
  constraint recommendation_events_idempotency_check check (char_length(idempotency_key) between 1 and 160),
  constraint recommendation_events_source_check check (event_source in ('client', 'server')),
  constraint recommendation_events_result_snapshot_check check (
    result_snapshot is null or jsonb_typeof(result_snapshot) = 'object'
  ),
  constraint recommendation_events_unique unique (recommendation_id, user_id, idempotency_key)
);

create index if not exists recommendation_events_recommendation_time_idx
  on public.recommendation_events(recommendation_id, occurred_at, id);

create table if not exists public.assessment_evidence (
  id uuid primary key default gen_random_uuid(),
  source_attempt_key text not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  assessment_session_key text not null,
  blueprint_version text not null,
  validation_status text not null default 'insufficient_evidence',
  score numeric(6,2),
  correct_count integer,
  attempt_count integer,
  category_breakdown jsonb not null default '[]'::jsonb,
  skill_breakdown jsonb not null default '[]'::jsonb,
  occurred_at timestamptz not null,
  ingested_at timestamptz not null default now(),
  raw_snapshot jsonb not null default '{}'::jsonb,
  constraint assessment_evidence_source_key_check check (btrim(source_attempt_key) <> ''),
  constraint assessment_evidence_target_check check (target in ('cpns', 'bumn')),
  constraint assessment_evidence_session_check check (btrim(assessment_session_key) <> ''),
  constraint assessment_evidence_blueprint_check check (btrim(blueprint_version) <> ''),
  constraint assessment_evidence_validation_check check (
    validation_status in ('not_available', 'insufficient_evidence', 'baseline_recorded', 'validated', 'needs_revalidation')
  ),
  constraint assessment_evidence_score_check check (score is null or score between 0 and 100),
  constraint assessment_evidence_counts_check check (
    (correct_count is null and attempt_count is null)
    or (correct_count is not null and attempt_count is not null and correct_count between 0 and attempt_count)
  ),
  constraint assessment_evidence_breakdown_check check (
    jsonb_typeof(category_breakdown) = 'array' and jsonb_typeof(skill_breakdown) = 'array'
  ),
  constraint assessment_evidence_raw_snapshot_check check (jsonb_typeof(raw_snapshot) = 'object'),
  constraint assessment_evidence_source_unique unique (source_attempt_key)
);

create index if not exists assessment_evidence_user_recent_idx
  on public.assessment_evidence(user_id, target, occurred_at desc);

-- Additive compatibility columns. Existing rows are explicitly legacy and no
-- historical revision, exposure, or hint authority is fabricated here.
alter table public.practice_sessions
  add column if not exists recommendation_id uuid,
  add column if not exists taxonomy_version_id uuid,
  add column if not exists learning_objective text,
  add column if not exists requested_mechanic_mode text,
  add column if not exists effective_mechanic_mode text,
  add column if not exists question_selection_type text,
  add column if not exists evidence_capture_version text not null default 'legacy-practice-v1';

alter table public.practice_sessions drop constraint if exists practice_sessions_learning_recommendation_fkey;
alter table public.practice_sessions add constraint practice_sessions_learning_recommendation_fkey
  foreign key (recommendation_id) references public.learning_recommendations(id) on delete set null;
alter table public.practice_sessions drop constraint if exists practice_sessions_learning_taxonomy_fkey;
alter table public.practice_sessions add constraint practice_sessions_learning_taxonomy_fkey
  foreign key (taxonomy_version_id) references public.learning_taxonomy_versions(id) on delete restrict;
alter table public.practice_sessions drop constraint if exists practice_sessions_learning_objective_check;
alter table public.practice_sessions add constraint practice_sessions_learning_objective_check check (
  learning_objective is null or learning_objective in (
    'repair_accuracy', 'spaced_review', 'collect_evidence', 'build_fluency', 'maintain_coverage'
  )
);
alter table public.practice_sessions drop constraint if exists practice_sessions_requested_mechanic_check;
alter table public.practice_sessions add constraint practice_sessions_requested_mechanic_check check (
  requested_mechanic_mode is null or requested_mechanic_mode in ('focus', 'standard', 'speed')
);
alter table public.practice_sessions drop constraint if exists practice_sessions_effective_mechanic_check;
alter table public.practice_sessions add constraint practice_sessions_effective_mechanic_check check (
  effective_mechanic_mode is null or effective_mechanic_mode in ('focus', 'standard', 'speed')
);
alter table public.practice_sessions drop constraint if exists practice_sessions_question_selection_check;
alter table public.practice_sessions add constraint practice_sessions_question_selection_check check (
  question_selection_type is null or question_selection_type in ('balanced', 'recommended', 'custom')
);
alter table public.practice_sessions drop constraint if exists practice_sessions_evidence_capture_version_check;
alter table public.practice_sessions add constraint practice_sessions_evidence_capture_version_check check (
  btrim(evidence_capture_version) <> ''
);

create index if not exists practice_sessions_recommendation_idx
  on public.practice_sessions(recommendation_id)
  where recommendation_id is not null;

alter table public.practice_session_questions
  add column if not exists question_revision_id uuid,
  add column if not exists taxonomy_version_id uuid,
  add column if not exists skill_id text,
  add column if not exists exposure_count_before integer,
  add column if not exists seen_before boolean,
  add column if not exists hint_requested_at timestamptz,
  add column if not exists hint_idempotency_key text,
  add column if not exists opened_at timestamptz;

alter table public.practice_session_questions drop constraint if exists practice_session_questions_revision_fkey;
alter table public.practice_session_questions add constraint practice_session_questions_revision_fkey
  foreign key (question_revision_id) references public.question_revisions(id) on delete restrict;
alter table public.practice_session_questions drop constraint if exists practice_session_questions_skill_pair_check;
alter table public.practice_session_questions add constraint practice_session_questions_skill_pair_check check (
  (taxonomy_version_id is null and skill_id is null)
  or (taxonomy_version_id is not null and nullif(btrim(skill_id), '') is not null)
);
alter table public.practice_session_questions drop constraint if exists practice_session_questions_skill_fkey;
alter table public.practice_session_questions add constraint practice_session_questions_skill_fkey
  foreign key (taxonomy_version_id, skill_id)
  references public.learning_skills(taxonomy_version_id, skill_id)
  on delete restrict;
alter table public.practice_session_questions drop constraint if exists practice_session_questions_exposure_check;
alter table public.practice_session_questions add constraint practice_session_questions_exposure_check check (
  exposure_count_before is null or exposure_count_before >= 0
);
alter table public.practice_session_questions drop constraint if exists practice_session_questions_hint_key_check;
alter table public.practice_session_questions add constraint practice_session_questions_hint_key_check check (
  hint_idempotency_key is null or char_length(hint_idempotency_key) between 1 and 160
);

create unique index if not exists practice_session_questions_hint_idempotency_idx
  on public.practice_session_questions(session_id, hint_idempotency_key)
  where hint_idempotency_key is not null;

alter table public.practice_answers
  add column if not exists canonical_attempt_id uuid;

alter table public.practice_answers drop constraint if exists practice_answers_canonical_attempt_fkey;
alter table public.practice_answers add constraint practice_answers_canonical_attempt_fkey
  foreign key (canonical_attempt_id) references public.learning_attempts(id) on delete set null;

create unique index if not exists practice_answers_canonical_attempt_unique_idx
  on public.practice_answers(canonical_attempt_id)
  where canonical_attempt_id is not null;

create or replace function public.validate_question_skill_mapping()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_question_target text;
  v_skill_target text;
begin
  select target into v_question_target
  from public.question_revisions
  where id = new.question_revision_id;

  select target into v_skill_target
  from public.learning_skills
  where taxonomy_version_id = new.taxonomy_version_id
    and skill_id = new.skill_id;

  if v_question_target is null or v_skill_target is null or v_question_target <> v_skill_target then
    raise exception using
      errcode = 'P0001',
      message = 'VALIDATION_FAILED: question revision and skill target must match';
  end if;
  return new;
end;
$$;

drop trigger if exists question_skill_mappings_target_guard on public.question_skill_mappings;
create trigger question_skill_mappings_target_guard
before insert or update on public.question_skill_mappings
for each row execute function public.validate_question_skill_mapping();

create or replace function public.reject_learning_attempt_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if not exists (
    select 1 from public.profiles where id = old.user_id
  ) then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'LEARNING_ATTEMPTS_APPEND_ONLY';
end;
$$;

drop trigger if exists learning_attempts_append_only_guard on public.learning_attempts;
create trigger learning_attempts_append_only_guard
before update or delete on public.learning_attempts
for each row execute function public.reject_learning_attempt_mutation();

create or replace function public.reject_learning_classification_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' and not exists (
    select 1 from public.learning_attempts where id = old.attempt_id
  ) then
    return old;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'LEARNING_CLASSIFICATIONS_APPEND_ONLY';
end;
$$;

drop trigger if exists learning_classifications_append_only_guard on public.learning_attempt_classifications;
create trigger learning_classifications_append_only_guard
before update or delete on public.learning_attempt_classifications
for each row execute function public.reject_learning_classification_mutation();

create or replace function public.reject_question_revision_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'QUESTION_REVISIONS_APPEND_ONLY';
end;
$$;

drop trigger if exists question_revisions_append_only_guard on public.question_revisions;
create trigger question_revisions_append_only_guard
before update or delete on public.question_revisions
for each row execute function public.reject_question_revision_mutation();

create or replace function public.reject_question_skill_mapping_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'QUESTION_SKILL_MAPPINGS_APPEND_ONLY';
end;
$$;

drop trigger if exists question_skill_mappings_append_only_guard on public.question_skill_mappings;
create trigger question_skill_mappings_append_only_guard
before update or delete on public.question_skill_mappings
for each row execute function public.reject_question_skill_mapping_mutation();

create or replace function public.reject_learning_invalidation_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE'
     and old.attempt_id is not null
     and not exists (
       select 1
       from public.learning_attempts attempt
       join public.profiles profile on profile.id = attempt.user_id
       where attempt.id = old.attempt_id
     ) then
    return old;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'LEARNING_INVALIDATIONS_APPEND_ONLY';
end;
$$;

drop trigger if exists learning_invalidations_append_only_guard on public.learning_attempt_invalidations;
create trigger learning_invalidations_append_only_guard
before update or delete on public.learning_attempt_invalidations
for each row execute function public.reject_learning_invalidation_mutation();

create or replace function public.reject_recommendation_event_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' and not exists (
    select 1 from public.profiles where id = old.user_id
  ) then
    return old;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'RECOMMENDATION_EVENTS_APPEND_ONLY';
end;
$$;

drop trigger if exists recommendation_events_append_only_guard on public.recommendation_events;
create trigger recommendation_events_append_only_guard
before update or delete on public.recommendation_events
for each row execute function public.reject_recommendation_event_mutation();

create or replace function public.reject_assessment_evidence_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.learning_maintenance', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' and not exists (
    select 1 from public.profiles where id = old.user_id
  ) then
    return old;
  end if;
  raise exception using
    errcode = 'P0001',
    message = 'ASSESSMENT_EVIDENCE_APPEND_ONLY';
end;
$$;

drop trigger if exists assessment_evidence_append_only_guard on public.assessment_evidence;
create trigger assessment_evidence_append_only_guard
before update or delete on public.assessment_evidence
for each row execute function public.reject_assessment_evidence_mutation();

create or replace function public.enqueue_learning_projection(
  p_user_id uuid,
  p_target text,
  p_taxonomy_version_id uuid default null,
  p_skill_id text default null,
  p_reason text default 'manual_rebuild',
  p_source_attempt_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_id uuid;
begin
  if p_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: target';
  end if;
  if (p_taxonomy_version_id is null) <> (p_skill_id is null) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: taxonomy and skill must be supplied together';
  end if;
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: projection reason';
  end if;

  insert into public.learning_projection_jobs(
    user_id, target, taxonomy_version_id, skill_id, reason, source_attempt_id
  ) values (
    p_user_id, p_target, p_taxonomy_version_id, p_skill_id, p_reason, p_source_attempt_id
  )
  on conflict do nothing
  returning id into v_job_id;

  if v_job_id is null then
    select id into v_job_id
    from public.learning_projection_jobs
    where user_id = p_user_id
      and target = p_target
      and taxonomy_version_id is not distinct from p_taxonomy_version_id
      and skill_id is not distinct from p_skill_id
      and reason = p_reason
      and status = 'pending'
    order by created_at
    limit 1;
  end if;
  return v_job_id;
end;
$$;

create or replace function public.queue_learning_attempt_projection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.enqueue_learning_projection(
    new.user_id,
    new.target,
    new.taxonomy_version_id,
    new.skill_id,
    'attempt_ingested',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists learning_attempts_projection_queue on public.learning_attempts;
create trigger learning_attempts_projection_queue
after insert on public.learning_attempts
for each row execute function public.queue_learning_attempt_projection();

create or replace function public.queue_learning_invalidation_projection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_projection record;
begin
  if new.attempt_id is not null then
    select attempt.user_id, attempt.target, attempt.taxonomy_version_id, attempt.skill_id
    into v_projection
    from public.learning_attempts attempt
    where attempt.id = new.attempt_id;

    if found then
      perform public.enqueue_learning_projection(
        v_projection.user_id,
        v_projection.target,
        v_projection.taxonomy_version_id,
        v_projection.skill_id,
        'attempt_invalidated',
        new.attempt_id
      );
    end if;
  else
    for v_projection in
      select distinct
        attempt.user_id,
        attempt.target,
        attempt.taxonomy_version_id,
        attempt.skill_id
      from public.learning_attempts attempt
      where attempt.question_revision_id = new.question_revision_id
    loop
      perform public.enqueue_learning_projection(
        v_projection.user_id,
        v_projection.target,
        v_projection.taxonomy_version_id,
        v_projection.skill_id,
        'revision_invalidated',
        null
      );
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists learning_invalidations_projection_queue on public.learning_attempt_invalidations;
create trigger learning_invalidations_projection_queue
after insert on public.learning_attempt_invalidations
for each row execute function public.queue_learning_invalidation_projection();

drop trigger if exists learner_question_exposures_updated_at on public.learner_question_exposures;
create trigger learner_question_exposures_updated_at
before update on public.learner_question_exposures
for each row execute function public.set_updated_at();

drop trigger if exists learning_projection_jobs_updated_at on public.learning_projection_jobs;
create trigger learning_projection_jobs_updated_at
before update on public.learning_projection_jobs
for each row execute function public.set_updated_at();

drop trigger if exists learner_skill_state_updated_at on public.learner_skill_state;
create trigger learner_skill_state_updated_at
before update on public.learner_skill_state
for each row execute function public.set_updated_at();

drop trigger if exists retention_schedules_updated_at on public.retention_schedules;
create trigger retention_schedules_updated_at
before update on public.retention_schedules
for each row execute function public.set_updated_at();

alter table public.learning_taxonomy_versions enable row level security;
alter table public.learning_skills enable row level security;
alter table public.question_revisions enable row level security;
alter table public.question_skill_mappings enable row level security;
alter table public.learner_question_exposures enable row level security;
alter table public.learning_fixture_runs enable row level security;
alter table public.learning_backfill_runs enable row level security;
alter table public.learning_attempts enable row level security;
alter table public.learning_attempt_classifications enable row level security;
alter table public.learning_attempt_invalidations enable row level security;
alter table public.learning_projection_jobs enable row level security;
alter table public.learner_skill_state enable row level security;
alter table public.retention_schedules enable row level security;
alter table public.learning_recommendations enable row level security;
alter table public.recommendation_events enable row level security;
alter table public.assessment_evidence enable row level security;

revoke all on table
  public.learning_taxonomy_versions,
  public.learning_skills,
  public.question_revisions,
  public.question_skill_mappings,
  public.learner_question_exposures,
  public.learning_fixture_runs,
  public.learning_backfill_runs,
  public.learning_attempts,
  public.learning_attempt_classifications,
  public.learning_attempt_invalidations,
  public.learning_projection_jobs,
  public.learner_skill_state,
  public.retention_schedules,
  public.learning_recommendations,
  public.recommendation_events,
  public.assessment_evidence
from public, anon, authenticated;

grant all on table
  public.learning_taxonomy_versions,
  public.learning_skills,
  public.question_revisions,
  public.question_skill_mappings,
  public.learner_question_exposures,
  public.learning_fixture_runs,
  public.learning_backfill_runs,
  public.learning_attempts,
  public.learning_attempt_classifications,
  public.learning_attempt_invalidations,
  public.learning_projection_jobs,
  public.learner_skill_state,
  public.retention_schedules,
  public.learning_recommendations,
  public.recommendation_events,
  public.assessment_evidence
to service_role;

grant select on table public.learning_taxonomy_versions, public.learning_skills to authenticated;
grant select on table
  public.learner_question_exposures,
  public.learning_attempts,
  public.learning_attempt_classifications,
  public.learning_attempt_invalidations,
  public.learner_skill_state,
  public.retention_schedules,
  public.learning_recommendations,
  public.recommendation_events,
  public.assessment_evidence
to authenticated;

-- Preserve legacy client mutation privileges while keeping every new
-- compatibility snapshot server-authoritative. Table-level INSERT/UPDATE grants
-- would otherwise allow older authenticated clients to spoof V2 evidence.
revoke insert, update on table public.practice_sessions from anon, authenticated;
grant insert (
  id, user_id, category, total_questions, correct_count, total_score, accuracy,
  started_at, finished_at, target, subcategory
) on table public.practice_sessions to authenticated;
grant update (
  id, user_id, category, total_questions, correct_count, total_score, accuracy,
  started_at, finished_at, target, subcategory
) on table public.practice_sessions to authenticated;

revoke insert, update on table public.practice_session_questions from anon, authenticated;

revoke insert, update on table public.practice_answers from anon, authenticated;
grant insert (
  id, session_id, user_id, question_id, question_order, selected_option_index,
  player_answer, is_correct, used_hint, response_time_ms, answered_at, created_at,
  session_question_id, idempotency_key, score_gained,
  correct_option_index_snapshot, explanation_snapshot
) on table public.practice_answers to authenticated;
grant update (
  id, session_id, user_id, question_id, question_order, selected_option_index,
  player_answer, is_correct, used_hint, response_time_ms, answered_at, created_at,
  session_question_id, idempotency_key, score_gained,
  correct_option_index_snapshot, explanation_snapshot
) on table public.practice_answers to authenticated;

drop policy if exists "Authenticated users can read learning taxonomy versions" on public.learning_taxonomy_versions;
create policy "Authenticated users can read learning taxonomy versions"
  on public.learning_taxonomy_versions for select to authenticated using (true);

drop policy if exists "Authenticated users can read learning skills" on public.learning_skills;
create policy "Authenticated users can read learning skills"
  on public.learning_skills for select to authenticated using (true);

drop policy if exists "Users can read their own learning exposures" on public.learner_question_exposures;
create policy "Users can read their own learning exposures"
  on public.learner_question_exposures for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own learning attempts" on public.learning_attempts;
create policy "Users can read their own learning attempts"
  on public.learning_attempts for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own attempt classifications" on public.learning_attempt_classifications;
create policy "Users can read their own attempt classifications"
  on public.learning_attempt_classifications for select to authenticated
  using (exists (
    select 1 from public.learning_attempts attempt
    where attempt.id = learning_attempt_classifications.attempt_id
      and attempt.user_id = auth.uid()
  ));

drop policy if exists "Users can read their own attempt invalidations" on public.learning_attempt_invalidations;
create policy "Users can read their own attempt invalidations"
  on public.learning_attempt_invalidations for select to authenticated
  using (attempt_id is not null and exists (
    select 1 from public.learning_attempts attempt
    where attempt.id = learning_attempt_invalidations.attempt_id
      and attempt.user_id = auth.uid()
  ));

drop policy if exists "Users can read their own learner skill state" on public.learner_skill_state;
create policy "Users can read their own learner skill state"
  on public.learner_skill_state for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own retention schedule" on public.retention_schedules;
create policy "Users can read their own retention schedule"
  on public.retention_schedules for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own learning recommendations" on public.learning_recommendations;
create policy "Users can read their own learning recommendations"
  on public.learning_recommendations for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own recommendation events" on public.recommendation_events;
create policy "Users can read their own recommendation events"
  on public.recommendation_events for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own assessment evidence" on public.assessment_evidence;
create policy "Users can read their own assessment evidence"
  on public.assessment_evidence for select to authenticated
  using (auth.uid() = user_id);

revoke all on function public.validate_question_skill_mapping() from public, anon, authenticated;
revoke all on function public.reject_learning_attempt_mutation() from public, anon, authenticated;
revoke all on function public.reject_learning_classification_mutation() from public, anon, authenticated;
revoke all on function public.reject_question_revision_mutation() from public, anon, authenticated;
revoke all on function public.reject_question_skill_mapping_mutation() from public, anon, authenticated;
revoke all on function public.reject_learning_invalidation_mutation() from public, anon, authenticated;
revoke all on function public.reject_recommendation_event_mutation() from public, anon, authenticated;
revoke all on function public.reject_assessment_evidence_mutation() from public, anon, authenticated;
revoke all on function public.enqueue_learning_projection(uuid, text, uuid, text, text, uuid) from public, anon, authenticated;
revoke all on function public.queue_learning_attempt_projection() from public, anon, authenticated;
revoke all on function public.queue_learning_invalidation_projection() from public, anon, authenticated;

grant execute on function public.validate_question_skill_mapping() to service_role;
grant execute on function public.reject_learning_attempt_mutation() to service_role;
grant execute on function public.reject_learning_classification_mutation() to service_role;
grant execute on function public.reject_question_revision_mutation() to service_role;
grant execute on function public.reject_question_skill_mapping_mutation() to service_role;
grant execute on function public.reject_learning_invalidation_mutation() to service_role;
grant execute on function public.reject_recommendation_event_mutation() to service_role;
grant execute on function public.reject_assessment_evidence_mutation() to service_role;
grant execute on function public.enqueue_learning_projection(uuid, text, uuid, text, text, uuid) to service_role;
grant execute on function public.queue_learning_attempt_projection() to service_role;
grant execute on function public.queue_learning_invalidation_projection() to service_role;

commit;
