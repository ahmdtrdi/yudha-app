# Supabase Schema

This folder is the recovery source for the YUDHA Supabase database.

Use it when:

- creating a new Supabase project
- restoring the schema after losing access to an old database
- helping teammates understand the database structure
- preparing the next backend persistence slice

## Files

- `bootstrap.sql`: base schema for a fresh Supabase project.
- `migrations/`: ordered schema changes that must be applied after the base schema.
- `postchecks/`: read-only verification queries paired with manual cloud migrations.
- `tests/`: pgTAP database contract tests for local Supabase and CI.
- `schema-reference.md`: human-readable explanation of the tables, views, policies, and intended implementation order.
- `auth-and-match-smoke-test.md`: manual register/login/profile/match verification steps.

## Recreate The Database

1. Create or open a Supabase project.
2. Open **SQL Editor**.
3. Paste all of `infra/supabase/bootstrap.sql` and run it.
4. Apply every SQL file in `infra/supabase/migrations/` in filename order.
5. Copy the new project credentials into backend environment files:
   - `SUPABASE_URL`
   - `SUPABASE_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
6. Create a test user through Supabase Auth.
7. Confirm a row is automatically created in `public.profiles`.
8. Follow `auth-and-match-smoke-test.md` to verify register, login, profile fetch, and match socket auth.

## Learning V2 Manual Cloud Checkpoint

Learning Analytics + Recommendation V2 is intentionally gated before any
taxonomy synchronization, backfill, fixture insertion, or API rollout:

1. In Supabase Cloud SQL Editor, paste and run the complete transaction in
   `migrations/20260901090000_learning_v2_analytics_foundation.sql`.
2. In a new SQL Editor query, run
   `postchecks/20260901090000_learning_v2_analytics_foundation.sql`.
3. Confirm every row returns `passed = true`. The final informational row should
   report zero rows in the new tables before Phase 2 seeds or backfills them.
4. Save or share the complete postcheck result before enabling backend reads.

Phase 1 is followed by a second manual runtime checkpoint:

1. Run the complete transaction in
   `migrations/20260901120000_learning_v2_analytics_runtime.sql`.
2. Run
   `postchecks/20260901120000_learning_v2_analytics_runtime.sql` and confirm
   every row reports `passed = true`.
3. From `infra/`, run `npm run learning:v2 -- sync`, then dry-run and apply the
   Practice/PvP backfills with explicit run keys.
4. Leave `LEARNING_V2_ENABLED=false` until content and backfill reports are
   reviewed. Enable it only for the cloud smoke test and rollout environment.

Do not run development fixtures against a real learner. Phase 2 requires an
explicit disposable cloud user ID and records the owning fixture run so the
evidence can be invalidated and rebuilt without deleting ledger rows.

## Important Security Notes

- `auth.users` is the source user table. Do not create a custom `users` table.
- `public.questions` contains `correct_option_index`, so frontend clients should not read it directly.
- `public.public_questions` hides answer metadata and is safe for client-facing reads.
- Learning V2 question revisions, canonical attempts, classifications,
  invalidations, projections, recommendations, and events are written only by
  the service role. Authenticated users can read only safe taxonomy data and
  their own learner records.
- Backend services using the service role key can bypass RLS when needed.

## Suggested Implementation Order

The full schema is available now, but backend work should stay incremental:

1. `match_results`
2. profile stat updates
3. `match_question_pool`
4. `match_logs`
5. leaderboard/history APIs
6. practice tables
7. interview tables
8. document/RAG tables
