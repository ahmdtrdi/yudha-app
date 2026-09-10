-- Run after migration + recovery. First result must contain ZERO rows.
select answer.id as answer_id, answer.session_id, 'missing or mismatched canonical attempt' as issue
from public.solo_answers answer
left join public.learning_attempts attempt on attempt.id = answer.canonical_attempt_id
where attempt.id is null
   or attempt.source <> 'solo'
   or attempt.source_attempt_key <> 'solo:' || answer.id::text
   or attempt.user_id <> answer.user_id
   or attempt.source_session_key is distinct from answer.session_id::text
union all
select answer.id, answer.session_id, 'missing evidence-v1 classification'
from public.solo_answers answer
where answer.canonical_attempt_id is not null and not exists (
  select 1 from public.learning_attempt_classifications classification
  where classification.attempt_id = answer.canonical_attempt_id
    and classification.classification_version = 'evidence-v1'
);

-- Inspect coverage; legacy_solo restores activity only, not guessed skill evidence.
select session.id as session_id, session.user_id, session.status,
  session.answered_count, count(answer.id) as stored_answers,
  count(attempt.id) as linked_learning_attempts,
  count(attempt.id) filter (where attempt.data_fidelity = 'v2_complete') as skill_evidence_answers,
  count(attempt.id) filter (where attempt.data_fidelity = 'legacy_solo') as legacy_activity_answers
from public.solo_sessions session
left join public.solo_answers answer on answer.session_id = session.id
left join public.learning_attempts attempt on attempt.id = answer.canonical_attempt_id
group by session.id
order by session.started_at desc;

-- After deploying backend-api with LEARNING_V2_ENABLED=true, these jobs should
-- become completed. Re-run this SELECT after the worker has had time to drain.
select user_id, target, reason, status, last_error, updated_at
from public.learning_projection_jobs
where reason = 'backfill'
order by updated_at desc;
