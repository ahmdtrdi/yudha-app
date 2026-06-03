# Supabase Schema

This folder is the recovery source for the YUDHA Supabase database.

Use it when:

- creating a new Supabase project
- restoring the schema after losing access to an old database
- helping teammates understand the database structure
- preparing the next backend persistence slice

## Files

- `bootstrap.sql`: runnable SQL for a fresh Supabase project.
- `schema-reference.md`: human-readable explanation of the tables, views, policies, and intended implementation order.

## Recreate The Database

1. Create or open a Supabase project.
2. Open **SQL Editor**.
3. Paste all of `infra/supabase/bootstrap.sql`.
4. Run the script.
5. Copy the new project credentials into backend environment files:
   - `SUPABASE_URL`
   - `SUPABASE_KEY`
6. Create a test user through Supabase Auth.
7. Confirm a row is automatically created in `public.profiles`.

## Important Security Notes

- `auth.users` is the source user table. Do not create a custom `users` table.
- `public.questions` contains `correct_option_index`, so frontend clients should not read it directly.
- `public.public_questions` hides answer metadata and is safe for client-facing reads.
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
