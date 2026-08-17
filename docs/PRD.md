# YUDHA — MVP Product Requirements and Architecture Contract

> **Status:** Approved for MVP implementation
> **Version:** 1.0
> **Last updated:** 2026-08-17
> **Product timezone:** `Asia/Jakarta` (WIB, UTC+7)
> **User-facing language:** Indonesian
> **Audience:** Product, Mobile, Backend, Game Backend, AI, DevOps, Content, and QA

## Document authority

This file is the single source of truth for YUDHA MVP product behavior, business rules, service ownership, public contracts, and release acceptance.

- If code, tests, tickets, mockups, archived documents, or [`PRD-AI-INTERVIEW.md`](./PRD-AI-INTERVIEW.md) conflict with this file, **this file wins** until an approved change updates it.
- `must` and `shall` are mandatory. `may` describes an explicitly permitted choice, not an undecided requirement.
- Archived gap documents are historical audit material, not active specifications.
- Database migrations are the executable physical schema. The logical models in this file define the behavior the schema must support.
- Store catalogs and Hired Pass season manifests are versioned product data. They may change content and prices but must not change the mechanics or safety boundaries defined here.
- Any pull request that changes observable behavior, business values, an API/socket shape, or an MVP boundary must update this file in the same pull request.

---

## 0. Product definition

### 0.1 One-liner

**YUDHA (Your Ultimate Digital Hiring Arena)** is a gamified mobile learning platform that builds CPNS and BUMN selection readiness through Practice, real-time card battles, explainable analytics, and AI mock interviews with text and voice interaction.

### 0.2 Target user and product promise

The MVP serves Indonesian CPNS and BUMN candidates who want repeatable practice, visible learning progress, and realistic interview rehearsal. YUDHA is a learning product. It does not guarantee employment, predict an official examination result, or issue an official certification.

### 0.3 Product principles

1. **Learning first:** monetization and cosmetics never improve HP, damage, healing, answer time, score, question quality, matchmaking priority, rating, or AI evaluation quality.
2. **Server authority:** servers own questions, answers, timers, battle state, progression, balances, inventory, entitlements, missions, streaks, and recommendations. Mobile never invents a successful mutation.
3. **One battle ruleset:** Bot, Casual, Ranked, and Private modes use the same server battle engine.
4. **Recoverable mutations:** purchases, credits, mission rewards, reward claims, interview turns, and match finalization are idempotent.
5. **Explainable personalization:** MVP recommendations use deterministic metrics and return their supporting evidence. LLM output never controls access or progression.

### 0.4 Canonical terminology

| Term | Meaning |
|---|---|
| **Target** | The user's exam track: `cpns` or `bumn`. It selects content, matchmaking queues, the fixed battle arena, and interview context. |
| **PvP** | Human-versus-human play. Bot mode is not PvP. |
| **Public match** | A human Casual or Ranked match created by matchmaking. |
| **Private match** | A human match created with a room code. It is unranked and has no progression. |
| **Normal completion** | A server-finalized activity that is not abandoned or invalidated and, for a match, is not ended by either player's surrender or disconnect. |
| **Rank points** | Persistent, non-seasonal competitive/engagement progression used for leaderboard ordering and tier. Daily Lobby missions and Ranked results both change this balance; it can increase or decrease but is never reset and is floored at zero. |
| **Y-Coin** | Persistent, non-transferable virtual currency used for cosmetics and AI Interview sessions. It can be obtained through beta Store credits, Ranked rewards, and Hired Pass tracks. It never expires. |
| **Pass Points** | Non-spendable progress for one Hired Pass season. They reset at season end and cannot be purchased or transferred. |
| **Hired Pass** | The only MVP premium entitlement. It unlocks the current season's premium reward track and suppresses ad stubs until that season ends. |
| **Business day** | A calendar date in `Asia/Jakarta`. Servers store timestamps in UTC and convert them for day/week/season rules. |

---

## 1. MVP boundaries

### 1.1 Included in MVP

| # | Capability | Required outcome |
|---|---|---|
| 1 | Supabase email/password authentication | Secure registration, login, verification, restoration, logout, and private-route protection |
| 2 | Authoritative Lobby | Profile/tier, two daily missions, streak, Hired Pass summary, and one next-action recommendation |
| 3 | Practice | Five server-locked questions, server grading, hints, results, and history |
| 4 | Bot battle | Solo play through the server battle engine |
| 5 | Casual and Ranked PvP | Same-target public matchmaking and server-authoritative real-time play |
| 6 | Private PvP | Create/join with a six-character room code and persist history without progression |
| 7 | Analytics, tiers, and leaderboard | Accuracy, response time, weak topics, win rate, rank points, and deterministic recommendations |
| 8 | Validated CPNS/BUMN content | Reproducible, idempotent database provisioning with content checks |
| 9 | AI Mock Interview | Text request/response, text SSE streaming, recorded voice, live voice, evaluations, and final summary |
| 10 | Y-Coin and Store | Repeatable beta credit, authoritative balance, character/tower catalog, purchase, inventory, and loadout |
| 11 | Hired Pass | Server beta activation, mixed-cadence seasonal missions, free/premium tracks, permanent claimed cosmetics, and ad-free state |
| 12 | Ad-placement stubs | Free-user result-exit trigger and premium suppression without a production ad SDK |
| 13 | Multi-instance readiness | Redis-coordinated matchmaking, health/readiness, observability, graceful shutdown, integration tests, and load tests |

### 1.2 Explicitly excluded from MVP

- community discussions, guilds, tournaments, spectators, and battle replays;
- content marketplace, official certification, and institutional/B2B dashboards;
- web or desktop clients;
- arena cosmetics or player-selected arenas;
- Y-Coin transfer, gifting, trading, cash-out, or a player marketplace;
- real-money payment processing and permanent payment-gateway selection;
- production ads SDK integration, rewarded ads, and ad-funded currency;
- auto-renewing Hired Pass subscriptions;
- a permanently designated canonical LLM provider;
- pgvector question search; and
- more than two human players in a match.

### 1.3 MVP acceptance definition

The MVP is pilot-ready only when:

- every included user journey works against deployed services on two real mobile clients;
- no production flow relies on local questions, local battle calculations, hardcoded Store/Pass state, or unauthenticated success fallbacks;
- Practice, Bot, Casual, Ranked, and Private modes use database-provisioned questions;
- Store credits, balance changes, Interview charges, match rewards, daily mission rewards, Pass progress, and claims are server-authoritative and idempotent;
- text streaming and live voice complete through at least one configured provider set, and provider failures follow Section 7;
- two Game Backend instances coordinate through Redis without duplicate queueing or room ownership;
- the performance, security, accessibility, observability, backup, and recovery criteria in Section 10 pass in staging; and
- Product, Mobile, Backend, Game Backend, AI, DevOps, Content, and QA accept their criteria in this document.

---

## 2. User journeys and access model

### 2.1 Core journey

```text
Register or Log In
  → Lobby: tier + rank points + daily missions + streak + recommendation
    → Practice: select topic → answer 5 locked questions → Results
    → Battle:
       → Bot
       → Casual or Ranked public queue
       → Create or join Private room code
    → Hired Pass: view season missions and claim free/premium milestones
    → Store: claim beta Y-Coin, buy/equip character or tower
    → Leaderboard/Profile: rank, analytics, weak topics, history
    → AI Interview: spend 100 Y-Coin → text/voice session → evaluation/summary
```

The learning loop is: **activity → authoritative analytics → recommended next action → activity**.

### 2.2 Authentication and target

- Registration requires email, password, username, and target (`cpns` or `bumn`).
- Every private REST route and socket namespace requires a valid Supabase JWT.
- While session restoration is unresolved, authenticated screens remain in a loading state. Unauthenticated deep links redirect to Login and preserve their intended destination.
- A target change affects activities created afterward. Existing Practice, match, and Interview sessions retain their target snapshot.
- Public and Private PvP require both humans to have the same target.
- Target selects one canonical arena: CPNS users see the CPNS arena and BUMN users see the BUMN arena. `equipped_arena_id` is compatibility-only and has no MVP behavior.

### 2.3 Access and monetization

| Capability | Free user | Active Hired Pass |
|---|---|---|
| Practice, Bot, Casual, Ranked, Private | Full access | Full access |
| AI Interview | `100 Y-Coin` per new session | Same `100 Y-Coin` cost |
| Character/tower Store | Buy with Y-Coin | Buy with Y-Coin |
| Free reward track | Earn and claim | Earn and claim |
| Premium reward track | Progress visible; claims locked | Claim reached milestones, including milestones reached before activation |
| Pass-exclusive cosmetics | Preview only | Claim from premium milestones |
| Result-exit ad stub | Triggered at defined safe breaks | Suppressed while entitlement is active |

There are no Practice or battle quotas. Hired Pass never changes learning content, battle mechanics, matching, ranking, or Interview quality.

---

## 3. Learning, daily missions, streak, and analytics

### 3.1 Question taxonomy and safety

The canonical target taxonomy is:

| Target | Category | Allowed subcategory examples |
|---|---|---|
| `cpns` | `twk` | nationalism, constitution, governance |
| `cpns` | `tiu` | verbal, numerik, logika |
| `cpns` | `tkp` | service, teamwork, integrity |
| `bumn` | `tkd` | verbal, numerik, logika |
| `bumn` | `akhlak` | amanah, kompeten, harmonis, loyal, adaptif, kolaboratif |

- Each source record has a stable unique `source_key` so imports can be rerun without duplicates.
- Each active question has one target, category, optional subcategory, `2..6` non-empty options, exactly one valid zero-based correct index, difficulty, weight `1..4`, effect (`damage` or `heal`), a non-empty explanation, an optional hint, and a positive time limit.
- `weight` affects Practice score only. `damage_value` and `heal_value` are compatibility metadata and do not affect MVP battles.
- Clients never receive the correct option or explanation before an answer resolves.
- A clean database must be provisionable with one documented idempotent command. Import validation reports inserted, updated, skipped, invalid, and duplicate records.
- Each enabled target requires at least `100` active, SME-approved questions and at least `20` in every enabled top-level category before release.

### 3.2 Practice rules

- A Practice session snapshots the user's target and locks exactly five active questions when created.
- If category is omitted, all active categories for the target are eligible. If subcategory is supplied, category is required and the pair must be valid for the target.
- The five questions are distinct within the session. The server owns the selection strategy; changing that strategy is allowed only if target/category filtering, five-question locking, and no-repeat-within-session behavior remain unchanged.
- A question is answered at most once. The server grades it, records response time and hint usage, and then returns correctness, the correct option, and explanation.
- Practice has no automatic answer timeout. `time_limit_seconds` is displayed as guidance and remains authoritative for battle use.
- Any user can reveal a hint before answering. Hint usage is recorded and causes no score or accuracy penalty.
- Correct score is `question.weight × 10`; a wrong answer scores `0`.
- Accuracy is `correct answers / answered questions × 100`.
- Normal completion requires all five questions to be answered. Abandoned or prematurely closed sessions do not grant daily mission progress, streak, or Hired Pass activity.
- The fifth accepted answer finalizes the Practice session and applies eligible daily-mission, streak, and Hired Pass activity in the same idempotent completion workflow. The explicit finish endpoint only retrieves or repairs that already-determined completion; it cannot finalize a session with unanswered questions.
- Submission and finish retries return the existing result without duplicating answers, activity, or rewards.

### 3.3 Daily Lobby missions and rank tiers

Daily Lobby missions are a separate system from Hired Pass missions. The two fixed MVP missions are:

| Mission | Completion condition | Automatic reward |
|---|---|---:|
| Daily Practice | Normally complete one five-question Practice session | `+50 rank_points` |
| Daily PvP | Normally complete one public Casual or Ranked match, regardless of outcome | `+80 rank_points` |

- Each mission can reward a user once per `Asia/Jakarta` business date.
- A mission date runs from `00:00:00` inclusive to the next `00:00:00` exclusive in `Asia/Jakarta`; an activity belongs to the date containing its server completion timestamp.
- Rewards apply automatically from idempotent server completion events; there is no manual claim button.
- For a Ranked match, the result delta applies first and is floored at zero, then the first-of-day `+80` mission reward applies.
- Daily mission points affect leaderboard order and tier. Tiers are Rookie `0..399`, Warrior `400..799`, Elite `800..1199`, and Legend `1200+`.
- Daily missions have no direct Y-Coin or Pass Point reward.

### 3.4 Streak

- The server converts the authoritative completion timestamp to `Asia/Jakarta`; client time is ignored.
- A streak-qualifying activity is a normal five-question Practice completion or a normal public Casual/Ranked completion.
- Bot, Private, abandoned, surrender, disconnect-forfeit, and Interview activities do not qualify.
- At most one streak day exists per user per business date.
- The first qualifying date sets `currentStreak=1`. The next consecutive date increments it. A gap of at least one complete business date resets the next activity to `1`.
- There is no grace day or offline backdating. `bestStreak` never decreases.

### 3.5 Analytics and deterministic recommendation

Analytics exposes Practice and Ranked accuracy, average response time, sample sizes, weak categories/subcategories, public-match win rate, rank tier, current/best streak, and history.

The recommendation uses server-graded Practice and Ranked answers from the current WIB date and the preceding 89 WIB calendar dates, and returns exactly one typed action, an Indonesian reason, and supporting metrics:

1. Fewer than five graded answers: recommend general Practice for the user's target.
2. Otherwise, a subcategory with at least five answers and accuracy below `70%`: recommend the lowest-accuracy qualifying subcategory.
3. Otherwise, a category with at least ten answers and accuracy below `80%`: recommend the lowest-accuracy qualifying category.
4. Otherwise, no Interview was completed from `00:00` on the sixth prior WIB calendar date through the current request time: recommend AI Interview.
5. Otherwise: recommend the least recently practiced category.

Ties use lower accuracy, then larger sample, then older last-practiced timestamp, then ascending stable category/subcategory ID. A never-practiced category is older than any timestamp. Recommendations never call an LLM.

### 3.6 Leaderboard

- Leaderboard order is descending `rank_points`, then descending Ranked wins, then ascending user ID for deterministic pagination. Casual, Bot, and Private results never affect a leaderboard tie-breaker.
- It exposes paginated entries and an authenticated “my rank” result.
- Daily mission and Ranked result mutations appear only after their authoritative transaction commits.

### 3.7 Ad-placement stubs

- A free user triggers an ad-placement stub only when leaving a fully completed five-question Practice Results screen or any server-finalized public Casual/Ranked Results screen, including a surrender or disconnect result.
- An active Hired Pass suppresses the stub entirely.
- No ad/stub is triggered during a question, battle, Private match, Store purchase, Hired Pass claim, or paid Interview.
- The stub returns immediately and never blocks navigation. Production ad SDK integration is post-MVP.

---

## 4. Architecture and logical data

### 4.1 Technology boundaries

| Layer | Choice | Responsibility |
|---|---|---|
| Mobile | Flutter | Indonesian UI, authenticated navigation, REST/socket/SSE consumption, audio capture/playback, and rendering authoritative state |
| App Backend | NestJS REST/SSE | Profile, Practice, Lobby, analytics, leaderboard, Store, Hired Pass, economy, and Interview orchestration |
| Game Backend | NestJS + Socket.IO | Public/private matchmaking, room ownership, authoritative battles, Bot scheduling, reconnects, and match finalization |
| Database | PostgreSQL via Supabase | Durable identity projection, content, learning activity, economy ledgers, entitlements, Interview state, and match history |
| Authentication | Supabase Auth JWT | Identity; profile rows are created server-side from authenticated users |
| Redis | Managed Redis | Atomic public queues, Private code reservations, Game Backend ownership/routing, cancellation, TTLs, and required cross-instance pub/sub |
| LLM | `InterviewLlmClient` adapter | Deployment-selected provider; no provider is a permanent product dependency |
| Speech | Configured STT/TTS adapters | Audio-to-text and text-to-audio; text remains the domain source of truth |
| Deployment | Docker-compatible managed container platform | Vendor-neutral services satisfying Section 10; cloud vendor choice does not change product behavior |

Active battle state stays in the owning Game Backend process. Redis coordinates discovery and routing; PostgreSQL persists final results and logs. A Redis outage makes public/private matchmaking unavailable with a controlled error rather than creating split queues.

### 4.2 Logical data models

These are behaviorally required models, not a replacement for executable migrations.

**`profiles`** (synced from `auth.users` via DB trigger)
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK, FK → auth.users) | |
| username | text | non-empty player display name |
| full_name | text, nullable | |
| target | text | `cpns` or `bumn`, set at registration |
| rank_points | int | drives leaderboard ordering |
| total_matches | int | |
| wins | int | compatibility physical name for Ranked wins only |
| losses | int | compatibility physical name for Ranked losses only |
| draws | int | compatibility physical name for Ranked draws only |
| winrate | float | Ranked win-rate projection only |
| coins | int | non-negative Y-Coin projection derived from the ledger |
| equipped_avatar_id | text, nullable | compatibility physical name for the equipped character; exposed as `characterId` |
| equipped_arena_id | text, nullable | compatibility-only; ignored by MVP clients and battles |
| equipped_tower_id | text, nullable | currently equipped tower cosmetic |
| current_streak | int | non-negative durable current streak |
| best_streak | int | maximum historical streak |
| last_streak_date | date, nullable | latest qualifying `Asia/Jakarta` business date |
| hired_pass_expires_at | timestamp, nullable | compatibility projection; season entitlement is authoritative |
| created_at | timestamp | |
| updated_at | timestamp | |

**`questions`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| source_key | text, unique | stable importer identity |
| target | text | `cpns` or `bumn` |
| category | text | canonical target category from Section 3.1 |
| subcategory | text, nullable | finer topic tag |
| prompt | text | question body |
| options | jsonb (string array) | `2..6` ordered non-empty options |
| correct_option_index | int | 0-based index into options array |
| explanation | text | non-empty; shown after answer resolution |
| difficulty | text | `easy`, `medium`, `hard` |
| weight | int | 1–4; affects Practice score and is unused by MVP battle effects |
| effect | text | `damage` or `heal` |
| damage_value | int | compatibility metadata; unused by MVP battles |
| heal_value | int | compatibility metadata; unused by MVP battles |
| time_limit_seconds | int | per-question timer (default 30s for PvP) |
| hint | text, nullable | optional hint for practice mode |
| is_active | boolean | soft-delete flag |
| created_at | timestamp | |
| updated_at | timestamp | |

> `public_questions` is a safe DB view that hides `correct_option_index` and `explanation` for client-facing reads.

**`practice_sessions`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| user_id | uuid (FK → profiles) | |
| target | text | |
| category | text, nullable | |
| subcategory | text, nullable | |
| total_questions | int | locked at session creation (default 5) |
| correct_count | int | |
| total_score | int | |
| accuracy | float | |
| started_at | timestamp | |
| finished_at | timestamp, nullable | null until session is finished |

**`practice_session_questions`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| session_id | uuid (FK → practice_sessions) | |
| question_id | uuid (FK → questions) | |
| question_order | int | position in the locked set |
| created_at | timestamp | |

**`practice_answers`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| session_id | uuid (FK → practice_sessions) | |
| user_id | uuid (FK → profiles) | |
| session_question_id | uuid, nullable | FK → practice_session_questions |
| question_id | uuid, nullable | |
| question_order | int, nullable | |
| selected_option_index | int, nullable | |
| player_answer | text, nullable | |
| is_correct | boolean | |
| used_hint | boolean | |
| response_time_ms | int, nullable | precise per-answer timing |
| answered_at | timestamp | |
| created_at | timestamp | |

**`match_results`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| room_id | text | |
| player_a_id | uuid (FK → profiles) | |
| player_b_id | uuid, nullable | null = bot opponent |
| winner_id | uuid, nullable | null = draw |
| loser_id | uuid, nullable | |
| mode | text | `ranked`, `casual`, `bot`, or `private` |
| target | text | `cpns`, `bumn` |
| reason | text | `hp_zero`, `round_timeout`, `surrender`, `disconnect`, `draw`, or `abandoned` |
| final_state | jsonb | rounds, HP, points, rating/Y-Coin deltas, and progression flags |
| completed_at | timestamp | |

**`match_logs`** (per-action audit trail)
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| match_id | uuid (FK → match_results) | |
| user_id | uuid | |
| action | text | `open_card`, `play_card`, `surrender`, `timeout` |
| payload | jsonb | action-specific data |
| created_at | timestamp | |

**`interview_sessions`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| user_id | uuid (FK → profiles) | |
| company_id | text | FK → interview_company_profiles |
| target_role | text | |
| mode | text | `realistic` or `coaching` |
| language | text | default `id` |
| response_style | text | `text` or `voice` |
| status | text | `creating`, `active`, `completed`, `cancelled`, or `failed` |
| context_snapshot | jsonb | frozen company context at session start |
| rolling_summary | text | compressed conversation memory |
| final_summary | jsonb, nullable | LLM-generated scoring/feedback at completion |
| coin_transaction_id | uuid, unique | the one successful `-100` session charge |
| created_at | timestamp | |
| updated_at | timestamp | |

**`interview_turns`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| session_id | uuid (FK → interview_sessions) | |
| role | text | `interviewer`, `candidate`, `system` |
| content | text | message text |
| idempotency_key | text, nullable | prevents duplicate answer submissions |
| parent_turn_id | uuid, nullable | links answer to its question |
| processing_status | text, nullable | tracks LLM evaluation state |
| evaluation | jsonb, nullable | per-turn scoring (visible in coaching mode) |
| created_at | timestamp | |

**`interview_company_profiles`** / **`interview_company_contexts`**
| Table | Purpose |
|---|---|
| `interview_company_profiles` | Company name, summary, and content version |
| `interview_company_contexts` | Categorized context chunks (values, culture, requirements) with priority ordering |

**Required supporting entities**

| Entity | Purpose and invariant |
|---|---|
| `rank_point_transactions` | Immutable deltas for Ranked results and the two daily missions; unique source/idempotency key |
| `daily_mission_progress` | One row per user, mission key, and WIB business date; completion and reward are atomic |
| `daily_learning_activity` | One qualifying streak row per user and WIB date |
| `coin_transactions` | Immutable non-zero Y-Coin delta and resulting non-negative balance; unique idempotency key |
| `store_items` | Versioned server catalog containing character/tower items only, rarity, price, pass exclusivity, and availability |
| `user_inventory` | Permanent item ownership with source and source reference |
| `store_purchases` | Idempotent cosmetic purchase record |
| `hired_pass_seasons` | Non-overlapping WIB calendar-month windows; one active season at a time |
| `hired_pass_missions` | Versioned daily/weekly/season mission definitions from the checked-in season manifest |
| `hired_pass_entitlements` | At most one entitlement per user/season; authoritative premium activation and expiry |
| `user_hired_pass_progress` | Per-user season Pass Points, mission progress, and awarded periods |
| `hired_pass_reward_claims` | Idempotent free/premium milestone claims and awarded Y-Coin/item snapshot |
| `interview_session_charges` | One successful `100 Y-Coin` debit per session and idempotency key |

Private room codes and public queue entries are ephemeral Redis records, not durable product entities. A created code contains owner, target, owning Game Backend instance, created/expiry timestamps, and single-use status.

### 4.3 Public contract conventions

- External JSON uses `camelCase`; timestamps are ISO 8601 UTC strings.
- Successful REST responses use `{ "data": ... }`. Lists use `{ "data": { "items": [], "limit": n, "offset": n, "total": n } }`.
- Mutating calls named below require an `idempotencyKey` of `1..160` characters. Replaying the same key and same operation returns the first committed result. Reusing it for different input returns `IDEMPOTENCY_KEY_REUSED`.
- Every mutating socket command requires a `commandId` of `1..160` characters. The Socket.IO acknowledgement uses `{ "data": ..., "requestId": ... }` on success or the same `{ "error": ... }` object used by REST on failure, with `details.recoverable` when relevant. Replaying the same command ID returns the original acknowledgement and emits no duplicate domain event; reusing it for different input returns `IDEMPOTENCY_KEY_REUSED`.
- Clients never calculate balances, effects, ratings, streaks, tiers, or entitlement state.
- All errors use this shape:

```json
{
  "error": {
    "code": "INSUFFICIENT_Y_COIN",
    "message": "Saldo Y-Coin tidak cukup.",
    "details": {},
    "requestId": "request-correlation-id"
  }
}
```

Required stable codes include `AUTH_REQUIRED`, `FORBIDDEN`, `VALIDATION_FAILED`, `NOT_FOUND`, `CONFLICT`, `IDEMPOTENCY_KEY_REUSED`, `INSUFFICIENT_Y_COIN`, `FEATURE_DISABLED`, `ENTITLEMENT_REQUIRED`, `QUEUE_UNAVAILABLE`, `ROOM_CODE_INVALID`, `ACTION_REJECTED`, `PROVIDER_UNAVAILABLE`, and `RATE_LIMITED`.

### 4.4 REST contracts

```text
# Auth
POST   /auth/register
       { email, password, username, target, fullName? }
       → { user, session?, verificationRequired }
POST   /auth/login
       { email, password }
       → { user, session }

# Lobby/Profile
GET    /lobby/summary
       → { profile, tier, rankPoints, yCoins, dailyMissions[2], streak,
           hiredPassSummary, recommendation }
GET    /profile
       → { id, username, fullName, target, rankPoints, tier,
           rankedStats: { wins, losses, draws, winRate },
           yCoins, characterId, towerId, streak }
PATCH  /profile
       { username?, fullName?, target? }
       → updated profile
PATCH  /profile/loadout
       { characterId?, towerId? }
       → { characterId, towerId }

# Practice
GET    /practice/dashboard
       → { target, categories[], statistics[] }
POST   /practice/sessions
       { category?, subcategory? }
       → { sessionId, questions[5] }
GET    /practice/sessions/:id
       → { session, questions, answers, progress }
POST   /practice/sessions/:id/answers
       { idempotencyKey, sessionQuestionId, selectedOptionIndex,
         responseTimeMs?, usedHint }
       → { isCorrect, correctOptionIndex, explanation, scoreGained, progress }
POST   /practice/sessions/:id/finish
       { idempotencyKey }
       → { accuracy, totalScore, correctCount, missionReward?, streak }
GET    /practice/history?category=&limit=&offset=
       → paginated session summaries

# Analytics/Leaderboard
GET    /analytics
       → { practice, ranked, weakTopics, streak, recommendation }
GET    /leaderboard?limit=&offset=
       → paginated { rank, userId, username, rankPoints, tier, rankedWins, rankedWinRate }
GET    /leaderboard/me
       → { rank, userId, username, rankPoints, tier, rankedWins, rankedWinRate }

# Store
GET    /store/items?type=character|tower
       → { yCoins, betaMode, betaPackages, disabledPaidPackages,
           items, ownedItemIds, equipped }
POST   /store/beta-credits
       { idempotencyKey, packageId: "beta-100" }
       → { credited: 100, replayed, yCoins }
POST   /store/purchases
       { idempotencyKey, itemId }
       → { purchased, replayed, purchaseId, itemId, yCoins }

# Hired Pass
GET    /hired-pass
       → { season, passPoints, entitlement, adFree, missions,
           rewards, claimedRewardIds }
POST   /hired-pass/beta-activate
       { idempotencyKey, seasonId }
       → { activated, replayed, entitlement }
POST   /hired-pass/rewards/:rewardId/claim
       { idempotencyKey }
       → { claimed, replayed, rewardId, coinsAwarded, itemId?, yCoins }

# AI Interview
POST   /interview/sessions
       { idempotencyKey, companyId, targetRole, mode,
         language: "id", responseStyle }
       → { session, openingQuestion, chargedYCoins: 100, yCoins }
GET    /interview/sessions?limit=&offset=
       → paginated session summaries
GET    /interview/sessions/:id
       → { session, turns, finalSummary? }
POST   /interview/sessions/:id/turns
       { idempotencyKey, answer: { type: "text", text } }
       → { turn, evaluation?, nextQuestion?, finalSummary? }
POST   /interview/sessions/:id/turns/stream
       { idempotencyKey, answer: { type: "text", text } }
       → text/event-stream
POST   /interview/sessions/:id/complete
       { idempotencyKey }
       → { finalSummary }
POST   /interview/sessions/:id/speech/transcriptions
       multipart audio
       → { transcript, provider }
GET    /interview/sessions/:id/speech/questions/:turnId/audio
       → authenticated binary audio stream
```

`POST /store/beta-credits` grants only while `ENABLE_BETA_ECONOMY_CREDIT=true`; otherwise it returns `FEATURE_DISABLED`. Each intentional tap while enabled uses a new idempotency key and grants `100 Y-Coin`; an exact retry replays without a second grant. Each `disabledPaidPackages` item supplies `disabledCode: "FEATURE_DISABLED"` and Indonesian copy explaining that purchase opens after beta. Mobile displays that copy on tap and sends no paid-package mutation.

### 4.5 Interview SSE contract

Every streaming event contains `sessionId`, `requestId`, and a monotonically increasing `sequence` beginning at `0`. The stream emits exactly one terminal event:

| Event | Required data |
|---|---|
| `started` | `answerTurnId` |
| `delta` | non-empty text fragment |
| `evaluation` | structured evaluation; emitted only in Coaching mode |
| `question` | complete next-question object when the session continues |
| `completed` | final persisted turn state; final summary exactly when this answer ends the session |
| `error` | Section 4.3 error object with recoverability in `details` |

Disconnect cancels provider work when safe. Reconnecting clients recover persisted state with `GET /interview/sessions/:id`; partial text is not treated as a committed turn. REST and SSE submissions share the same idempotency claim and cannot evaluate the same answer twice.

### 4.6 Socket.IO match contract

Namespace: `/match`.

```text
# Client → Server
join_queue          { commandId, mode: "ranked" | "casual" | "bot" }
cancel_queue        { commandId }
create_private_room { commandId }
join_private_room   { commandId, code }
cancel_private_room { commandId, code }
open_card           { commandId, roomId, cardId }
play_card           { commandId, roomId, cardId, selectedOptionIndex }
surrender           { commandId, roomId }

# Server → Client
queue_joined
queue_cancelled
private_room_created { code, target, expiresAt }
private_room_joined
private_room_cancelled
match_found
game_state_update
open_card_accepted
card_action_rejected
play_card_result
round_result
match_result
presence_update
error
```

- Private codes use six characters from the exact alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. The Game Backend generates them with a cryptographically secure random source and reserves them atomically in Redis, retrying collisions.
- A code expires exactly 15 minutes after creation if unused. Joining atomically consumes it for one match; cancellation or expiry invalidates it. Each code allows exactly two same-target authenticated users: its creator and its first valid joiner.
- Each client command receives a Socket.IO acknowledgement before any causally resulting domain event. The acknowledgement deadline used by the Section 10.1 metric starts when the Game Backend receives the command.
- `play_card_result` contains `roomId`, `cardId`, actor/target user IDs, correctness, timeout flag, effect, nominal effect value, HP before/after for both players, points before/after, combo before/after for both players, and next card ID.
- `match_result` contains outcome, winner/loser, finish reason, round results, final states, rating/Y-Coin/daily-mission deltas, streak result, and per-system progression flags.
- Rejected commands use the Section 4.3 error object with a stable code, Indonesian message, and `details.recoverable`. Clients display or resync; they never apply a guessed transition.

### 4.7 Live speech socket contract

Namespace: `/interview-speech`. Authentication and session ownership are required before audio is accepted.

- Client events: `start_session { commandId, sessionId }`, `audio_chunk { commandId, sessionId, sequence, audio }`, `finish_answer { commandId, sessionId }`, and `cancel { commandId, sessionId }`.
- Server events: `session_ready`, `transcript_delta`, `transcript_final`, `evaluation`, `question_text`, `question_audio_chunk`, `turn_completed`, `session_completed`, and `error`.
- The lifecycle is `start_session` → `session_ready` → zero or more ordered `audio_chunk`/`transcript_delta` pairs → `finish_answer` → `transcript_final` → evaluation/question events → `turn_completed` or `session_completed`. `cancel` ends capture and provider work without committing a partial transcript as an answer.
- Client audio and server audio/text chunks carry monotonic sequence numbers and bounded payloads. The server rejects gaps, duplicate content under a different command ID, oversize chunks, excessive duration, inactivity, and input beyond advertised backpressure limits using the Section 4.3 error object.
- The final transcript is persisted as the candidate answer. Audio is never a parallel source of truth.

### 4.8 Service ownership

- **Mobile:** authenticated navigation, Indonesian presentation, audio capture/playback, animation, and faithful rendering of server state.
- **App Backend:** Profile, Lobby, Practice, daily missions, streak, analytics, leaderboard, Store, economy, Hired Pass, Interview transport/orchestration, and provider adapters.
- **Game Backend:** Redis matchmaking/private codes, room ownership, Bot, live battle state, reconnects, and exactly-once result finalization.
- **Database:** constraints, RLS, durable ledgers, content, sessions, results, and idempotency uniqueness.
- **AI:** provider adapters, prompts, structured-output validation, safety, evaluation fixtures, and latency/fallback behavior.
- **Content:** taxonomy, answers, explanations, hints, company context, versioned Store catalog, and season manifests.
- **DevOps:** Redis, secrets, containers, deployment, routing, dashboards, alerts, backup, and recovery.
- **QA:** contract, boundary, cross-client, payment-less beta economy, streaming, load, and release acceptance.

---

## 5. Battle and matchmaking rules

### 5.1 Mode and progression matrix

| Mode | Opponent/source | Persistent history | Ranked result | Y-Coin result | Daily mission/streak | Pass activity |
|---|---|---:|---:|---:|---:|---:|
| `bot` | Server Bot | Yes | No | No | No | No |
| `casual` | Public same-target queue | Yes | No | No | Yes on normal completion | Eligible only when a season manifest names public PvP |
| `ranked` | Public same-target queue | Yes | Yes | Yes | Yes on normal completion | Eligible only when a season manifest names public PvP/Ranked |
| `private` | Six-character room code | Yes | No | No | No | No |

Surrender, disconnect-forfeit, and abandoned matches never complete a daily mission or streak for either player. Abandoned matches have zero progression. Ranked surrender/disconnect outcomes still apply the normal win/loss rating and Y-Coin result exactly once.

### 5.2 Room creation and cards

1. Public queues are partitioned by target and mode. Private join validates the creator's target.
2. The server creates a room from active target-specific database questions and assigns an owning Game Backend instance.
3. Both players use the same deterministic source pool but receive private card instances. A client receives no correct answer before its card resolves.
4. Each player starts a round at `100 HP`, `0` points, combo `x1`, and a hand of four cards.
5. Players act independently. Each player can have at most one opened card. Opening starts its server timer; another card cannot be opened until the current card resolves.
6. Answer, server timeout, or surrender resolves atomically. A resolved card is consumed and replaced from the room pool.
7. Incoming attacks never consume or reshuffle the defender's visible hand.
8. When the pool is exhausted, the server deterministically recycles source questions with fresh public card-instance IDs. Question exhaustion never ends a match.

### 5.3 Effects, combo, and points

The question's `effect` field, not its category, determines Damage or Heal.

```text
nominalEffect = 5 × clamp(comboLevelBeforeAnswer, 1, 3)
```

| Resolution | HP effect | Points | Actor combo after resolution |
|---|---|---:|---|
| Correct Damage | Subtract nominal effect from opponent, floor at `0` | Add nominal effect | Increase one, maximum `x3` |
| Correct Heal | Add nominal effect to actor, cap at `100` | Add nominal effect even if HP cap reduces actual healing | Increase one, maximum `x3` |
| Wrong/timeout | None | `0` | Decrease one, minimum `x1` |

- Damage and Heal use the combo before the correct answer advances it, so valid values are exactly `5`, `10`, and `15`.
- A correct answer starts or refreshes a seven-second combo window. Expiry resets combo to `x1`.
- Incoming Damage lowers the defender's combo by one, minimum `x1`. It does not start a new combo window.
- HP always remains within `0..100`. Weight, `damage_value`, and `heal_value` never change MVP battle effects.
- The server emits the authoritative before/after HP, points, and combo values. Mobile animates those values without recalculation.

### 5.4 Rounds and match completion

- A match is best-of-three: first to two round wins, maximum three rounds.
- Each round lasts at most 180 seconds and ends immediately if either player reaches `0 HP`.
- At HP-zero or timer expiry, the player with higher remaining HP wins the round. Equal HP ties the round; points do not break the tie.
- A non-final round has a three-second server-timed break. The next round resets HP, points, combo, opened card, timers, and starting hands.
- The match ends immediately when a player reaches two round wins. Otherwise, after round three, more round wins wins; equal round wins produce a draw.
- Surrender ends the match immediately and awards the opponent the match win.
- A disconnected human has a 30-second reconnect grace period while server timers and Bot turns continue. A newer authenticated socket replaces the old socket and receives current state.
- Grace expiry awards the connected opponent a disconnect win. If both humans are offline at expiry, the match is an abandoned draw with zero progression.
- Match finalization, logs, rating, Y-Coin, daily missions, streak, and Pass activity commit idempotently; clients never retry these as separate balance mutations.

### 5.5 Ranked results

| Outcome | Rank delta | Y-Coin delta |
|---|---:|---:|
| Win | `+20` | `+10` |
| Loss | `-12` | `+3` |
| Draw | `0` | `+5` |

Rank points are floored at zero. The Ranked delta commits before a first-of-day Daily PvP reward. Example: a user at zero who loses the first qualifying Ranked match remains at zero after `-12`, then receives `+80`, ending at `80`.

### 5.6 Bot behavior

- Bot mode uses the authenticated Game Backend, not a client state machine.
- The Bot schedules a turn after a random server delay from `3.3` through `5.9` seconds, prefers Damage, and otherwise selects its first available card.
- The Bot answers correctly and follows the same hand, timer, combo, Damage, Heal, round, and match rules.
- The Bot uses a fixed server-owned character/tower and the human's target arena/question pool.
- All Bot timers are cancelled when the room finishes or is abandoned.

---

## 6. Hired Pass, Y-Coin, Store, and catalog authority

### 6.1 Y-Coin ledger and allowed sources

- The backend is authoritative for every Y-Coin delta and the resulting non-negative balance.
- MVP positive sources are repeatable beta Store credit, Ranked results, free-track claims, and premium-track claims.
- MVP debits are cosmetic purchases and `100 Y-Coin` Interview session charges.
- Y-Coin never expires, cannot be transferred, and cannot be changed directly by Mobile or an authenticated database client.
- Every mutation writes an immutable ledger entry with reason, reference, idempotency key, and balance after.

### 6.2 Beta Store behavior

- While `ENABLE_BETA_ECONOMY_CREDIT=true`, Store shows `beta-100`: `100 Y-Coin`, price label `GRATIS`.
- The package is intentionally repeatable during beta. Each intentional tap uses a new idempotency key; a network retry with the same key returns the original result and does not double-credit.
- Other Y-Coin packs remain visible but disabled. Tapping one displays Indonesian copy that paid top-ups become available after beta.
- Real payment, receipt validation, refunds, and payment-gateway selection are post-MVP.

### 6.3 Cosmetic Store and loadout

- The server catalog is authoritative for character and tower items, rarity, Y-Coin price, availability, and Pass exclusivity.
- Arena items are excluded. Target selects the battle arena.
- Purchases are permanent and atomic: verify active item, reject Pass-exclusive direct purchase, reject duplicates, lock balance, debit once, grant inventory once, and return the committed balance.
- A user can equip only an owned active character/tower. Loadout changes never affect mechanics.
- Mobile consumes catalog results and displays server failures. It has no production static-catalog or local-purchase fallback.

### 6.4 Hired Pass season and entitlement

- A season starts at `00:00:00` on the first calendar day and ends exclusively at `00:00:00` on the first day of the next month in `Asia/Jakarta`.
- Season windows cannot overlap, and exactly one release season is active.
- Every user earns Pass Points and can claim the free track.
- Beta activation is a user-facing, server-authoritative action available behind its feature flag. It activates the current season once per user and grants no automatic Y-Coin.
- The entitlement's unique user/season key enforces the activation limit. Retrying the original activation key replays its result; a later key for the same season returns the existing entitlement without another mutation.
- Hired Pass does not auto-renew and is not prorated. It expires at season end regardless of activation date.
- A late activation unlocks premium claims for all milestones already reached.
- At season end, Pass Points and unclaimed rewards expire. Claimed Y-Coin remains in the balance and claimed cosmetics remain permanently owned/equippable.
- Expiry removes premium claiming and ad-stub suppression only.

### 6.5 Seasonal missions and rewards

- Each checked-in versioned season manifest defines the season ID/window, daily/weekly/whole-season missions, target counts, Pass Point awards, milestone thresholds, free rewards, premium rewards, and Pass-exclusive item IDs.
- Daily periods reset at `00:00 Asia/Jakarta`; weekly periods start Monday `00:00 Asia/Jakarta`; whole-season progress uses the season window.
- Allowed activity sources are normal Practice completion, normal public PvP completion, normal Ranked completion/win, Interview completion, and streak-day creation. Bot and Private never qualify.
- One source event can advance every matching active mission once, but retries cannot increment again.
- At each paired milestone, the premium reward contains more Y-Coin than the free reward, or contains at least one Pass-exclusive cosmetic in addition to at least the free reward's Y-Coin amount. The manifest validator enforces this rule, and every season contains at least one Pass-exclusive cosmetic.
- Rewards require an explicit, idempotent user claim. Free rewards require points; premium rewards require points plus an active entitlement for that season.

### 6.6 Catalog deployment rules

Store catalogs and season manifests are version-controlled inputs validated before deployment. Validation rejects duplicate IDs, unknown types/sources, negative values, missing referenced items, overlapping seasons, unreachable milestones, premium/free pairs that violate Section 6.5, and a release with no active season. Mobile never embeds authoritative copies.

---

## 7. AI Mock Interview

[`PRD-AI-INTERVIEW.md`](./PRD-AI-INTERVIEW.md) is an implementation reference. This section is the authoritative product contract when the documents differ.

### 7.1 Session access and lifecycle

- Every new session costs exactly `100 Y-Coin` for free and Hired Pass users.
- Session creation requires an idempotency key, sufficient balance, active company context, target role, mode, language `id`, and response style.
- In one transaction, the server debits `100`, records the coin ledger/charge, creates the session/context snapshot, and persists a deterministic opening question. Any failure before all four commit rolls back the debit and session.
- The opening question is the Indonesian template `Ceritakan tentang diri Anda dan mengapa Anda tertarik pada posisi {targetRole} di {companyName}?`, populated from the validated request and context snapshot without an LLM call.
- Retrying the same creation key returns the existing session and charge. A session is never charged twice.
- A successfully created/resumable session is not automatically refunded for a later provider or speech failure.
- A normal session contains five candidate-answer turns: one deterministic opening and up to four provider-generated follow-ups. After the fifth completed answer, the server persists the final summary and closes the session.
- The user can explicitly complete after at least one answered turn; the summary uses the available evidence. Cancelling before one answer marks the session cancelled without a summary or refund.
- At most one answer per session is processing. Concurrent submissions return `CONFLICT` unless they replay the same idempotency key.

### 7.2 Modes and evaluation

| Mode | Disclosure behavior |
|---|---|
| `realistic` | Stores each structured evaluation but hides it until the final summary. Follow-ups remain natural and do not coach the user. |
| `coaching` | Returns the structured evaluation after every completed answer and then supplies the next question. |

Every completed answer produces a validated provider-independent structure:

- `overallScore` and `relevance`, `clarity`, `structure`, `confidence`, `impact`, and `authenticity`, each integer `0..100`;
- candidate facts used for continuity;
- `1..5` strengths and improvements;
- suggested rewrite;
- next question unless the session is ending; and
- an Indonesian coaching note in Coaching mode.

The final summary contains overall/dimension scores, evidence-based strengths, improvement priorities, a concise practice plan, and disclosure that the assessment is learning guidance rather than an employment decision.

### 7.3 Provider-neutral strategy

- All reasoning providers implement the same `InterviewLlmClient` input, structured output, streaming, timeout, and cancellation contract.
- No provider is permanently canonical in MVP. Deployment selects a primary and can configure a fallback; at least one provider must pass the evaluation and streaming contract before release.
- Provider/model names never alter client schemas, scoring dimensions, disclosure, price, or session length.
- The opening question is deterministic. Company context is versioned and snapshotted at session creation. Rolling summary and bounded recent turns keep the input within configured budgets.
- Provider output is schema-validated. One repair attempt is allowed for malformed output; primary failure can fall back once. If no provider succeeds, the answer remains retryable and does not count as a completed turn.
- Prompts, candidate text, evaluations, and provider errors use request/session correlation while excluding secrets from logs.

### 7.4 Text and voice behavior

- Text answers support ordinary REST and SSE streaming. Both paths use the same idempotency claim and persist the same final turn.
- Recorded voice uploads audio, receives a transcript, lets the user review/edit it, and submits the reviewed text as the answer.
- Live voice streams bounded audio chunks, returns partial/final transcript, evaluates the final text, and streams the next question text/audio.
- Text is the sole domain source of truth. STT never submits without a final transcript, and TTS never changes question content.
- Speech failure degrades to text within the paid session. It does not invalidate or duplicate a completed text turn.
- Raw candidate audio is deleted after transcription or live-session termination and is never used for training. Generated question audio is ephemeral and can be regenerated from persisted text.

### 7.5 Safety and privacy

- Interview content is private to the owning user and service roles.
- The service rejects empty, oversized, unsupported-language, or unsafe audio/text inputs with stable errors.
- The product must not claim official hiring authority, infer protected traits, or present scores as a guarantee.
- Account deletion removes or irreversibly anonymizes interview content according to the release privacy policy; operational logs retain no raw audio or full answer text.

---

## 8. Dependency-ordered MVP delivery gates

These are acceptance gates, not calendar estimates. Work can overlap, but a gate passes only when all listed outcomes are demonstrated.

### Gate 0 — Contracts and content inputs

- This PRD is approved and reflected in request/response types shared with Mobile and QA.
- Error and idempotency conventions have contract fixtures.
- The Store catalog and an active versioned season manifest validate in CI.
- Content taxonomy/mapping is approved by the CPNS/BUMN SME.

### Gate 1 — Authoritative learning foundation

- Clean and current databases migrate and receive at least 100 approved questions per target through the idempotent importer.
- Auth route guards and ownership/RLS tests pass.
- Practice, history, analytics, daily missions, rank ledger, streak, Lobby summary, and recommendation work without local fallback state.
- WIB midnight, Monday, and month-boundary tests pass.

### Gate 2 — One battle engine for every mode

- Damage, Heal, combo, timer, round, and finish tests cover the Section 5 matrix.
- Mobile Bot uses the Game Backend and contains no production local question/effect engine.
- Casual, Ranked, Bot, and Private run through the same engine; room-code TTL/same-target/single-use behavior passes.
- Match history and all Ranked/daily/streak/Pass mutations finalize exactly once.

### Gate 3 — Economy and Hired Pass

- Mobile consumes the server Store catalog, balance, inventory, loadout, season, missions, rewards, entitlement, and claims.
- Repeatable `GRATIS` beta credit works as specified; disabled paid packs show the post-beta message.
- Cosmetic purchase, beta activation, retroactive premium claim, concurrent claim, expiry, and permanent ownership tests pass.
- Free-user result-exit ad stubs and premium suppression pass.

### Gate 4 — Interview completion

- Session charge and creation are atomic; insufficient balance and retry tests pass.
- Five-turn Realistic and Coaching sessions pass with provider-independent schemas.
- REST, SSE, recorded voice, and live voice complete; disconnect, cancellation, fallback, invalid provider output, and text degradation pass.
- Context fixtures and an evaluation set are approved by AI and Product.

### Gate 5 — Scale and release

- Redis coordination and routing pass with two Game Backend instances.
- Service containers, liveness, readiness, graceful shutdown, migrations, backups, recovery, dashboards, alerts, and saved load results exist.
- The complete two-device staging regression and Section 10 release checklist pass.

---

## 9. Role acceptance criteria

| Owner | MVP acceptance responsibility |
|---|---|
| Product/Design | Approve this PRD, Indonesian copy, safe ad-stub placement, catalogs/manifests, Interview evaluation disclosure, and end-to-end journeys |
| Mobile | Remove production local authority/fallbacks; implement auth routing, server Store/Pass/Lobby, all match modes, explicit effects, SSE, recorded/live voice, and accessible result states |
| App Backend | Own Profile, Practice, Lobby, daily missions, rank/streak, analytics, economy, Hired Pass, Interview transport, authorization, ledgers, and stable errors |
| Game Backend | Own Redis queues/codes, room routing, all battle rules, Bot lifecycle, reconnects, event schemas, logs, and exactly-once finalization |
| AI | Deliver interchangeable provider adapters, structured validation, streaming/cancellation, safety, evaluation fixtures, and provider latency/error reporting |
| Content/SME | Approve target taxonomy, answers, explanations, hints, minimum coverage, company context, Store catalog, and every release season manifest |
| DevOps | Provision environments/Redis/secrets, route sticky sockets, deploy containers, run migrations, monitor services, and prove backup/recovery |
| QA | Own black-box rule matrices, cross-client ordering/retry/reconnect, WIB boundaries, economy/Pass concurrency, streaming, accessibility, load, and release evidence |

---

## 10. Non-functional and release requirements

### 10.1 Performance and capacity

Staging must meet these p95 targets under the saved pilot load profile:

| Measurement | Target |
|---|---:|
| App Backend REST, excluding AI/speech | `≤500 ms` |
| Game socket command acknowledgement in the deployment region | `≤250 ms` |
| AI text first SSE `delta`, including configured provider | `≤5 s` |
| Public matchmaking when a compatible opponent is already queued | `≤2 s` |
| Tested connected sockets | `500` |
| Tested simultaneously active rooms | `200` |

No result, purchase, claim, charge, or daily reward is lost or duplicated during the load run. Monthly pilot availability target is `99.5%`, excluding announced maintenance.

### 10.2 Security and integrity

- Validate JWT and ownership on every private REST/SSE/socket operation.
- Authenticated clients cannot directly update questions, correct answers, rank points, balances, inventory, entitlements, mission progress, streaks, match results, or Interview evaluations.
- Service-role credentials and provider secrets stay server-side and never enter logs, mobile bundles, or responses.
- Correct answers remain hidden until resolution. Public battle payloads never include source answer keys.
- RLS and service-only functions are integration-tested against a migrated database.
- Apply request/body/audio limits and per-user rate limits to auth, beta credit, matchmaking, room creation/join, Interview creation/turns, and speech.
- Logs identify users through IDs needed for operations and exclude passwords, tokens, raw audio, full candidate answers, and unrevealed correct answers.

### 10.3 Reliability and observability

- Liveness proves the process is running. Readiness becomes false when a required database, Redis, or service dependency makes new work unsafe.
- Graceful shutdown stops new work, removes queue entries, drains or hands off connections as designed, finalizes completed matches, cancels Bot/provider jobs, and closes dependencies.
- Structured logs carry `requestId`, `userId`, `roomId`, `matchId`, and `sessionId` where applicable.
- Metrics include REST latency/errors, active sockets/rooms, matchmaking latency, event-loop lag, Redis health, database latency, match-finalization failures, economy mutation failures, provider latency/errors, SSE disconnects, and speech failures.
- Alerts cover sustained readiness failure, Redis/database unavailability, duplicate-finalization attempts, provider error spikes, and balance/claim transaction failures.

### 10.4 Accessibility, language, and privacy

- User-facing MVP copy is Indonesian. Stable identifiers, code, and this PRD are English.
- Authentication, Lobby, Practice, match controls/results, Store, Hired Pass, and Interview support screen-reader labels, logical focus order, text scaling, and non-color-only status indicators.
- Interactive controls meet a minimum `44×44` logical-pixel target and readable text/contrast requirements.
- Interview text is private to its owner and service roles. Raw speech audio follows Section 7.4 deletion rules.
- Account deletion removes or irreversibly anonymizes user-owned learning and Interview content while retaining only legally/operationally required aggregate or transaction audit data.

### 10.5 Required test suites

- Unit tests for all formulas, transitions, validation, error mapping, and deterministic recommendation ties.
- Database integration tests for migrations, RLS, importer idempotency, ledgers, daily/season boundaries, concurrent Store/Pass/Interview mutations, and match finalization.
- Contract tests for REST, SSE, `/match`, and `/interview-speech` payloads/errors.
- Socket end-to-end tests for two clients, Bot, Casual, Ranked, Private, timeout, surrender, disconnect/reconnect, stale sockets, duplicate commands, and two Game Backend instances.
- Mobile integration tests proving no local-success fallback and correct loading/error/retry states.
- Provider evaluation tests for both Interview modes, five turns, malformed output, fallback, streaming order, cancellation, and speech-to-text degradation.
- Repeatable load tests for the Section 10.1 profile.

### 10.6 Release checklist

A release candidate is rejected unless all items are true:

- compilation, static analysis, unit, integration, contract, E2E, and load tests pass;
- migrations pass from a clean database and the current deployed schema;
- active question coverage, Store catalog, company context, and season manifest validate;
- two physical clients complete Practice, every match mode, Store/Pass, and every Interview transport in staging;
- beta-only flags are explicitly set and paid packages cannot mutate balance;
- no private route, deep link, or disconnected repository falls back to local authoritative state;
- dashboards/alerts receive staging events, secrets are scanned, and logs are inspected for leakage;
- backup restore, rollback/forward database recovery, and container rollback steps are exercised and recorded; and
- Product, QA, Content, AI, App Backend, Game Backend, Mobile, and DevOps sign off on their Section 9 responsibilities.

### 10.7 Primary risks and fixed mitigations

| Risk | Required mitigation |
|---|---|
| Split or duplicate matchmaking | Redis atomic queue/code operations, ownership metadata, sticky routing, TTL cleanup, and controlled outage errors |
| Provider cost/reliability | Fixed `100 Y-Coin` access, one pending answer, bounded context, timeout/cancel, schema validation, one fallback, and text degradation |
| Question obsolescence or bad answers | Stable source keys, structured taxonomy, soft deactivation, import reports, minimum coverage, and SME approval |
| Beta currency inflation | Explicit beta banner, separate ledger reason, feature flag, disabled paid packs, and no claim that beta balance represents real-money value |
| Season/reward drift | Checked-in manifest validation, non-overlapping windows, immutable claim snapshots, and deployment failure without an active valid season |
| Client/server divergence | Server authority, shared contract fixtures, no production local fallbacks, and two-client acceptance tests |

---

## Change control

Product approves behavior and economy changes. Backend, Mobile, AI, DevOps, Content, and QA approve changes affecting their contracts or acceptance criteria. A decision is complete only after this file, affected versioned catalogs/manifests, contract fixtures, and tests agree in the same change.
