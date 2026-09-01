-- Run immediately after 20260901120000_learning_v2_analytics_runtime.sql.
-- Every row must return passed = true. Row counts are informational.

with required_functions(signature) as (
  values
    ('public.create_practice_session_learning_v2(uuid,text,text,uuid)'),
    ('public.request_practice_hint_learning_v2(uuid,uuid,uuid,text,timestamptz)'),
    ('public.submit_practice_answer_learning_v2(uuid,uuid,text,uuid,integer,integer,timestamptz)'),
    ('public.finish_practice_session_learning_v2(uuid,uuid,text,timestamptz)'),
    ('public.claim_learning_projection_jobs(text,integer,timestamptz)'),
    ('public.ingest_pvp_learning_evidence(uuid)'),
    ('public.reconcile_recent_pvp_learning_evidence(timestamptz,integer)')
), checks(check_name, passed, detail) as (
  select
    'fixture_evidence_fk',
    exists (
      select 1
      from pg_constraint
      where conrelid = 'public.learning_attempts'::regclass
        and conname = 'learning_attempts_fixture_run_id_fkey'
        and confdeltype = 'r'
    ),
    'fixture audit rows cannot cascade-delete canonical evidence'
  union all
  select
    'runtime_columns',
    exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'learner_skill_state'
        and column_name = 'difficulty_level_count'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'learner_skill_state'
        and column_name = 'latest_strong_evidence_at'
    ),
    'learner state stores diversity and strong-evidence freshness'
  union all
  select
    'versioned_primary_mapping',
    to_regclass('public.question_skill_mappings_one_primary_idx') is not null
      and pg_get_indexdef('public.question_skill_mappings_one_primary_idx'::regclass)
        like '%question_revision_id, taxonomy_version_id%',
    'primary mapping uniqueness is scoped to question revision plus taxonomy version'
  union all
  select
    'runtime_functions',
    (select bool_and(to_regprocedure(signature) is not null) from required_functions),
    'all seven service-role Learning V2 runtime RPCs exist'
  union all
  select
    'runtime_function_permissions',
    (
      select bool_and(
        has_function_privilege('service_role', signature, 'EXECUTE')
        and not has_function_privilege('authenticated', signature, 'EXECUTE')
        and not has_function_privilege('anon', signature, 'EXECUTE')
      ) from required_functions
    ),
    'runtime RPCs are executable by service role only'
  union all
  select
    'profile_projection_trigger',
    exists (
      select 1 from pg_trigger
      where tgrelid = 'public.profiles'::regclass
        and tgname = 'profiles_learning_projection_queue'
        and not tgisinternal and tgenabled <> 'D'
    ),
    'new learner profiles enqueue an initial projection'
  union all
  select
    'queued_existing_profiles',
    not exists (
      select 1 from public.profiles profile
      where profile.target in ('cpns', 'bumn')
        and not exists (
          select 1 from public.learning_projection_jobs job
          where job.user_id = profile.id and job.target = profile.target
        )
        and not exists (
          select 1 from public.learner_skill_state state
          where state.user_id = profile.id and state.target = profile.target
        )
    ),
    'existing target profiles have projection work or prepared state'
  union all
  select
    'informational_row_counts',
    true,
    jsonb_build_object(
      'projectionJobs', (select count(*) from public.learning_projection_jobs),
      'skillStates', (select count(*) from public.learner_skill_state),
      'recommendations', (select count(*) from public.learning_recommendations),
      'attempts', (select count(*) from public.learning_attempts)
    )::text
)
select check_name, passed, detail
from checks
order by case when check_name = 'informational_row_counts' then 2 else 1 end, check_name;
