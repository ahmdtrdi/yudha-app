alter table public.match_results
  drop constraint if exists match_results_reason_check;

alter table public.match_results
  add constraint match_results_reason_check
  check (
    reason in (
      'hp_zero',
      'round_timeout',
      'surrender',
      'question_exhaustion',
      'draw',
      'disconnect'
    )
  );
