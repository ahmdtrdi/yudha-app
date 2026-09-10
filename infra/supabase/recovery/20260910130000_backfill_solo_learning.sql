-- Run AFTER migrations/20260910130000_restore_solo_learning_ingestion.sql.
-- Recovers all missing Solo evidence from persisted source answers. Safe to rerun.
-- No gameplay/reward/exposure replay; no updates/deletes to existing attempts.
begin;

do $$
declare
  v_answer record;
  v_count integer := 0;
begin
  for v_answer in
    select answer.id
    from public.solo_answers answer
    left join public.learning_attempts attempt
      on attempt.source = 'solo' and attempt.source_attempt_key = 'solo:' || answer.id::text
    left join public.learning_attempt_classifications classification
      on classification.attempt_id = attempt.id
      and classification.classification_version = 'evidence-v1'
    where answer.canonical_attempt_id is null or classification.attempt_id is null
    order by answer.answered_at, answer.id
  loop
    perform public.ingest_solo_answer_learning_evidence(v_answer.id);
    v_count := v_count + 1;
  end loop;
  raise notice 'Recovered or linked % Solo answers.', v_count;
end;
$$;

-- Refresh every affected learner, including expired recommendations whose
-- earlier enqueue failed. The backend worker calculates the prepared states.
select public.enqueue_learning_projection(
  learner.user_id, learner.target, null, null, 'backfill'
)
from (
  select distinct user_id, target from public.solo_sessions
  where answered_count > 0
) learner;

commit;
