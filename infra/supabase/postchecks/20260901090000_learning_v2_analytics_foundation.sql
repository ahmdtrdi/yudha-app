-- Run this in Supabase Cloud SQL Editor immediately after
-- 20260901090000_learning_v2_analytics_foundation.sql.
-- Every row except informational_row_counts must return passed = true.

with required_tables(table_name) as (
  values
    ('learning_taxonomy_versions'),
    ('learning_skills'),
    ('question_revisions'),
    ('question_skill_mappings'),
    ('learner_question_exposures'),
    ('learning_fixture_runs'),
    ('learning_backfill_runs'),
    ('learning_recommendations'),
    ('learning_attempts'),
    ('learning_attempt_classifications'),
    ('learning_attempt_invalidations'),
    ('learning_projection_jobs'),
    ('learner_skill_state'),
    ('retention_schedules'),
    ('recommendation_events'),
    ('assessment_evidence')
),
missing_tables as (
  select table_name
  from required_tables
  where to_regclass('public.' || table_name) is null
),
required_rls_tables(table_name) as (
  select table_name from required_tables
),
missing_rls as (
  select required.table_name
  from required_rls_tables required
  left join pg_class relation
    on relation.oid = to_regclass('public.' || required.table_name)
  where relation.oid is null or not relation.relrowsecurity
),
required_compat_columns(table_name, column_name) as (
  values
    ('practice_sessions', 'recommendation_id'),
    ('practice_sessions', 'taxonomy_version_id'),
    ('practice_sessions', 'learning_objective'),
    ('practice_sessions', 'requested_mechanic_mode'),
    ('practice_sessions', 'effective_mechanic_mode'),
    ('practice_sessions', 'question_selection_type'),
    ('practice_sessions', 'evidence_capture_version'),
    ('practice_session_questions', 'question_revision_id'),
    ('practice_session_questions', 'taxonomy_version_id'),
    ('practice_session_questions', 'skill_id'),
    ('practice_session_questions', 'exposure_count_before'),
    ('practice_session_questions', 'seen_before'),
    ('practice_session_questions', 'hint_requested_at'),
    ('practice_session_questions', 'hint_idempotency_key'),
    ('practice_session_questions', 'opened_at'),
    ('practice_answers', 'canonical_attempt_id')
),
missing_compat_columns as (
  select required.table_name || '.' || required.column_name as qualified_name
  from required_compat_columns required
  left join information_schema.columns column_info
    on column_info.table_schema = 'public'
   and column_info.table_name = required.table_name
   and column_info.column_name = required.column_name
  where column_info.column_name is null
),
checks(check_name, passed, detail) as (
  select
    'required_tables',
    not exists (select 1 from missing_tables),
    case
      when exists (select 1 from missing_tables)
        then 'missing=' || (select string_agg(table_name, ', ' order by table_name) from missing_tables)
      else 'all 16 Learning V2 foundation tables exist'
    end
  union all
  select
    'row_level_security',
    not exists (select 1 from missing_rls),
    case
      when exists (select 1 from missing_rls)
        then 'missing_or_disabled=' || (select string_agg(table_name, ', ' order by table_name) from missing_rls)
      else 'RLS is enabled on every new table'
    end
  union all
  select
    'compatibility_columns',
    not exists (select 1 from missing_compat_columns),
    case
      when exists (select 1 from missing_compat_columns)
        then 'missing=' || (select string_agg(qualified_name, ', ' order by qualified_name) from missing_compat_columns)
      else 'Practice compatibility columns are present'
    end
  union all
  select
    'canonical_source_uniqueness',
    exists (
      select 1
      from pg_constraint
      where conrelid = 'public.learning_attempts'::regclass
        and conname = 'learning_attempts_source_unique'
        and contype = 'u'
    ),
    'learning_attempts(source, source_attempt_key) is unique'
  union all
  select
    'one_active_recommendation',
    to_regclass('public.learning_recommendations_one_active_idx') is not null,
    'one active recommendation index exists per user and target'
  union all
  select
    'append_only_triggers',
    (
      select count(*) = 7
      from pg_trigger
      where not tgisinternal
        and tgenabled <> 'D'
        and tgname in (
          'learning_attempts_append_only_guard',
          'learning_classifications_append_only_guard',
          'learning_invalidations_append_only_guard',
          'question_revisions_append_only_guard',
          'question_skill_mappings_append_only_guard',
          'recommendation_events_append_only_guard',
          'assessment_evidence_append_only_guard'
        )
    ),
    'raw evidence, classifications, invalidations, mappings, and event ledgers have enabled mutation guards'
  union all
  select
    'projection_queue_trigger',
    exists (
      select 1
      from pg_trigger
      where tgrelid = 'public.learning_attempts'::regclass
        and tgname = 'learning_attempts_projection_queue'
        and not tgisinternal
        and tgenabled <> 'D'
    ),
    'attempt inserts enqueue targeted projection work'
  union all
  select
    'invalidation_queue_trigger',
    exists (
      select 1
      from pg_trigger
      where tgrelid = 'public.learning_attempt_invalidations'::regclass
        and tgname = 'learning_invalidations_projection_queue'
        and not tgisinternal
        and tgenabled <> 'D'
    ),
    'attempt and revision invalidations enqueue targeted projection work'
  union all
  select
    'projection_function_permissions',
    has_function_privilege(
      'service_role',
      'public.enqueue_learning_projection(uuid,text,uuid,text,text,uuid)',
      'EXECUTE'
    ) and not has_function_privilege(
      'authenticated',
      'public.enqueue_learning_projection(uuid,text,uuid,text,text,uuid)',
      'EXECUTE'
    ),
    'projection enqueue is service-role only'
  union all
  select
    'learner_write_permissions',
    (
      select bool_and(
        not has_table_privilege(
          'authenticated',
          format('public.%I', required.table_name),
          'INSERT,UPDATE,DELETE'
        )
      )
      from required_tables required
    ),
    'authenticated clients cannot write any Learning V2 table directly'
  union all
  select
    'service_role_permissions',
    (
      select bool_and(
        has_table_privilege(
          'service_role',
          format('public.%I', required.table_name),
          'INSERT,UPDATE,DELETE,SELECT'
        )
      )
      from required_tables required
    ),
    'service role can operate every Learning V2 table'
  union all
  select
    'authenticated_read_policies',
    (
      select count(*) >= 11
      from pg_policies
      where schemaname = 'public'
        and tablename in (
          'learning_taxonomy_versions', 'learning_skills',
          'learner_question_exposures', 'learning_attempts',
          'learning_attempt_classifications', 'learning_attempt_invalidations',
          'learner_skill_state', 'retention_schedules',
          'learning_recommendations', 'recommendation_events', 'assessment_evidence'
        )
        and cmd = 'SELECT'
    ),
    'safe taxonomy and owned learner records have SELECT policies'
  union all
  select
    'sensitive_content_permissions',
    not has_table_privilege('authenticated', 'public.question_revisions', 'SELECT')
      and not has_table_privilege('anon', 'public.question_revisions', 'SELECT'),
    'question revision answers remain server-only'
  union all
  select
    'compatibility_column_authority',
    has_column_privilege('authenticated', 'public.practice_sessions', 'category', 'INSERT')
      and not has_column_privilege('authenticated', 'public.practice_sessions', 'recommendation_id', 'INSERT')
      and not has_column_privilege('authenticated', 'public.practice_sessions', 'recommendation_id', 'UPDATE')
      and not has_column_privilege('authenticated', 'public.practice_session_questions', 'hint_requested_at', 'UPDATE')
      and not has_column_privilege('authenticated', 'public.practice_answers', 'canonical_attempt_id', 'INSERT')
      and not has_column_privilege('authenticated', 'public.practice_answers', 'canonical_attempt_id', 'UPDATE'),
    'legacy Practice writes remain compatible while V2 snapshots are server-authoritative'
  union all
  select
    'informational_row_counts',
    true,
    jsonb_build_object(
      'taxonomyVersions', (select count(*) from public.learning_taxonomy_versions),
      'skills', (select count(*) from public.learning_skills),
      'questionRevisions', (select count(*) from public.question_revisions),
      'attempts', (select count(*) from public.learning_attempts),
      'skillStates', (select count(*) from public.learner_skill_state),
      'recommendations', (select count(*) from public.learning_recommendations)
    )::text
)
select check_name, passed, detail
from checks
order by case when check_name = 'informational_row_counts' then 2 else 1 end, check_name;
