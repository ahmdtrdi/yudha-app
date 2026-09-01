begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(52);

select has_table('public', 'learning_taxonomy_versions', 'taxonomy version table exists');
select has_table('public', 'learning_skills', 'versioned skill table exists');
select has_table('public', 'question_revisions', 'immutable question revision table exists');
select has_table('public', 'question_skill_mappings', 'question-to-skill mapping table exists');
select has_table('public', 'learner_question_exposures', 'lifetime exposure table exists');
select has_table('public', 'learning_fixture_runs', 'synthetic fixture audit table exists');
select has_table('public', 'learning_backfill_runs', 'legacy backfill audit table exists');
select has_table('public', 'learning_recommendations', 'stored recommendation table exists');
select has_table('public', 'learning_attempts', 'canonical attempt ledger exists');
select has_table('public', 'learning_attempt_classifications', 'versioned classification table exists');
select has_table('public', 'learning_attempt_invalidations', 'attempt invalidation table exists');
select has_table('public', 'learning_projection_jobs', 'projection queue exists');
select has_table('public', 'learner_skill_state', 'prepared learner state exists');
select has_table('public', 'retention_schedules', 'retention schedule exists');
select has_table('public', 'recommendation_events', 'recommendation event ledger exists');
select has_table('public', 'assessment_evidence', 'assessment evidence boundary exists');

select has_column('public', 'practice_sessions', 'recommendation_id', 'Practice can reference a recommendation');
select has_column('public', 'practice_sessions', 'taxonomy_version_id', 'Practice snapshots taxonomy version');
select has_column('public', 'practice_sessions', 'learning_objective', 'Practice snapshots learning objective');
select has_column('public', 'practice_sessions', 'requested_mechanic_mode', 'Practice stores requested mechanic');
select has_column('public', 'practice_sessions', 'effective_mechanic_mode', 'Practice stores effective mechanic');
select has_column('public', 'practice_sessions', 'question_selection_type', 'Practice stores question selection');
select has_column('public', 'practice_sessions', 'evidence_capture_version', 'Practice declares capture fidelity');
select has_column('public', 'practice_session_questions', 'question_revision_id', 'Presented question snapshots revision');
select has_column('public', 'practice_session_questions', 'taxonomy_version_id', 'Presented question snapshots taxonomy');
select has_column('public', 'practice_session_questions', 'skill_id', 'Presented question snapshots skill');
select has_column('public', 'practice_session_questions', 'exposure_count_before', 'Presented question snapshots exposure count');
select has_column('public', 'practice_session_questions', 'seen_before', 'Presented question snapshots seen state');
select has_column('public', 'practice_session_questions', 'hint_requested_at', 'Presented question stores authoritative hint time');
select has_column('public', 'practice_session_questions', 'hint_idempotency_key', 'Hint mutation is idempotent');
select has_column('public', 'practice_session_questions', 'opened_at', 'Presented question can store open time');
select has_column('public', 'practice_answers', 'canonical_attempt_id', 'Practice answer can link canonical attempt');

select has_trigger('public', 'question_skill_mappings', 'question_skill_mappings_target_guard', 'question and skill targets must match');
select has_trigger('public', 'question_revisions', 'question_revisions_append_only_guard', 'question revisions are append-only');
select has_trigger('public', 'question_skill_mappings', 'question_skill_mappings_append_only_guard', 'question skill mappings are append-only');
select has_trigger('public', 'learning_attempts', 'learning_attempts_append_only_guard', 'canonical attempts are append-only');
select has_trigger('public', 'learning_attempts', 'learning_attempts_projection_queue', 'attempt insert queues projection work');
select has_trigger('public', 'learning_attempt_invalidations', 'learning_invalidations_append_only_guard', 'attempt invalidations are append-only');
select has_trigger('public', 'learning_attempt_invalidations', 'learning_invalidations_projection_queue', 'invalidation inserts queue projection work');
select has_trigger('public', 'recommendation_events', 'recommendation_events_append_only_guard', 'recommendation events are append-only');
select has_trigger('public', 'assessment_evidence', 'assessment_evidence_append_only_guard', 'assessment evidence is append-only');

select ok(
  to_regprocedure('public.enqueue_learning_projection(uuid,text,uuid,text,text,uuid)') is not null,
  'projection enqueue function exists'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.enqueue_learning_projection(uuid,text,uuid,text,text,uuid)',
    'EXECUTE'
  ),
  'service role can enqueue projections'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.enqueue_learning_projection(uuid,text,uuid,text,text,uuid)',
    'EXECUTE'
  ),
  'authenticated users cannot enqueue projections directly'
);
select ok(
  (
    select bool_and(relation.relrowsecurity)
    from unnest(array[
      'learning_taxonomy_versions', 'learning_skills', 'question_revisions',
      'question_skill_mappings', 'learner_question_exposures', 'learning_fixture_runs',
      'learning_backfill_runs', 'learning_recommendations', 'learning_attempts',
      'learning_attempt_classifications', 'learning_attempt_invalidations',
      'learning_projection_jobs', 'learner_skill_state', 'retention_schedules',
      'recommendation_events', 'assessment_evidence'
    ]) as required(table_name)
    join pg_class relation on relation.oid = to_regclass('public.' || required.table_name)
  ),
  'RLS is enabled on every Learning V2 table'
);
select ok(
  not has_table_privilege('authenticated', 'public.learning_attempts', 'INSERT,UPDATE,DELETE')
    and not has_table_privilege('authenticated', 'public.learner_skill_state', 'INSERT,UPDATE,DELETE')
    and not has_table_privilege('authenticated', 'public.learning_recommendations', 'INSERT,UPDATE,DELETE'),
  'authenticated users cannot write evidence or projections directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.question_revisions', 'SELECT')
    and not has_table_privilege('anon', 'public.question_revisions', 'SELECT'),
  'question revision answers remain server-only'
);
select ok(
  has_column_privilege('authenticated', 'public.practice_sessions', 'category', 'INSERT')
    and not has_column_privilege('authenticated', 'public.practice_sessions', 'recommendation_id', 'INSERT')
    and not has_column_privilege('authenticated', 'public.practice_sessions', 'recommendation_id', 'UPDATE')
    and not has_column_privilege('authenticated', 'public.practice_session_questions', 'hint_requested_at', 'UPDATE')
    and not has_column_privilege('authenticated', 'public.practice_answers', 'canonical_attempt_id', 'INSERT')
    and not has_column_privilege('authenticated', 'public.practice_answers', 'canonical_attempt_id', 'UPDATE'),
  'new Practice compatibility evidence remains server-authoritative'
);
select has_constraint(
  'public',
  'learning_attempts',
  'learning_attempts_source_unique',
  'source plus source-attempt key is unique'
);
select has_index(
  'public',
  'learning_recommendations',
  'learning_recommendations_one_active_idx',
  'only one active recommendation exists per user and target'
);
select has_index(
  'public',
  'learning_projection_jobs',
  'learning_projection_jobs_pending_unique_idx',
  'pending projection work is deduplicated'
);
select has_index(
  'public',
  'practice_answers',
  'practice_answers_canonical_attempt_unique_idx',
  'a canonical attempt maps to at most one Practice answer'
);

select * from finish();
rollback;
