-- Returns no rows when the Solo Learning V2 alignment is healthy.

select answer.id, 'missing canonical attempt' as issue
from public.solo_answers answer
join public.solo_session_questions question on question.id = answer.session_question_id
where question.question_revision_id is not null
  and answer.canonical_attempt_id is null
union all
select answer.id, 'canonical attempt source mismatch' as issue
from public.solo_answers answer
join public.learning_attempts attempt on attempt.id = answer.canonical_attempt_id
where attempt.source <> 'solo'
   or attempt.source_attempt_key <> 'solo:' || answer.id::text
union all
select session.id, 'completed session lacks canonical stop fields' as issue
from public.solo_sessions session
where session.status = 'completed'
  and (session.completion_reason <> 'policy_completed'
    or session.policy_stop_trigger not in ('tower_destroyed', 'questions_completed'));
