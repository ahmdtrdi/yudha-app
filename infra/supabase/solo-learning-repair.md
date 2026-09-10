# Solo Learning Center repair — 2026-09-10

The September 3 focus/speed migration replaced `submit_solo_answer` without its
canonical learning writes. A separate backend bug passed a taxonomy without a
skill when expiring recommendations, interrupting that worker run.

## Cloud run order

Run only these new files against the existing database. All cloud SQL execution
is reserved for the owner; no cloud SQL was executed during implementation.

1. Paste and run the entire transaction in
   [the repair migration](migrations/20260910130000_restore_solo_learning_ingestion.sql).
   This installs the shared ingestion function and restores the answer RPC while
   preserving standard/focus/speed gameplay. It does not backfill historical rows.
2. Deploy the updated `backend-api` and keep `LEARNING_V2_ENABLED=true`. It queues
   recommendation expiry with both taxonomy and skill omitted and processes
   projection jobs even when a maintenance task fails.
3. Paste and run the entire transaction in
   [the recovery script](recovery/20260910130000_backfill_solo_learning.sql).
   It recovers missing attempts, missing classifications, and missing answer links
   across all learners, then queues full learner rebuilds. It is safe to rerun.
4. Run [the read-only postcheck](postchecks/20260910130000_restore_solo_learning_ingestion.sql).
   The first result must return **zero rows**. The second compares stored answers
   with linked attempts. The third shows recovery jobs; wait for the minute-based
   worker to finish and rerun this check until the jobs complete without errors.
5. Refresh Learning Center. Complete a new Solo session and confirm its answers
   have non-null `canonical_attempt_id` values, matching `learning_attempts` and
   `evidence-v1` classifications, and updated `learner_skill_state` rows.

The migration is designed for the existing schema through the September 3 Solo
focus/speed changes. Do not replay the old September 2 answer function by itself:
that would replace focus/speed behavior. Do not use a full bootstrap or blanket
database push for this repair.

## Recovery behavior

- Saved revision, taxonomy, skill, exposure, hint, and timing evidence are used
  when available. Current question mappings are never substituted for missing
  historical metadata.
- Pre-alignment answers without complete saved metadata are marked `legacy_solo`.
  They restore activity history but do not invent Peta Skill proficiency.
- Existing canonical attempts and classifications remain immutable. Missing rows
  are inserted; missing `solo_answers.canonical_attempt_id` links are restored.
- Recovery does not replay sessions, coins, energy, streaks, or exposure counts.
  Synthetic fixtures are left unchanged.
- The backend still scopes the dashboard to the learner's current target and
  latest taxonomy; activity uses its existing 30-day window.

## Local verification

Backend regression tests cover valid whole-user expiry jobs, queue retryability,
worker failure isolation, and prevention of overlapping worker runs.

The standalone PostgreSQL regression runner uses PGlite with the repository's
actual Learning/Solo table constraints and functions. It does not read `.env`,
contact Supabase, or connect to production. Auth hosting and the SHA-256 digest
wrapper are supplied locally; unrelated economy/streak triggers are not booted.

With `@electric-sql/pglite` available, run from the repository root:

```powershell
node infra/supabase/tests/run-solo-learning-regression.mjs <path-to-pglite/dist/index.js>
```

It reproduces the previous bug, runs the migration twice, covers all mechanics,
idempotent and cached retries, hint/exposure/timing exclusions, session completion,
reward idempotency, atomic failure rollback, legacy recovery, missing link and
classification repair, recovery reruns, permissions, and the read-only postcheck.
