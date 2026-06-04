# Backend Development Log

## 2026-06-02 - Backend Game PvP Core Slice

**The Change:**
- Added shared match contracts under `contracts/` for socket events, payloads, player-relative battle state, and public question cards.
- Implemented an in-memory `backend-game` PvP core with local questions, `QuestionDealer`, pure `GameEngine`, `RoomManager`, and `MatchService` orchestration.
- Reworked the `/match` Socket.IO gateway so it stays thin: Supabase auth, event handlers, service delegation, and emits.
- Added focused tests for player-scoped card consumption, public-state redaction, final-state ordering, matchmaking, and active-room queue rejection.

**The Reasoning:**
- YUDHA PvP is an independent real-time card battle, not a shared quiz round, so cards are scoped by `roomId + userId + cardId`.
- The same shared queue seeds both players' hands for fairness, while each player advances through draws independently.
- `game_state_update` is player-relative with `self` and `opponent` so Flutter can render the same room from either player's perspective without guessing roles.


**The Tech Debt:**
- Match results are not persisted to Supabase yet, and profile stats/rank/coins are not updated.
- Reconnect recovery, disconnect win/loss, room codes, bots, countdown timers, leaderboard, analytics, and practice APIs are still future slices.
- The local question pool is only an MVP seed; production should load curated questions from Supabase or a managed content pipeline.

## 2026-06-02 - Supabase Bootstrap Schema For New Project

**The Change:**
- Added `infra/supabase/bootstrap.sql` to recreate the core YUDHA database tables in a fresh Supabase project.
- Included `profiles`, `questions`, `practice_sessions`, `practice_answers`, and `match_results` with indexes, timestamp triggers, profile auto-creation from `auth.users`, and baseline RLS policies.

**The Reasoning:**
- The current backend expects `profiles` to exist with `rank_points`, `total_matches`, `wins`, `losses`, `winrate`, `coins`, and equipped cosmetic fields.
- Keeping the schema in the repo makes a lost/recreated Supabase project recoverable and gives the next persistence slice a clear target.
- The script keeps match persistence ready without forcing the backend-game core to write results yet.

**The Tech Debt:**
- The bootstrap does not include seed question data yet.
- Admin-only question management policies and service-role write flows still need to be formalized.
- Match result persistence and profile stat updates are still pending implementation in `backend-game`.

## 2026-06-02 - Team-Readable Supabase Schema Package

**The Change:**
- Expanded `infra/supabase/bootstrap.sql` into the full recoverable schema for profiles, questions, safe public question reads, practice, match history, match question pools, match logs, interview sessions/messages, institutions, documents, and document chunks.
- Added `infra/supabase/README.md` with database recovery steps for a fresh Supabase project.
- Added `infra/supabase/schema-reference.md` so teammates can understand the schema, RLS model, and table naming.
- Updated `.gitignore` to ignore generated TypeScript build-info files.

**The Reasoning:**
- The team needs the database schema visible in the repo, not only inside a Supabase project owned by one account.
- A runnable bootstrap plus human-readable docs makes database recovery repeatable if access is lost again.
- The `public_questions` view keeps client-facing question reads separate from the internal table that stores answer metadata.

**The Tech Debt:**
- The schema still needs seed data for questions and institutions.
- Backend persistence for `match_results`, `match_question_pool`, and `match_logs` is not implemented yet.
- Admin/service-role workflows for writing protected content tables still need to be built.

## 2026-06-02 - Supabase Auth API And Smoke Test Path

**The Change:**
- Added `POST /auth/register` and `POST /auth/login` in `apps/backend-api`.
- Registration forwards username/full-name metadata to Supabase Auth so the profile trigger can create the matching `profiles` row.
- Updated backend env examples to refer to the Supabase publishable key.
- Added `infra/supabase/auth-and-match-smoke-test.md` with manual register, login, profile, and match-socket verification steps.

**The Reasoning:**
- The backend-game match socket already requires a Supabase access token, so the app needed a concrete way to obtain that token.
- Keeping register/login in `backend-api` gives the team one simple smoke-test path before wiring Flutter to real auth.
- The publishable key is enough for normal Supabase Auth operations and RLS-protected user flows.

**The Tech Debt:**
- Flutter auth is still mock-only and needs to call these endpoints or Supabase Auth directly.
- Email confirmation may need to be disabled in local/dev Supabase settings or handled in the UI.
- Backend privileged writes for match persistence/profile stat updates will need a server-only key or dedicated SQL/RLS policy design.

## 2026-06-03

- Added `GET /interview/sessions` for authenticated users to retrieve their interview sessions from the `interview_sessions` table.
- Added repository support for listing owned interview sessions ordered by newest first.
- Returned compact session metadata including status, company, target role, mode, language, response style, final summary, and timestamps.

## 2026-06-03 - Leaderboard API Endpoints

**The Change:**
- Added a new `LeaderboardModule` in `apps/backend-api` and registered it in the main API module.
- Added `GET /leaderboard` to return ranked profile entries with pagination.
- Added authenticated `GET /leaderboard/me` to return the current user's leaderboard rank.
- Added leaderboard service/repository layers that read rank-ready stats from `profiles`.

**The Reasoning:**
- `profiles` already stores the current leaderboard state, including rank points, match totals, win/loss counts, winrate, and equipped cosmetics.
- Reading from `profiles` keeps leaderboard queries fast and avoids recalculating stats from match history on every request.
- The API follows the existing backend module pattern with a controller, service, repository, and Supabase-backed data access.

**The Tech Debt:**
- `full_name` and `created_at` are not currently present in the generated backend `profiles` type, so leaderboard responses omit `fullName` and use `id` as the final stable tie-breaker.
- `backend-game` still needs to persist completed match results and update profile stats/rank points after each match.
- `GET /leaderboard/around-me` is still a future UX endpoint.

## 2026-06-04 - Practice API And Question Session Locking

**The Change:**
- Added authenticated practice endpoints for dashboard, session creation, session reads, answer submission, early finish, and history.
- Added the practice v2 Supabase migration and updated `bootstrapv2.sql`/generated database types for `target`, `practice_session_questions`, and `practice_answers.session_question_id`.
- Added a question import helper for loading `apps/games/data/questions.json` into `public.questions`.
- Updated backend API config loading to prefer `apps/backend-api/.env` so local runs consistently use the intended Supabase project.

**The Reasoning:**
- Practice sessions now lock exactly five selected questions so answers are validated against the intended session state instead of re-querying a moving question pool.
- The backend reads `profiles.target` from the authenticated user and manually scopes all user-owned reads/writes because the service-role client bypasses RLS.
- The importer keeps the existing game question JSON usable as Supabase seed data without exposing answer metadata through client-facing endpoints.

**The Tech Debt:**
- The question importer is a script, not an admin API; production content management still needs a protected workflow.
- Practice dashboard labels currently mirror raw category ids instead of a localized display-name table.
- The practice repository uses multiple summary reads per dashboard/history request; larger datasets may need aggregate SQL/RPC helpers.

## 2026-06-04 - Required Registration Target

**The Change:**
- Updated `POST /auth/register` to require `target` and accept only `cpns` or `bumn`.
- Kept `fullName` nullable while still forwarding trimmed profile metadata to Supabase Auth.
- Added a Supabase migration and aligned `bootstrapv2.sql` so the profile signup trigger stores `target` and supports both `full_name` and mobile `display_name`.
- Updated the auth smoke-test registration payload and added focused auth service tests.

**The Reasoning:**
- Mobile registration asks for email, password, nama, and target belajar, so backend registration now requires the same target choice.
- Practice already scopes dashboards and sessions from `profiles.target`, so persisting the selected target at signup prevents new users from silently defaulting to CPNS.
- Limiting registration to `cpns` and `bumn` keeps the backend contract aligned with the current mobile `ProfileTarget` enum.

**The Tech Debt:**
- Existing Supabase projects must apply the new migration before registrations without `target` should be considered invalid at the database trigger level.
- The older schema/docs still mention `kedinasan` in some question/practice target constraints, so a future cleanup should decide whether to remove or reintroduce that target consistently.
- Mobile still signs up directly through Supabase Auth, so backend and trigger validation must stay in sync until mobile fully uses the backend auth endpoint.

## 2026-06-04 - Profile Read And Update Endpoint

**The Change:**
- Updated authenticated `GET /profile` to fetch all columns from the `profiles` table with `select('*')`.
- Added authenticated `PATCH /profile` so a user can update profile fields on their own profile row and receive the full updated row.
- Expanded backend Supabase profile types to include `full_name`, `created_at`, and `updated_at`.
- Added focused profile service/controller tests for full reads, updates, empty payload rejection, and Supabase error mapping.

**The Reasoning:**
- Mobile and future profile screens need the complete profile row instead of the older leaderboard-focused subset.
- The update path remains scoped by authenticated `user.id`, so callers cannot choose another user's profile id in the endpoint path.
- Returning the full row after update keeps client state refresh simple and consistent with the GET response shape.

**The Tech Debt:**
- The update payload is intentionally broad for now; future product rules should decide which profile columns are safe for user self-service edits.
- Database constraints still carry most validation for target/stat fields, so API-level validation may need to be added once profile editing UX is finalized.
