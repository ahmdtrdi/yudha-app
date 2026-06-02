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
