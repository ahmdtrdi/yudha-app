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

## 2026-07-13 - Match Result Persistence + Post-Match Profile Stats

**The Change:**
- Created SQL migration `infra/supabase/migrations/20260713000000_finalize_match_result.sql` with a Postgres RPC function `finalize_match_result` that atomically inserts a `match_results` row and updates both players' `profiles` rows.
- Added `getAdminClient()` to the game backend's `SupabaseService` using `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS for server-side writes.
- Created `MatchResultService` (`apps/backend-game/src/match/results/match-result.service.ts`) that maps `InternalRoomState` to RPC parameters, calls the RPC with retry-once logic (500ms delay), and logs failures without throwing.
- Created `match-result.constants.ts` with configurable rating/coin reward amounts (Win: +20 rating/10 coins, Lose: -12 rating/3 coins, Draw: 0 rating/5 coins).
- Hooked `MatchResultService` into `MatchService.handlePlayCard` and `handleSurrender` — persistence runs before `scheduleCleanup` so match data is saved before the 2-second garbage collection.
- Extended `MatchResultPayload` in `contracts/match.payloads.ts` with optional `ratingDelta` and `coinsDelta` fields per player so Flutter can display stat changes immediately.
- Made `handlePlayCard`/`handleSurrender` in `MatchGateway` async to properly await the now-async service methods.
- Updated `.env.example` to document the `SUPABASE_SERVICE_ROLE_KEY` requirement.
- Fixed `match.service.spec.ts` with a mock `MatchResultService` provider.

**The Reasoning:**
- Postgres RPC guarantees atomicity — a match is never recorded without its stat update, and vice versa. `ON CONFLICT (room_id) DO NOTHING` provides idempotency against double-fire.
- `security definer` on the RPC lets it bypass RLS safely for this one controlled write path without exposing a broad service-role key to arbitrary table writes.
- Fire-and-forget persistence ensures Socket.IO events are never blocked by DB write latency or failures. Errors are logged with `MATCH_PERSIST_FAILED` tag for manual reconciliation.
- Bot matches are designed to affect coins only (no `rank_points` change) to prevent rating farming, though bot mode is not yet implemented.
- Rating delta calculation lives exclusively in SQL so backend-api and backend-game can never disagree on reward math opreation

**The Tech Debt:**
- The `finalize_match_result` SQL migration must be applied manually to Supabase (SQL editor or `supabase db push`) before match persistence will work.
- Bot battle mode is not yet implemented — `p_mode` is always `'player'`. When bots are added, `MatchResultService.buildRpcParams()` must be updated.
- Coin reward amounts (10/3/5) are placeholder — product needs to confirm actual values.
- No dead-letter queue for failed persistence — if both attempts fail, the match result is only logged, not queued for retry.
- `match_logs` per-action audit trail and `GET /matches` history endpoint are still separate future tickets.

## 2026-07-13 - Bot Battle Mode (vs Bot)

**The Change:**
- Extended `JoinQueuePayload.mode` in `contracts/match.payloads.ts` to accept `'bot'` alongside `'ranked'` and `'casual'`.
- Added `RoomManager.createBotRoom()` that creates a room with the human player as `playerA` and a synthetic bot participant (`userId: 'bot'`, `socketId: null`, `connected: true`) as `playerB`, bypassing the matchmaking queue entirely.
- Created `BotBattleService` (`apps/backend-game/src/match/bot/bot-battle.service.ts`) that manages the bot match lifecycle: room creation, scheduled bot turns (3.3–5.9s random delay per PRD §3.2), card selection (damage-first, fallback to first available), answer resolution, async event emission to the human player, and timer cleanup on all match-end paths.
- Branched `MatchService.handleJoinQueue` on `mode === 'bot'` to skip the queue and emit `match_found` + initial `game_state_update` immediately — no `queue_joined` step.
- Added `cancelBotSchedule(roomId)` calls in `handlePlayCard`, `handleSurrender`, and `handleDisconnect` to prevent leaked timers when a match ends from the human side.
- Implemented `OnGatewayInit` in `MatchGateway` with an `afterInit()` hook that wires `BotBattleService`'s emit callback to the Socket.IO `Server` instance, enabling async bot turns to push events to the human player's socket outside the normal request/response flow.
- Updated `MatchResultService.buildRpcParams()` to detect bot matches (`playerB.userId === 'bot'`) and set `p_player_b_id = null`, `p_mode = 'bot'`, and sanitize winner/loser IDs so the literal string `'bot'` never reaches the database.
- Registered `BotBattleService` in `MatchModule` providers.

**The Reasoning:**
- The bot passes the card's `correctOptionIndex` directly into `engine.playCard()` as its `selectedOptionIndex`, achieving "always answers correctly" with zero `GameEngine` modifications. All damage/heal math stays centralized in the engine — the bot is just another "player" from the engine's perspective.
- A single `cancelBotSchedule(roomId)` method is called from every match-end branch (play-card finish, surrender, disconnect) to avoid the most common bug pattern in timer-driven features: a leaked timer firing into a disposed room.
- Bot matches use `p_mode = 'bot'` in the persistence RPC so the database can distinguish bot results and skip `rank_points` deltas while still awarding coins and updating `total_matches`.
- The async emit callback pattern (gateway → service → bot service) keeps `BotBattleService` decoupled from the Socket.IO `Server` instance while still allowing timer-driven bot actions to emit events to the human player.

**The Tech Debt:**
- The bot uses a hardcoded `userId: 'bot'` string — if multiple concurrent bot matches are needed per-user this works fine (keyed by `roomId`), but the `userToRoom` map currently maps `'bot'` to only one room. Concurrent bot matches from different users would need per-room bot IDs (e.g. `bot_${roomId}`).
- Bot card selection is simple damage-preference only — no HP-aware defensive strategy (heal when low). Product flagged as a potential future enhancement.
- Question exhaustion and recycling interact with bot matches the same way as PvP — once recycling is implemented, bot matches will inherit it automatically.
- The `match.service.spec.ts` test may need a mock `BotBattleService` provider added to its test module setup.

## 2026-07-13 - Content Correctness: Supabase Questions + Heal Value Fix

**The Change:**
- Replaced the 12 hardcoded questions in `QuestionService` with async reads from the Supabase `questions` table via the service-role admin client. Reads go to the base table (not `public_questions` view) because the game backend needs `correct_option_index` server-side for answer validation.
- Questions are fetched once at match creation (`getMatchQuestionPool(target)`) and cached in room state — no Supabase round-trip occurs during `open_card`/`play_card`.
- Added `buildBalancedPool()` that distributes questions evenly across TWK/TIU/TKP categories (4/4/4 = 12 pool), shuffles within each, backfills from other categories when one is short, then does a final shuffle so categories aren't grouped in the dealt hand.
- `damage_value`, `heal_value`, and `time_limit_seconds` now come directly from the DB row — no local recomputation. This removes the heal-value halving bug where `healValue` was `Math.max(5, Math.floor(effectValue / 2))` instead of full impact.
- Added `SupabaseQuestionRow` and `CategoryDistribution` types to `question.types.ts`. Added `timeLimitSeconds` to `InternalCard`.
- Made `handleJoinQueue` in both `MatchService` and `MatchGateway` async since question fetch is now an awaited Supabase call.
- Made `BotBattleService.createBotMatch` async — bot matches use the exact same `getMatchQuestionPool(target)` call as PvP, no separate question-fetch path.
- Updated `match.service.spec.ts` with mocked `BotBattleService`, `SupabaseService`, and `QuestionService` providers. Stub cards use DB-shaped values (full-impact `healValue`, no halving).

**The Reasoning:**
- Values must come from the DB because content authors set `damage_value`/`heal_value` at authoring time using the impact formula (`8 + weight × 6`). Local recomputation duplicated this logic and introduced the halving bug for heal values.
- Reading from the base `questions` table (not the `public_questions` view) is required because the view deliberately hides `correct_option_index` for client-facing reads, but the game backend needs it to validate answers.
- Category balancing prevents matches where all cards are the same type by chance. The `CATEGORY_DISTRIBUTION` constant is configurable without a code change pattern — just edit the constant.
- Fetching once at match creation (not per-card) aligns with PRD §6 Risk #1: *"Avoid blocking PostgreSQL queries during active battle rounds."*

**The Tech Debt:**
- Target is hardcoded to `'cpns'` in both `handleJoinQueue` and `BotBattleService.createBotMatch`. When profile-aware matchmaking lands, it should read the player's `profiles.target` and pass it through.
- Cross-target PvP matchmaking (cpns vs bumn players) is unresolved — currently both players would get the same `'cpns'` pool. Needs a product decision on whose target wins or whether to enforce same-target pairing.
- Category distribution (4/4/4) is a best-guess default — product/content team should confirm the intended ratio.
- Difficulty filtering is not applied for v1 — flagged as a follow-up if load testing or product review requests it.
- No in-memory cache of recently-fetched pools across near-simultaneous match starts — flagged as a future optimization if load testing shows it's needed..

## 2026-07-21 - Supporting Features: Match Logs + Match History API + Question Recycling

**The Change:**

### Part A — Match Logs (per-action audit trail)
- Created `MatchLogBuffer` (`apps/backend-game/src/match/logs/match-log-buffer.ts`) — an in-memory per-room buffer that records every `open_card`, `play_card`, and `surrender` action during a match with no DB writes mid-battle.
- Created `match-log.types.ts` with `MatchLogEntry`, `MatchLogAction`, and `MatchLogRpcEntry` types.
- Hooked `.record()` calls into `MatchService.handleOpenCard`, `handlePlayCard`, and `handleSurrender` with consistent payload shapes per action type.
- Extended `MatchResultService.finalizeMatch()` to accept a `logEntries` parameter. After the RPC returns a `matchResultId`, logs are bulk-inserted into `match_logs` using the FK.
- `MatchService.persistAndEnrich()` drains the buffer and passes entries to `finalizeMatch` — the buffer is always cleared, even if persistence fails (no memory leak).
- Made `GameEngine.getPlayer()` and `getOpponent()` public so the surrender handler can capture HP state for logging.
- Registered `MatchLogBuffer` in `MatchModule` providers.

### Part B — Match History API
- Created `MatchesModule`, `MatchesController`, `MatchesService`, and `matches.types.ts` in `apps/backend-api/src/matches/`.
- `GET /matches?limit=&offset=` — authenticated endpoint using `SupabaseAuthGuard`, reads from `match_results` where the user is `player_a_id` or `player_b_id`.
- `toHistoryDto()` derives self-relative `outcome` (win/lose/draw) from `winner_user_id`, maps final state (HP/score) relative to the requesting user, and sets `isBotMatch: true` with `opponentUsername: "Bot"` when `player_b_id` is null or mode is bot.
- Pagination follows the exact pattern from `/leaderboard` — `parseNonNegativeInteger`, `defaultLimit: 20`, `maxLimit: 50`.
- Registered `MatchesModule` in `AppModule`.

### Part C — Question Recycling
- Added `reserveQueue: InternalCard[]` and `nextRecycleId: number` to `InternalRoomState`.
- Updated `GameEngine.createRoom()` to accept an optional `reserveQueue` parameter.
- Updated `playCard()` draw logic: when the main `sharedQueue` is exhausted, cards are drawn from `reserveQueue` with fresh card-instance IDs (`card_r${nextRecycleId}`) to avoid ID collision with previously-dealt cards.
- Updated `isQuestionExhausted()` to check both `sharedQueue` and `reserveQueue` — only triggers `question_exhaustion` when both are empty and no playable cards remain.
- Added `getCardPool()` to `QuestionService` returning `{ active, reserve }` — the active set feeds the shared queue, the reserve feeds recycling. Kept `getCards()` as legacy backward-compat.
- Updated `RoomManager.joinQueue()` and `createRoom()` to accept and pass reserve cards.
- Updated `MatchService.handleJoinQueue()` to use `getCardPool()`.

**The Reasoning:**
- Buffering logs in memory during the match (not writing per-action) satisfies PRD §6 Risk #1: "Avoid blocking PostgreSQL queries during active battle rounds." Logs are only flushed at match-end in the same persistence flow.
- Match history lives in `backend-api` (not `backend-game`) per PRD §2.4 service boundaries — REST endpoints for the Flutter client belong on the App Backend, keeping the two backends decoupled.
- Question recycling uses reading (b) from the plan: genuinely different questions from a larger pre-fetched buffer, not repeated content. This avoids the "memorize the answer, get free points on recycle" exploit. The reserve is part of the initial fetch — no mid-battle Supabase query.
- Fresh card-instance IDs on recycled cards (`card_r${n}`) prevent client-side tracking collisions with previously-answered card IDs.

**The Tech Debt:**
- The `timeout` log action type is defined but not wired — it will be connected when timeout/reflected-damage engine logic is implemented.
- `match_results` is not yet in the backend-api generated `database.types.ts` — the Supabase query uses `client as any` until types are regenerated.
- The local question pool only has 12 questions, so the reserve buffer is currently empty. When backed by Supabase, `getMatchQuestionPool` should fetch 2× the pool size and split into active/reserve.
- `opponentUsername` in match history is either "Bot" or `null` — a join against `profiles` for the real username is deferred until the UI needs it.
- Log entries for bot actions are not yet wired (depends on the bot battle service integration).
- Log persistence is a separate insert after the RPC, not in the same transaction — if the RPC succeeds but the log insert fails, logs are lost (logged but not retried).

## 2026-07-21 - Fix 5 cards handsize to 4 cards

**The Change:**
- Modified `QuestionDealer.ts` (line 6) `HAND_SIZE` from `5` to `4`.
- No structural impact to other services or types — just reducing the number of cards dealt to each player.

**The Reasoning:**
- The hand size was hardcoded to 5 in `QuestionDealer` and not configurable via PRD.
- Changed to 4 to match PRD requirement.
- No downstream impact as no other services depend on the hand size.

**The Tech Debt:**
- The hand size is hardcoded to 4 in `QuestionDealer` — would be better to move this to a constant in `match.constants.ts` or similar if it needs to be configurable.
- No impact on other services or types.

## 2026-07-21 - Card Timer/Timeout + Performance Analytics Endpoint

**The Change:**

### Part A — Server-Enforced Per-Card Timeout (`apps/backend-game`)
- Created `CardTimeoutService` (`apps/backend-game/src/match/timeout/card-timeout.service.ts`) managing per-card turn timers keyed by `${roomId}:${userId}`.
- Added `GameEngine.timeoutCard()` to handle card turn expiry (resolves as incorrect with 0 effect, splices card from hand, logs `action: 'timeout'`, draws next card from main or reserve queue, and checks match win conditions).
- Integrated timer scheduling into `MatchService.handleOpenCard()` using `card.timeLimitSeconds` (defaulting to 10s fallback).
- Added `cardTimeoutService.clearTimeout()` call at the start of `MatchService.handlePlayCard()` to prevent race conditions when a manual answer arrives just before timeout.
- Added `cardTimeoutService.cancelAllTimersForRoom()` cleanup in `handleDisconnect`, `handleSurrender`, `handleCardTimeout`, and `persistAndEnrich` to prevent leaked timers.
- Registered `CardTimeoutService` in `MatchModule` and updated unit test setup.

### Part B — Performance Analytics Endpoint (`apps/backend-api`)
- Created `AnalyticsModule`, `AnalyticsController`, `AnalyticsService`, and `analytics.types.ts` in `apps/backend-api/src/analytics/`.
- Endpoint `GET /analytics` protected by `SupabaseAuthGuard`.
- Aggregates practice performance data: `overallAccuracy`, `totalAnswered`, `categoryBreakdown` (TWK, TIU, TKP), `weakSubcategories` (accuracy < 60% with minimum sample size of 5), and `avgResponseTimeMs`.
- Aggregates battle performance data from `profiles`: `winrate`, `wins`, `losses`, `totalMatches`.
- Gracefully returns clean zeroed data structure for new users with no history.
- Registered `AnalyticsModule` in `AppModule`.

**The Reasoning:**
- Server-enforced per-card timeouts ensure that matches cannot stall indefinitely when a player opens a card and becomes idle or drops connection.
- Keying timers by `${roomId}:${userId}` avoids timer collision across concurrent active matches.
- Returning practice category breakdowns, weak subcategories (sample-size filtered), average response time, and battle stats in a single `GET /analytics` call allows the Flutter client to render a comprehensive performance dashboard without multiple round-trips.

**The Tech Debt:**
- Weak subcategory threshold parameters (60% accuracy, minimum sample size of 5) are hardcoded constants in `AnalyticsService` — could be moved to config or environment variables if dynamic tuning is needed.
- `get_practice_analytics` SQL migration (`infra/supabase/migrations/20260721000000_get_practice_analytics.sql`) needs to be run on remote Supabase instance (`supabase db push` or SQL editor) for production environment deployment.

## 2026-07-23 - Server-Authoritative Economy, Loadout, and Hired Pass

**The Change:**
- Added migration `20260723000000_server_authoritative_economy.sql` with the Store catalog, user inventory, purchase and coin ledgers, Hired Pass seasons/missions/rewards/progress/claims, starter-item backfills, and the missing profile tower/pass fields.
- Normalized legacy UUID-typed avatar/arena profile columns to text so they can reference stable cosmetic catalog IDs, and aligned both recovery bootstrap files.
- Added service-role-only transactional functions for purchases, loadout changes, beta credits, reward claims, and idempotent learning activity. Direct authenticated profile/economy writes are revoked.
- Replaced `finalize_match_result` so duplicate calls return the original deltas, coin rewards are audited, and completed bot/player matches advance Hired Pass missions atomically.
- Added database triggers that advance Hired Pass missions when practice or interview sessions first become completed.
- Added authenticated Store and Hired Pass REST modules, an ownership-validating `PATCH /profile/loadout`, and a strict allowlist for editable `PATCH /profile` fields.
- Added `progressionPersisted` to the match-result contract and populated it for both player and bot persistence paths.
- Added equipped tower IDs to leaderboard responses, updated Supabase types/API documentation, and added backend unit coverage.

**The Reasoning:**
- Coins, rank, ownership, pass claims, and loadout must share one server-side source of truth. Database transactions and idempotency constraints prevent double charges or rewards under retries and concurrent taps.
- RLS policy removal and privilege revocation are required because controller validation alone does not prevent an authenticated user from calling Supabase REST directly.
- Practice/interview database triggers keep mission awards in the same transaction as completion, avoiding missed progress when an API response fails after the session update.
- Cosmetic IDs remain presentation-only and do not affect battle mechanics.

**The Tech Debt:**
- The seeded MVP Hired Pass season ends at `2026-08-01T00:00:00Z`; a new explicitly seeded season or an administrative season-management workflow is required afterward.
- Real-money payment and automatic premium entitlement are intentionally absent. `POST /store/beta-credits` is available only when `ENABLE_BETA_ECONOMY_CREDIT=true`.
- The migration still needs to be applied to the target Supabase project before the new endpoints are used.
- Mobile integration was deliberately excluded; existing clients will not consume the new authoritative responses until the frontend team wires them.

## 2026-07-23 - Target-Aware, Reconnect-Safe Battle Backend

**The Change:**
- Added shared battle contracts for `BattleTarget` (`cpns|bumn`), `MatchmakingMode` (`ranked|casual|bot`), character/tower loadouts, enriched public room snapshots, reconnect deadlines, and authoritative match-result mode/target/deltas.
- Added `GamePlayerProfileService` in `backend-game` to snapshot the authenticated user's display name, target, equipped character, and equipped tower from Supabase. Bot rooms use a fixed server-owned loadout and inherit the human player's target.
- Changed matchmaking to FIFO buckets keyed by exact `(target, mode)`. Missing mode remains backward-compatible as Casual, unsupported modes are rejected, and Bot bypasses the human queue.
- Changed room creation and public state so both players receive server-derived display names and character/tower loadouts. Target owns the shared CPNS/BUMN battle context; arena is no longer part of the live battle loadout.
- Changed question loading to query active rows from Supabase's base `questions` table using the room target. Source Supabase question IDs remain internal while public card-instance IDs are generated separately.
- Replaced finite runtime reserve exhaustion with deterministic room-pool recycling. Recycled draws receive fresh `card_r*` instance IDs, and `question_exhaustion` is no longer a normal match-end path.
- Added independent 30-second disconnect grace timers. Card timers, the opponent, and Bot turns continue during the grace period. Reconnect replaces stale sockets, cancels the user's timer, and emits current state plus presence.
- Added disconnect forfeits and abandoned draws: a connected opponent wins after timeout; two offline humans produce a persisted draw with zero progression. All disconnect timers are cleared on reconnect, normal completion, room completion, or destruction.
- Added migration `20260723010000_target_aware_matchmaking.sql`: match modes become `ranked|casual|bot`, legacy `player` rows backfill to Ranked, battle target is stored, and `finalize_match_result` persists every mode while applying progression only to normal Ranked results.
- Updated backend-api match history DTOs to expose normalized mode and battle target.
- Expanded backend-game regression coverage from 153 to 166 passing tests. New cases cover target/mode isolation, FIFO, profile/loadout snapshots, invalid modes, target-specific Supabase filters, multi-cycle recycling, stale sockets, reconnect-before-timeout, disconnect forfeits, both-offline draws, normal completion during grace, timer cleanup, and zero-delta persistence contracts.
- Verification: backend-game `tsc --noEmit` and 166/166 Jest tests pass; backend-api `tsc --noEmit` and 39/39 Jest tests pass; backend-scoped `git diff --check` passes.

**The Reasoning:**
- Target and cosmetics are loaded from the authenticated server profile so clients cannot select a different question domain or equip inventory they do not own.
- Exact `(target, mode)` buckets prevent CPNS/BUMN and Ranked/Casual cross-matches while retaining predictable FIFO behavior.
- A single pre-fetched Supabase pool avoids database calls during active battle. Recycling the immutable room pool keeps both players aligned at equivalent draw positions and removes content exhaustion as an artificial win condition.
- Disconnect is treated as temporary presence loss rather than an immediate match end. Independent timers let the connected player and all server-owned turn timers continue without pausing the room.
- Progression gating belongs in the transactional database function: every result remains auditable, but Casual, Bot, and abandoned matches cannot mutate competitive or economy state.

**The Tech Debt:**
- The new migration still needs to be applied and exercised against the target Supabase project. Unit tests verify the RPC contract with mocks but do not execute PostgreSQL transaction behavior.
- The required two-account smoke test remains: target/mode isolation, distinct loadout rendering, reconnect restoration, 30-second forfeit, and Ranked-only progression should be verified against deployed backend instances.
- Matchmaking queues, rooms, and grace timers are process-local. Horizontal scaling still requires Redis-backed queue/state coordination and distributed timer ownership.
- Legacy test-compatible overloads remain in `GameEngine.createRoom`, `RoomManager.joinQueue`, and `RoomManager.createBotRoom`; remove them after all older backend callers and fixtures use profile-based room seeds.

## 2026-08-17 - Combo-Scaled Heal And Battle PRD Alignment

**The Change:**
- Changed the Game Backend's live Heal calculation to use the same pre-answer combo value as Damage: combo `x1`, `x2`, and `x3` now apply `5`, `10`, and `15` HP respectively.
- Kept Heal capped at maximum HP and kept awarded battle points equal to the resolved Heal amount.
- Replaced the damage-specific base constant/helper with a shared combo-effect calculation used by both Damage and Heal.
- Preserved `questions.heal_value` in the Supabase schema, question query, internal card mapping, and server-side types. It is now compatibility/future-balancing metadata and is not used by the live battle engine.
- Aligned the local Flutter Bot battle calculation by removing weight-derived Heal values and using the shared `5/10/15` combo scale. Updated the question sheet to show the current combo and resolved impact instead of weight-based power.
- Updated the canonical `docs/PRD.md` to document combo-scaled Damage/Heal, retained database value fields, 180-second rounds, 3-second round breaks, and best-of-three match resolution.
- Added regression coverage proving that stored `healValue` does not affect live healing, Heal scales through `5/10/15`, and healing remains capped at `100 HP`.

**The Reasoning:**
- Damage and Heal now follow one predictable battle rule: resolve `5 × comboLevel.clamp(1, 3)` using the combo level that existed before the correct answer advances the chain.
- Keeping `heal_value` in Supabase avoids a destructive schema/content migration and preserves the option to reintroduce authored values in a future balancing revision.
- Centralizing both effects on one combo helper prevents Damage and Heal from drifting into separate formulas across PvP and server Bot matches.
- Updating the local mobile fallback keeps its correct-answer Heal behavior consistent while Mobile still transitions toward the server-authoritative Bot flow.

**Verification:**
- Backend Game: 67 focused Jest tests passed for the engine, Supabase question mapping, and server Bot behavior.
- Flutter: 22 focused battle state-machine/controller tests passed.
- Focused Dart static analysis reported no issues.
- `git diff --check` passed.

**The Tech Debt:**
- Mobile Bot mode still uses the local `BotBattleRepository` instead of authenticated `mode=bot` Socket.IO rooms, so the server must remain the production authority once that handoff is completed.
- Project-wide Backend Game `tsc --noEmit` is still blocked by pre-existing `match-result.service.spec.ts` fixtures that omit the required `comboLevel` field; the focused changed-code tests pass.
- Archived PRDs and gap reports intentionally remain historical and may describe the superseded stored-value Heal rule; `docs/PRD.md` is the canonical specification.

## 2026-08-18 - Gate 0–1 backend contract cutover

**The Change:**
- Added the Gate 1 API surface in `apps/backend-api` for Lobby, Analytics, Practice, Profile, and Leaderboard, aligning the server response shapes with the PRD contract and camelCase payload patterns.
- Added a shared `LobbyService` that aggregates profile state, rank points/Y-Coin balances, business-date daily mission progress, Hired Pass summary, and a single recommendation payload for the home screen.
- Expanded the Practice flow to enforce category/subcategory validation, required `idempotencyKey` handling for answer and finish operations, and the paginated `items/limit/offset/total` history envelope.
- Updated the Practice repository/service flow to use transactional session completion/answer handling, plus the repository-side idempotency/replay safeguards expected by the contract.
- Added deterministic analytics and recommendation logic for practice performance, weak-topic detection, public-match stats, tier/streak views, and a recommendation selection based on the configured 90-day and recency rules.
- Refined leaderboard access to use SQL-backed page/rank RPCs and normalized the leaderboard types to the Gate 1 contract shape.
- Added a shared progression helper for WIB business-date calculations and rank-tier mapping that is consumed by lobby and analytics composition.
- Added the common API exception filter so stable error codes like `IDEMPOTENCY_KEY_REUSED` are surfaced consistently in the Nest API layer.
- Added and updated tests for the new Gate 1 modules and REST contracts, covering lobby summary, analytics recommendation, practice session behavior, leaderboard ordering, and API error mapping.
- Added and updated the shared Supabase database typing to cover the new progression and gate-1 response shapes.
- Added the Gate 0 content contract artifacts under `contracts/` and the validation tooling under `infra/` for taxonomy, question-bank, Store catalog, and season manifest checks.

**The Reasoning:**
- The backend needed one consistent source of truth for the post-PRD cutover: authoritative profile summaries, deterministic recommendation logic, and SQL-backed ranking without leaking internal answer data.
- Practice, analytics, and lobby are now composed from the same domain primitives so the client can switch to the new PRD contract without mixing legacy response formats.
- The idempotency and error normalization are intentionally enforced server-side so retries remain safe and the mobile client can rely on stable error envelopes.
- The content validation and contract work is being kept development-only until external SME approval and the dedicated security hotfix are complete.

**The Tech Debt:**
- The repository still carries the explicit external dependency on SME approval for the development question bank before the gate can be declared officially passed.
- Authentication/RLS hardening remains tracked as a separate security hotfix and is intentionally excluded from this backend delivery acceptance scope.
- Mobile integration remains deferred until its parsers and idempotency key handling are updated to match the backend contract.
- The current repo state preserves the existing backend-game `.env.example` change and does not refactor it as part of this staged backend work.

**Verification:**
- Backend API test suite passed: 16/16 suites, 54/54 tests.
- Gate 0 validation passed via `npm run validate:gate0` in `infra/` with the expected development-only warning.
- Backend API build passed via `npm run build`.
