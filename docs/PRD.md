# YUDHA — Product Requirements and Architecture Contract

> **Status:** Approved product contract; Learning V2 Gate 5 remains blocked by explicit decision debt
> **Version:** 2.0
> **Last updated:** 2026-09-01
> **Product timezone:** `Asia/Jakarta` (WIB, UTC+7)
> **User-facing language:** Indonesian
> **Audience:** Product, Mobile, Web, App Backend, Game Backend, Data, AI, Security, DevOps, Content, and QA

## Document authority

This file is the single source of truth for YUDHA product behavior, business rules, service ownership, public contracts, and release acceptance. Section 11 is the approved Learning System V2 contract. Its delivery gates control when target behavior replaces the legacy Practice compatibility flow.

- If code, tests, tickets, mockups, archived documents, or [`PRD-AI-INTERVIEW.md`](./PRD-AI-INTERVIEW.md) conflict with this file, **this file wins** until an approved change updates it.
- `must` and `shall` are mandatory. `may` describes an explicitly permitted choice, not an undecided requirement.
- [`LEARNING-SYSTEM-V2-DRAFT.md`](./LEARNING-SYSTEM-V2-DRAFT.md) and archived gap documents are historical design and audit material, not separate active specifications.
- Database migrations are the executable physical schema. The logical models in this file define the behavior the schema must support.
- Store catalogs and Hired Pass season manifests are versioned product data. They may change content and prices but must not change the mechanics or safety boundaries defined here.
- Any pull request that changes observable behavior, business values, an API/socket shape, or an MVP boundary must update this file in the same pull request.

---

## 0. Product definition

### 0.1 One-liner

**YUDHA (Your Ultimate Digital Hiring Arena)** is a gamified learning platform that builds CPNS and BUMN selection readiness through Solo learning, real-time card battles, explainable analytics, future Assessment evidence, and AI mock interviews with text and voice interaction.

### 0.2 Target user and product promise

The MVP serves Indonesian CPNS and BUMN candidates who want repeatable practice, visible learning progress, and realistic interview rehearsal. YUDHA is a learning product. It does not guarantee employment, predict an official examination result, or issue an official certification.

### 0.3 Product principles

1. **Learning first:** monetization and cosmetics never improve HP, damage, healing, answer time, score, question quality, matchmaking priority, rating, or AI evaluation quality.
2. **Server authority:** servers own questions, answers, timers, battle state, progression, balances, inventory, entitlements, missions, streaks, and recommendations. Mobile never invents a successful mutation.
3. **One battle ruleset:** Bot, Casual, Ranked, and Private modes use the same server battle engine.
4. **Recoverable mutations:** purchases, credits, mission rewards, reward claims, interview turns, and match finalization are idempotent.
5. **Explainable personalization:** recommendations use deterministic, versioned metrics and return their supporting evidence. LLM output never controls learning state, access, or progression.
6. **Evidence integrity:** immutable attempts preserve source context; Solo, Assessment, and Competition evidence remain distinguishable and are never collapsed into a misleading mastery percentage.

### 0.4 Canonical terminology

| Term | Meaning |
|---|---|
| **Target** | The user's exam track: `cpns` or `bumn`. It selects content, matchmaking queues, the fixed battle arena, and interview context. |
| **Solo** | The canonical learner-controlled question-practice lane. Legacy logical and public names containing `practice` are compatibility surfaces only. |
| **Mechanic** | The timing behavior of a Solo session: `focus`, `standard`, or `speed`. |
| **Question selection** | The independent content-selection strategy: `balanced`, `recommended`, or `custom`. |
| **Delivery policy** | The versioned server policy that decides how a Solo session stops. The initial Solo slice uses a learner-selected fixed count of 20, 35, or 50 questions. |
| **Skill** | A versioned SME-approved learning-taxonomy node used to classify questions and aggregate evidence. The actual CPNS/BUMN catalog is a separate approved artifact. |
| **Attempt** | One immutable, server-authoritative answer outcome in the canonical learning ledger. |
| **Assessment** | A future web-based validation lane. Mobile displays imported results only; Assessment never becomes the primary next action. |
| **Competition evidence** | PvP answer evidence retained as a separate context; it does not become Solo mastery evidence. |
| **PvP** | Human-versus-human play. Bot mode is not PvP. |
| **Public match** | A human Casual or Ranked match created by matchmaking. |
| **Private match** | A human match created with a room code. It is unranked and has no progression. |
| **Normal completion** | A server-finalized activity that is not abandoned or invalidated and, for a match, is not ended by either player's surrender or disconnect. A future Solo session qualifies only with completion reason `policy_completed`. |
| **Rank points** | Persistent, non-seasonal competitive/engagement progression used for leaderboard ordering and tier. Daily Lobby missions and Ranked results both change this balance; it can increase or decrease but is never reset and is floored at zero. |
| **Y-Coin** | Persistent, non-transferable virtual currency used for cosmetics and AI Interview sessions. It can be obtained through beta Store credits, Ranked rewards, and Hired Pass tracks. It never expires. |
| **Pass Points** | Non-spendable progress for one Hired Pass season. They reset at season end and cannot be purchased or transferred. |
| **Hired Pass** | The only MVP premium entitlement. It unlocks the current season's premium reward track and suppresses ad stubs until that season ends. |
| **Business day** | A calendar date in `Asia/Jakarta`. Servers store timestamps in UTC and convert them for day/week/season rules. |

---

## 1. Product boundaries

### 1.1 Included in MVP

| # | Capability | Required outcome |
|---|---|---|
| 1 | Supabase email/password authentication | Secure registration, login, verification, restoration, logout, and private-route protection |
| 2 | Authoritative Lobby | Profile/tier, two daily missions, streak, Hired Pass summary, and one next-action recommendation |
| 3 | Solo learning and Practice compatibility | Approved V2 evidence, learner state, recommendation, dashboard, and future Solo contracts; the current five-question Practice flow remains available through compatibility APIs until Gate 5 |
| 4 | Bot battle | Single-player battle through the server battle engine |
| 5 | Casual and Ranked PvP | Same-target public matchmaking and server-authoritative real-time play |
| 6 | Private PvP | Create/join with a six-character room code and persist history without progression |
| 7 | Learning analytics, tiers, and leaderboard | Transparent evidence metrics, confidence, trends, pace, retention, coverage, separate Competition results, rank points, and deterministic Solo recommendations |
| 8 | Validated CPNS/BUMN content | Reproducible, idempotent database provisioning with content checks |
| 9 | AI Mock Interview | Text request/response, text SSE streaming, recorded voice, live voice, evaluations, and final summary |
| 10 | Y-Coin and Store | Repeatable beta credit, authoritative balance, character/tower catalog, purchase, inventory, and loadout |
| 11 | Hired Pass | Server beta activation, mixed-cadence seasonal missions, free/premium tracks, permanent claimed cosmetics, and ad-free state |
| 12 | Ad-placement stubs | Free-user result-exit trigger and premium suppression without a production ad SDK |
| 13 | Multi-instance readiness | Redis-coordinated matchmaking, health/readiness, observability, graceful shutdown, integration tests, and load tests |

### 1.2 Explicitly excluded from MVP

- community discussions, guilds, tournaments, spectators, and battle replays;
- content marketplace, official certification, and institutional/B2B dashboards;
- general-purpose web or desktop clients, except the explicitly scoped future web Assessment lane and internal single-admin-role content-quality surface in Section 11;
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
- Solo/legacy Practice, Bot, Casual, Ranked, and Private modes use database-provisioned questions;
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
  → Lobby: tier + rank points + daily missions + streak + one Solo recommendation
    → Solo: choose mechanic + question selection → answer authoritative session → Results
       ↳ current release compatibility: Practice → 5 locked questions → Results
    → Battle:
       → Bot
       → Casual or Ranked public queue
       → Create or join Private room code
    → Hired Pass: view season missions and claim free/premium milestones
    → Store: claim beta Y-Coin, buy/equip character or tower
    → Learning Dashboard/Profile: skill state, evidence, trends, pace, retention, activity
    → Competition: separate PvP analytics, rank, leaderboard, and history
    → Assessment Results: display future imported validation evidence
    → AI Interview: spend 100 Y-Coin → text/voice session → evaluation/summary
```

The learning loop is: **Solo/PvP/Assessment evidence → immutable attempts → versioned learner state → primary Solo recommendation → dashboards → new evidence**.

### 2.2 Authentication and target

- Registration requires email, password, username, and target (`cpns` or `bumn`).
- Every private REST route and socket namespace requires a valid Supabase JWT.
- While session restoration is unresolved, authenticated screens remain in a loading state. Unauthenticated deep links redirect to Login and preserve their intended destination.
- A target change affects activities created afterward. Existing Solo/Practice, match, Assessment, and Interview records retain their target snapshot.
- Public and Private PvP require both humans to have the same target.
- Target selects one canonical arena: CPNS users see the CPNS arena and BUMN users see the BUMN arena. `equipped_arena_id` is compatibility-only and has no MVP behavior.

### 2.3 Access and monetization

| Capability | Free user | Active Hired Pass |
|---|---|---|
| Solo/Practice, Bot, Casual, Ranked, Private | Full access | Full access |
| AI Interview | `100 Y-Coin` per new session | Same `100 Y-Coin` cost |
| Character/tower Store | Buy with Y-Coin | Buy with Y-Coin |
| Free reward track | Earn and claim | Earn and claim |
| Premium reward track | Progress visible; claims locked | Claim reached milestones, including milestones reached before activation |
| Pass-exclusive cosmetics | Preview only | Claim from premium milestones |
| Result-exit ad stub | Triggered at defined safe breaks | Suppressed while entitlement is active |

There are no Solo/Practice or battle quotas. Hired Pass never changes learning content, evidence classification, recommendation priority, battle mechanics, matching, ranking, or Interview quality.

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
- Every active question maps to one versioned SME-approved skill-taxonomy node. Taxonomy versions are immutable once used by evidence; mappings may be superseded without rewriting historical attempt snapshots. The actual CPNS/BUMN skill catalog remains a separate approval artifact and is not invented by this PRD.
- Each active question has one target, category, optional subcategory, `2..6` non-empty options, exactly one valid zero-based correct index, difficulty, weight `1..4`, effect (`damage` or `heal`), a non-empty explanation, an optional hint, and a positive time limit.
- `weight` affects Practice score only. `damage_value` and `heal_value` are compatibility metadata and do not affect MVP battles.
- Clients never receive the correct option or explanation before an answer resolves.
- A clean database must be provisionable with one documented idempotent command. Import validation reports inserted, updated, skipped, invalid, and duplicate records.
- Each enabled target requires at least `100` active, SME-approved questions and at least `20` in every enabled top-level category before release.

### 3.2 Solo rules and Practice compatibility

- Section 11 is authoritative for new logical names, evidence, mechanics, question selection, timers, hints, stopping rules, and interfaces.
- New contracts use `solo`; physical `practice_*` records and `/practice/*` endpoints are temporary compatibility surfaces.
- Focus, Standard, and Speed are timing mechanics independent of Balanced, Recommended, and Custom question selection.
- Hints are server-tracked in every mechanic. A hinted attempt is assisted evidence and is excluded from independent mastery and pace decisions.
- Focus has no deadline. Standard uses the authoritative question limit. Speed targets `90%` of the learner's recent comparable median and requires at least five valid pace attempts; otherwise it behaves as Standard with a warning and does not produce true Speed evidence.
- Manual Speed is permitted below `85%` smoothed independent accuracy with a warning, but the server never recommends it below that threshold.
- Standard and Speed timeouts are server-authoritative, race-safe, and idempotent. Answer and reconciliation retries cannot create duplicate attempts.
- The initial Solo slice has an approved learner-selected fixed count, target-specific Balanced allocation, no within-session duplicates, deterministic inventory fallback, explicit early stop, and resumable session behavior. Difficulty progression, adaptive delivery, final taxonomy weights, and intentional cross-session repetition remain deferred. Five questions is not a V2 invariant.
- Until that debt closes and Gate 5 passes, the existing Practice adapter retains its locked five-question behavior, score, completion, and client contract. Its answers are backfilled into the canonical ledger only with evidence the source actually captured; missing timing, exposure, hint, version, or skill data is never fabricated.
- Only future Solo sessions completed with `policy_completed` qualify for daily mission, streak, Hired Pass, or normal-completion effects. All retries return the original committed result without duplicating attempts, activity, or rewards.

### 3.3 Daily Lobby missions and rank tiers

Daily Lobby missions are a separate system from Hired Pass missions. The two fixed MVP missions are:

| Mission | Completion condition | Automatic reward |
|---|---|---:|
| Daily Solo | Complete an eligible learning session | No rank-point reward |
| Daily PvP | Normally complete one public Casual or Ranked match, regardless of outcome | `+80 rank_points` |

- Each mission can reward a user once per `Asia/Jakarta` business date.
- Solo never mutates competitive rank points. Its initial direct result reward is server-authoritative Y-Coin: `+10` when every question is correct and the tower is destroyed, `+3` when all questions are resolved but the tower remains, and `0` when the learner stops early. Direct Solo rewards are capped at `30` Y-Coin per WIB business date.
- A mission date runs from `00:00:00` inclusive to the next `00:00:00` exclusive in `Asia/Jakarta`; an activity belongs to the date containing its server completion timestamp.
- Rewards apply automatically from idempotent server completion events; there is no manual claim button.
- For a Ranked match, the result delta applies first and is floored at zero, then the first-of-day `+80` mission reward applies.
- Daily mission points affect leaderboard order and tier. Tiers are Rookie `0..399`, Warrior `400..799`, Elite `800..1199`, and Legend `1200+`.
- Daily missions have no direct Y-Coin or Pass Point reward.
- During compatibility, a normal five-question Practice completion satisfies Daily Solo. After Gate 5, only a Solo `policy_completed` event qualifies.

### 3.4 Streak

- The server converts the authoritative completion timestamp to `Asia/Jakarta`; client time is ignored.
- A streak-qualifying activity is an eligible Solo completion or a normal public Casual/Ranked completion. During compatibility, a normal five-question Practice completion is the Solo event adapter; after Gate 5, only `policy_completed` qualifies.
- Bot, Private, abandoned, surrender, disconnect-forfeit, and Interview activities do not qualify.
- At most one streak day exists per user per business date.
- The first qualifying date sets `currentStreak=1`. The next consecutive date increments it. A gap of at least one complete business date resets the next activity to `1`.
- There is no grace day or offline backdating. `bestStreak` never decreases.

### 3.5 Daily reminder notifications

- Android and Chromium PWA installations use Firebase Cloud Messaging only as the delivery transport; notification eligibility remains server-authoritative.
- Account preferences default to disabled until explicit notification permission is granted. Morning and streak-rescue reminders can be controlled independently and use editable local wall-clock times, defaulting to `09:00` and `19:30`.
- Each authorized installation stores an IANA time zone and receives at most one reminder of each kind per local calendar date while it has been active within the preceding 30 days.
- The morning reminder is eligible only while at least one Daily Lobby mission is incomplete for the current `Asia/Jakarta` business date.
- The rescue reminder is eligible only when `last_streak_date` is the immediately preceding WIB business date and no qualifying `daily_learning_activity` exists today. Stale or already-protected streaks never produce rescue reminders.
- Reminder messages use normal priority, expire at the next WIB reset, collapse duplicates, contain no sensitive data, and deep-link to Lobby, Solo (or compatible Practice), or public PvP as appropriate.
- A one-time contextual permission prompt may appear after the first authoritative Solo/compatible Practice or public Casual/Ranked completion. Dismissing it prevents further automatic prompts; users retain control from Profile settings and system/browser settings.

### 3.6 Analytics and deterministic recommendation

Section 11 defines the authoritative `learning-v1` analytics and recommendation policy. Every displayed percentage includes numerator, denominator, unique-question count, and confidence. Solo, Assessment, and Competition remain separate evidence contexts.

The primary next action is always Solo. The engine selects exactly one objective through ordered gates—repair, due review, evidence/coverage, fluency, then maintenance—and ranks skills only inside the winning objective. Assessment gap may affect ranking as a separate signal; Assessment, PvP, and AI Interview never become the primary recommendation.

Current state uses the latest 20 eligible unseen-independent Solo attempts per skill. Trend compares latest 10 with previous 10. Thirty days governs activity summaries, not deletion of older learning evidence. Policies, formulas, confidence thresholds, state ordering, weights, and deterministic tie-breakers are normative in Section 11 and versioned as unvalidated `learning-v1` until calibration approves a successor.

For eligible unseen-independent evidence, `smoothedAccuracy = (correct + 2) / (attempts + 4)`. The canonical objective shorthand is **repair → due review → evidence/coverage → fluency → maintenance**.

### 3.7 Leaderboard

- Leaderboard order is descending `rank_points`, then descending Ranked wins, then ascending user ID for deterministic pagination. Casual, Bot, and Private results never affect a leaderboard tie-breaker.
- It exposes paginated entries and an authenticated “my rank” result.
- Daily mission and Ranked result mutations appear only after their authoritative transaction commits.

### 3.8 Ad-placement stubs

- A free user triggers an ad-placement stub only when leaving an eligible Solo Results screen or any server-finalized public Casual/Ranked Results screen, including a surrender or disconnect result. During compatibility, an eligible Solo result is a fully completed five-question Practice result; after Gate 5, it requires `policy_completed`.
- An active Hired Pass suppresses the stub entirely.
- No ad/stub is triggered during a question, battle, Private match, Store purchase, Hired Pass claim, or paid Interview.
- The stub returns immediately and never blocks navigation. Production ad SDK integration is post-MVP.

---

## 4. Architecture and logical data

### 4.1 Technology boundaries

| Layer | Choice | Responsibility |
|---|---|---|
| Mobile | Flutter | Indonesian UI, authenticated navigation, Solo and result experiences, REST/socket/SSE consumption, audio capture/playback, and rendering authoritative state |
| Internal Web | Implementation selected at delivery | Future Assessment operation and single-admin-role content-quality workflow only; not a general customer web client |
| App Backend | NestJS REST/SSE | Profile, Solo/Practice compatibility, canonical learning ledger, learner-state projections, recommendations, dashboards, Lobby, leaderboard, Store, Hired Pass, economy, and Interview orchestration |
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

**`practice_sessions`** (legacy physical compatibility model)
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

**`practice_session_questions`** (legacy physical compatibility model)
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| session_id | uuid (FK → practice_sessions) | |
| question_id | uuid (FK → questions) | |
| question_order | int | position in the locked set |
| created_at | timestamp | |

**`practice_answers`** (legacy physical compatibility model)
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
| `notification_preferences` | Account-level opt-in, reminder toggles, and local wall-clock times |
| `push_installations` | Authorized Android/web FCM installations, IANA time zone, and freshness |
| `notification_deliveries` | Idempotent per-installation reminder attempts, delivery state, and open attribution |
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
| `skill_taxonomy_versions` / `skills` | Immutable versioned SME-approved taxonomy metadata and stable skill identities |
| `question_skill_mappings` | Versioned question-to-skill mappings with effective versions and audit provenance |
| `solo_sessions` / `solo_session_questions` | Target Solo mechanics, selection, delivery-policy snapshot, authoritative question-open/timer state, and completion reason |
| `learning_attempts` | Append-only canonical evidence ledger with source uniqueness, authoritative metadata snapshots, evidence classifications, and `calculationVersion` |
| `learner_skill_state` | Prepared versioned per-user/per-skill state, metrics, confidence, trend, pace, retention, and coverage projection |
| `learning_recommendations` / `learning_recommendation_events` | Deterministic recommendation snapshots and shown/started/completed/dismissed attribution |
| `retention_schedules` | Due-review schedule; first delayed review is seven days and uses an equivalent unseen question |
| `learner_preferences` | Preferred mechanic, question selection, and timed-practice settings |
| `assessment_results` | Future imported Assessment validation evidence kept separate from Solo state |
| `question_quality_projections` / `question_quality_triage` | Internal evidence summaries, manual triage, resolution, and controlled deactivation audit |

Private room codes and public queue entries are ephemeral Redis records, not durable product entities. A created code contains owner, target, owning Game Backend instance, created/expiry timestamps, and single-use status.

### 4.3 Public contract conventions

- External JSON uses `camelCase`; timestamps are ISO 8601 UTC strings.
- Successful REST responses use `{ "data": ... }`. Lists use `{ "data": { "items": [], "limit": n, "offset": n, "total": n } }`.
- Mutating calls named below require an `idempotencyKey` of `1..160` characters. Replaying the same key and same operation returns the first committed result. Reusing it for different input returns `IDEMPOTENCY_KEY_REUSED`.
- Every mutating socket command requires a `commandId` of `1..160` characters. The Socket.IO acknowledgement uses `{ "data": ..., "requestId": ... }` on success or the same `{ "error": ... }` object used by REST on failure, with `details.recoverable` when relevant. Replaying the same command ID returns the original acknowledgement and emits no duplicate domain event; reusing it for different input returns `IDEMPOTENCY_KEY_REUSED`.
- Clients never calculate balances, effects, ratings, streaks, tiers, entitlement state, evidence classification, learning metrics, learner state, timers, or recommendation priority.
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

# Notifications
GET    /notifications/preferences
       → { enabled, morningEnabled, morningTime, rescueEnabled, rescueTime }
PATCH  /notifications/preferences
       { enabled?, morningEnabled?, morningTime?, rescueEnabled?, rescueTime? }
       → updated preferences
PUT    /notifications/installations/:installationId
       { token, platform: "android" | "web", timeZone }
       → registered installation summary
DELETE /notifications/installations/:installationId
       → { removed: true }
POST   /notifications/deliveries/:deliveryId/open
       → { deliveryId, openedAt }

# Solo (canonical Learning V2 family; available when its delivery gate passes)
POST   /solo/sessions
       { idempotencyKey, mechanicMode, questionSelection, recommendationId? }
       → authoritative session and delivery-policy snapshot
GET    /solo/sessions/:id
       → session, progress, opened question state, answers, completion
POST   /solo/sessions/:id/questions/:sessionQuestionId/open
       { idempotencyKey }
       → safe question, openedAt, deadlineAt?, effectiveMechanic, warnings[]
POST   /solo/sessions/:id/questions/:sessionQuestionId/hint
       { idempotencyKey }
       → server-tracked hint and assisted-evidence status
POST   /solo/sessions/:id/answers
       { idempotencyKey, sessionQuestionId, selectedOptionIndex,
         clientActiveResponseTimeMs?, backgroundDurationMs? }
       → authoritative result, attemptId, evidence classification, progress
       (selectedOptionIndex: null reconciles a server-created timeout)
POST   /solo/sessions/:id/finish
       { idempotencyKey, requestedReason? }
       → completionReason, eligibility, after-session feedback
GET    /solo/history?skillId=&limit=&offset=
       → paginated canonical Solo session summaries

# Learning V2
GET    /learning/dashboard
       → nextAction, skillMap, trends, pace, retention, assessmentResults,
         activity, competition
GET    /learning/recommendations/current
       → one primary Solo action with objective, reason, evidence, policy version
POST   /learning/recommendations/:recommendationId/events
       { idempotencyKey, eventType }
       → recommendation attribution state

# Internal content quality (server-managed admin role required)
GET    /admin/content-quality/questions
GET    /admin/content-quality/questions/:questionId
GET    /admin/content-quality/review-cases
POST   /admin/content-quality/review-cases
PATCH  /admin/content-quality/review-cases/:caseId
POST   /admin/content-quality/questions/:questionId/deactivate
POST   /admin/content-quality/questions/:questionId/reactivate

# Practice (temporary compatibility family)
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

# Analytics compatibility / Leaderboard
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

- Client events: `start_session { commandId, sessionId }`, `audio_chunk { commandId, sessionId, answerId, sequence, audio, encoding, sampleRateHz, channels }`, `finish_answer { commandId, sessionId, answerId, finalSequence }`, and `cancel { commandId, sessionId, answerId? }`.
- Server events: `session_ready`, `audio_chunk_ack`, `transcript_final`, `evaluation`, `question_text`, `question_audio_start`, `question_audio_chunk`, `question_audio_end`, `turn_completed`, `session_completed`, and `error`. `transcript_delta` is reserved for future streaming-STT adapters and is not required in the Groq final-transcript release.
- The lifecycle is `start_session` → `session_ready` → ordered `audio_chunk`/`audio_chunk_ack` pairs → `finish_answer` → required `transcript_final` → evaluation/question events → ordered question-audio start/chunk/end events → `turn_completed` or `session_completed`. `cancel` discards the partial answer without committing it and re-arms sequence zero for the active socket/session.
- `session_ready.audioConfig` advertises mono PCM16 (`pcm_s16le`) at 16 kHz, 64 KiB maximum decoded chunks, a 10 MiB/90-second answer limit, and a 15-second inactivity timeout after capture begins.
- Every speech event carries its available correlation IDs and monotonic sequence/final-sequence values. The server rejects gaps, duplicates, answer conflicts, unsupported formats, excessive size/duration, inactivity, and input beyond advertised backpressure limits using the Section 4.3 error object.
- The final transcript is persisted as the candidate answer. Audio is never a parallel source of truth.

### 4.8 Service ownership

- **Mobile:** authenticated navigation, Indonesian presentation, audio capture/playback, animation, and faithful rendering of server state.
- **App Backend:** Profile, Lobby, Solo/Practice compatibility, canonical attempts, learner state, recommendation, dashboards, internal content-quality authorization/workflows, daily missions, streak, leaderboard, Store, economy, Hired Pass, Interview transport/orchestration, and provider adapters.
- **Game Backend:** Redis matchmaking/private codes, room ownership, Bot, live battle state, reconnects, and exactly-once result finalization.
- **Database:** constraints, RLS, append-only learning and economy ledgers, versioned projections, content, sessions, results, and idempotency uniqueness.
- **AI:** provider adapters, prompts, structured-output validation, safety, evaluation fixtures, and latency/fallback behavior.
- **Content/SME:** approve skill-taxonomy artifacts and mappings, answers, explanations, hints, company context, versioned Store catalog, and season manifests; metrics never deactivate content automatically.
- **Data:** own calculation-version implementation, backfill fidelity, projection reproducibility, metric QA, and recommendation-effectiveness measurement.
- **Security:** own admin-role enforcement, auditability, privacy/anonymization verification, and sensitive evidence access review.
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
- Allowed activity sources are eligible Solo completion, normal public PvP completion, normal Ranked completion/win, Interview completion, and streak-day creation. During compatibility, normal Practice completion adapts to eligible Solo activity; after Learning V2 Gate 5, only `policy_completed` Solo qualifies. Bot and Private never qualify.
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
- Recorded voice remains a failure fallback that uploads audio, receives a transcript, lets the user review/edit it, and submits the reviewed text as the answer.
- Android live voice automatically plays each question, then keeps the microphone off until the candidate presses and holds the answer control. PCM16 capture starts on press and release submits the required final transcript for automatic evaluation and next-question playback.
- Presses shorter than 500 ms or without audio are discarded and re-armed without STT. A held answer submits automatically at 90 seconds; interruption cancels it, while transport reconnect replays buffered audio with the same answer ID.
- Text is the sole domain source of truth. STT never submits without a final transcript, and TTS never changes question content.
- Speech failure degrades to text within the paid session. It does not invalidate or duplicate a completed text turn.
- Ending a call after at least one committed answer completes the session and shows the summary. Ending before any answer disconnects while preserving the paid session for resume; REST completion rejects zero-answer sessions.
- Raw candidate audio is deleted after transcription or live-session termination and is never used for training. Generated question audio is ephemeral and can be regenerated from persisted text.

### 7.5 Safety and privacy

- Interview content is private to the owning user and service roles.
- The service rejects empty, oversized, unsupported-language, or unsafe audio/text inputs with stable errors.
- The product must not claim official hiring authority, infer protected traits, or present scores as a guarantee.
- Account deletion removes or irreversibly anonymizes interview content according to the release privacy policy; operational logs retain no raw audio or full answer text.

---

## 8. Dependency-ordered delivery gates

These are acceptance gates, not calendar estimates. Work can overlap, but a gate passes only when all listed outcomes are demonstrated.

### Gate 0 — Contracts and content inputs

- This PRD is approved and reflected in request/response types shared with Mobile and QA.
- Error and idempotency conventions have contract fixtures.
- The Store catalog and an active versioned season manifest validate in CI.
- Content taxonomy/mapping is approved by the CPNS/BUMN SME.
- Learning V2 taxonomy structure and `learning-v1` policy are approved; the actual skill catalog remains a separate SME-owned artifact.

### Gate 1 — Authoritative learning foundation

- Clean and current databases migrate and receive at least 100 approved questions per target through the idempotent importer.
- Auth route guards and ownership/RLS tests pass.
- Solo/Practice compatibility, history, canonical evidence, analytics, daily missions, rank ledger, streak, Lobby summary, and recommendation work without local fallback state.
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

### Learning V2 gates

The detailed acceptance criteria are in Section 11.20. Delivery is ordered as follows:

1. taxonomy and `learning-v1` policy approval;
2. canonical evidence ledger and honest legacy backfill;
3. versioned learner-state analytics;
4. Solo recommendations and learner dashboards;
5. new Solo mechanics only after delivery-policy debt closes; and
6. Assessment ingestion and internal content-quality operations.

Gates 1–4 approve implementation of evidence, state, recommendation, and dashboard foundations without changing the current five-question Practice delivery. Gate 5 may begin with the approved Balanced + Standard fixed-count slice; deferred adaptive, difficulty, recommendation, and final-taxonomy behavior cannot be silently folded into that slice. Gate 6 does not authorize a detailed public Assessment implementation beyond the boundary in this PRD.

---

## 9. Role acceptance criteria

| Owner | MVP acceptance responsibility |
|---|---|
| Product/Design | Approve this PRD, Learning V2 policy/debt closures, Indonesian copy, safe ad-stub placement, catalogs/manifests, Interview evaluation disclosure, and end-to-end journeys |
| Mobile | Remove production local authority/fallbacks; implement authoritative Solo/result/dashboard states, auth routing, server Store/Pass/Lobby, all match modes, explicit effects, SSE, recorded/live voice, and accessible result states |
| Web | Implement only the approved future Assessment boundary and internal content-quality workflow with server authorization |
| App Backend | Own Profile, Solo/Practice adapters, canonical learning ledger, state/recommendation projections, dashboards, Lobby, daily missions, rank/streak, economy, Hired Pass, Interview transport, authorization, ledgers, and stable errors |
| Game Backend | Own Redis queues/codes, room routing, all battle rules, Bot lifecycle, reconnects, event schemas, logs, and exactly-once finalization |
| AI | Deliver interchangeable provider adapters, structured validation, streaming/cancellation, safety, evaluation fixtures, and provider latency/error reporting |
| Data | Prove classification, formulas, calculation versions, lower-fidelity backfill, projection reproducibility, deterministic ties, and effectiveness measurement |
| Content/SME | Approve skill-taxonomy artifacts/mappings, answers, explanations, hints, minimum coverage, question-quality resolutions, company context, Store catalog, and every release season manifest |
| Security | Verify single-admin-role authorization, audit trails, controlled deactivation, privacy, deletion, and anonymization boundaries |
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

- Validate JWT and ownership on every private REST/SSE/socket operation; internal content-quality routes additionally require the server-managed admin role.
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
- Metrics include REST latency/errors, attempt-ledger conflicts, projection lag/failures, recommendation calculation versions, active sockets/rooms, matchmaking latency, event-loop lag, Redis health, database latency, match-finalization failures, economy mutation failures, provider latency/errors, SSE disconnects, and speech failures.
- Alerts cover sustained readiness failure, Redis/database unavailability, duplicate-finalization attempts, provider error spikes, and balance/claim transaction failures.

### 10.4 Accessibility, language, and privacy

- User-facing MVP copy is Indonesian. Stable identifiers, code, and this PRD are English.
- Authentication, Lobby, Solo/Practice, Learning Dashboard, Assessment-result display, Competition, match controls/results, Store, Hired Pass, and Interview support screen-reader labels, logical focus order, text scaling, and non-color-only status indicators.
- Interactive controls meet a minimum `44×44` logical-pixel target and readable text/contrast requirements.
- Interview text is private to its owner and service roles. Raw speech audio follows Section 7.4 deletion rules.
- Account deletion removes or irreversibly anonymizes user-owned learning and Interview content while retaining only legally/operationally required aggregate or transaction audit data.

### 10.5 Required test suites

- Unit tests for all formulas, evidence classifications, state ordering, confidence fallbacks, transitions, validation, error mapping, and deterministic recommendation ties.
- Database integration tests for migrations, RLS/admin authorization, importer idempotency, attempt uniqueness, backfill fidelity, ledgers, daily/season boundaries, concurrent Solo timeout/answer and Store/Pass/Interview mutations, content deactivation, and match finalization.
- Contract tests for Solo/Learning/compatibility REST, SSE, `/match`, and `/interview-speech` payloads/errors.
- Socket end-to-end tests for two clients, Bot, Casual, Ranked, Private, timeout, surrender, disconnect/reconnect, stale sockets, duplicate commands, and two Game Backend instances.
- Mobile integration tests proving no local-success fallback and correct loading/error/retry states.
- Provider evaluation tests for both Interview modes, five turns, malformed output, fallback, streaming order, cancellation, and speech-to-text degradation.
- Repeatable load tests for the Section 10.1 profile.

### 10.6 Release checklist

A release candidate is rejected unless all items are true:

- compilation, static analysis, unit, integration, contract, E2E, and load tests pass;
- migrations pass from a clean database and the current deployed schema;
- active question coverage, Store catalog, company context, and season manifest validate;
- two physical clients complete Solo/compatible Practice, every match mode, Store/Pass, and every Interview transport in staging;
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
| Misleading learning state | Separate evidence lanes, append-only attempts, transparent denominators/confidence, versioned calculations, and no fabricated backfill data |
| Premature Solo delivery policy | Gate 5 is limited to the approved Balanced + Standard fixed-count policy; versioned contracts and tests prevent deferred adaptive, difficulty, recommendation, repetition, or taxonomy behavior from appearing implicitly |
| Beta currency inflation | Explicit beta banner, separate ledger reason, feature flag, disabled paid packs, and no claim that beta balance represents real-money value |
| Season/reward drift | Checked-in manifest validation, non-overlapping windows, immutable claim snapshots, and deployment failure without an active valid season |
| Client/server divergence | Server authority, shared contract fixtures, no production local fallbacks, and two-client acceptance tests |

---

## 11. Learning System V2 contract

> **Adoption status:** Approved and canonical as of 2026-08-31.
> **Policy version:** `learning-v1` is approved for implementation but remains unvalidated against production outcomes. Threshold or weight changes require a new calculation version.
> **Delivery constraint:** Gates 1–4 may proceed. Gate 5 cannot pass until the decision debt in Section 11.22 is approved. Existing five-question Practice behavior remains the compatibility delivery surface until then.

The following contract is the complete adopted Learning System V2 definition. Numbered references inside this section (for example “Section 7”) refer to its nested Learning V2 subsections.

### 1. Product outcome

YUDHA Learning System V2 turns authoritative learner activity into a transparent, repeatable learning loop:

    Solo, PvP, and Assessment evidence
                    ↓
          validate and classify
                    ↓
       immutable learning attempts
                    ↓
     learner state per user and skill
                    ↓
        one next-best Solo action
                    ↓
    mobile learning dashboard and feedback
                    ↓
          learner completes Solo
                    └──────────────→ repeat

The central product rule is:

> Analytics determines the learner's current state. Recommendation chooses the next Solo learning action. Solo delivers practice. Assessment validates progress independently. PvP remains a separate competition context.

V2 must help the learner answer:

1. What have I covered?
2. What am I improving?
3. What needs attention?
4. What should I do next?
5. Has my progress been independently validated?

V2 must not:

- collapse Solo, PvP, and Assessment into one unexplained score;
- present engagement, rank, or repeated-question success as mastery;
- claim an official exam outcome, hiring outcome, psychological diagnosis, or certification;
- treat one short session as proof of mastery;
- use an LLM to calculate learner state, choose access, or control progression;
- overwrite raw attempts when a formula changes; or
- hardcode five questions as a permanent V2 domain invariant.

#### 1.1 In scope

- Stable skill-level taxonomy contracts.
- Authoritative question metadata and content versioning.
- Solo mechanics: Focus, Standard, and Speed.
- Solo question selection: Balanced, Recommended, and Custom.
- Immutable evidence from Solo, PvP, and future web Assessment.
- Versioned evidence classification, learner state, and recommendations.
- One primary Solo recommendation with an evidence-based explanation.
- Mobile learning and after-session dashboards.
- Mobile display of Assessment results produced on the web.
- Separate Competition analytics.
- An internal admin web dashboard for question-quality review.
- Additive migration from current Practice and Analytics contracts.

#### 1.2 Outside this approved contract or intentionally deferred

- Detailed web Assessment UX, session delivery, and public Assessment APIs.
- The final CPNS/BUMN skill catalog; it remains an SME-owned versioned artifact.
- Adaptive or mastery-based Solo stopping rules beyond the approved initial fixed-count slice.
- Automated machine-learning recommendations, IRT, Elo-style ability estimation, or population benchmarking.
- Automatic question deactivation.
- Shipping behavior outside the approved delivery gates or silently resolving registered decision debt.

---

### 2. Current-to-target change matrix

| Area | Current implementation / approved MVP | Approved V2 target |
|---|---|---|
| Domain name | Practice | Solo in all new public and logical contracts; Practice remains a compatibility alias |
| Topic grain | Target, category, optional subcategory | Target and stable skill ID, with category/subcategory retained for navigation |
| Session choice | Category and subcategory | Independent mechanic and question-selection choices |
| Mechanics | One untimed Practice flow | Focus, Standard, and Speed |
| Question selection | Server-selected category pool | Balanced, Recommended, and Custom |
| Session length | Exactly five questions | Learner selects 20, 35, or 50 questions; no option is preselected in manual setup |
| Hints | Hint content is delivered with the question and client reports use | Hint content is returned only by a server-tracked hint endpoint |
| Timer | No automatic Solo timeout | Focus has no deadline; Standard and effective Speed use server-authoritative deadlines |
| Response time | Client response time is accepted | Server elapsed time is authoritative for timed modes; validated client active time supports Focus |
| Accuracy | Broad answer accuracy | Activity, assisted, independent, and unseen-independent accuracy are separate |
| Pace | Average response time | Median valid effective time and comparable pace ratios |
| Evidence lanes | Practice and Ranked answers may be combined for recommendation | Solo, PvP, and Assessment remain separate evidence lanes |
| Learner state | Weak category/subcategory | Versioned learner state per user × target × skill |
| Recommendation | Practice or Interview based on a 90-day rule list | One Solo learning action selected through ordered objective gates |
| Recommendation evaluation | Not tracked end to end | Shown, accepted, dismissed, started, completed, immediate result, and delayed result |
| Assessment | No learning Assessment activity | Future web evidence source; mobile displays available results only |
| Data foundation | Source operational rows | Append-only canonical learning-attempt ledger plus derived projections |
| Learner dashboard | Aggregate Practice and battle statistics | Coverage, skill state, evidence, pace, retention, Assessment result, activity, and separate Competition |
| Content quality | No complete review workflow | Admin web metrics, triage, resolution, and controlled deactivation |

**Current compatibility:** The existing five-question Practice flow, /practice routes, /analytics route, Practice physical tables, current daily mission keys, and current PvP socket events continue until their consumers pass the migration gates in Section 20.

---

### 3. Canonical terminology and types

#### 3.1 Product terminology

| Term | Meaning |
|---|---|
| **Solo** | The non-PvP learning activity. It is the V2 replacement term for Practice. |
| **Mechanic** | How the learner experiences a Solo question: Focus, Standard, or Speed. |
| **Question selection** | Which content is selected: Balanced, Recommended, or Custom. |
| **Delivery policy** | How long a Solo session continues and why it ends. Its V2 default is unresolved. |
| **Skill** | The lowest stable, SME-approved curriculum unit that can support reliable evidence and recommendation. |
| **Attempt** | One immutable record of an answered or timed-out learning question. |
| **Independent evidence** | Valid first-attempt evidence without a requested hint. |
| **Unseen evidence** | Evidence from a question the learner had not previously encountered. |
| **Assessment** | A future web-based standardized validation activity using held-out or unseen content. |
| **Competition** | PvP rank, match, and performance information, kept separate from the learning dashboard. |
| **Learner state** | Versioned derived Solo status for one user and skill. |
| **Assessment validation** | A separate indication of whether Assessment evidence validates progress. |

#### 3.2 Approved public enums

    type MechanicMode =
      | "focus"
      | "standard"
      | "speed";

    type QuestionSelectionType =
      | "balanced"
      | "recommended"
      | "custom";

    type LearningObjective =
      | "repair_accuracy"
      | "spaced_review"
      | "collect_evidence"
      | "build_fluency"
      | "maintain_coverage";

    type LearningSource =
      | "solo"
      | "pvp"
      | "assessment";

    type EvidenceConfidence =
      | "low"
      | "medium"
      | "high";

    type SoloSkillStatus =
      | "collecting_data"
      | "needs_repair"
      | "developing"
      | "needs_review"
      | "needs_fluency"
      | "secure";

    type AssessmentValidationStatus =
      | "not_available"
      | "insufficient_evidence"
      | "baseline_recorded"
      | "validated"
      | "needs_revalidation";

    type CompletionReason =
      | "policy_completed"
      | "user_stopped"
      | "question_inventory_exhausted"
      | "abandoned";

    type PolicyStopTrigger =
      | "fixed_count_reached"
      | "fixed_duration_reached"
      | "mastery_evidence_reached"
      | "adaptive_condition_reached"
      | "user_continue_ended";

The following delivery-policy values are reserved contract vocabulary, not enabled V2 policies:

    type StoppingRule =
      | "fixed_count"
      | "fixed_duration"
      | "mastery_evidence"
      | "adaptive"
      | "user_continues";

#### 3.3 Compatibility naming

All new V2 documentation, endpoints, payloads, logical entities, analytics fields, and UI copy use **Solo**.

Legacy names remain temporary mappings:

| Legacy | V2 |
|---|---|
| Practice | Solo |
| practice session | Solo session |
| practice answer | Solo attempt source record |
| daily_practice | daily_solo after consumer migration |
| Practice recommendation | Solo recommendation |
| weak topic | skill state with evidence and confidence |

Physical Practice table names may remain during the additive migration. Their presence must not make Practice the V2 public term.

---

### 4. System boundaries and evidence lanes

#### 4.1 Shared pipeline, separate meaning

Solo, PvP, and Assessment write a common canonical attempt shape, but their results are never averaged blindly.

The aggregation grain is:

    user × target × skill × learning source × mechanic

Mechanic is populated only for Solo. It is null for PvP and Assessment.

#### 4.2 Solo evidence

Solo primarily supports:

- daily learner-state calculation;
- understanding and independent accuracy;
- hint dependency;
- pace development;
- spaced-review scheduling;
- recommendation generation; and
- immediate and delayed recommendation evaluation.

#### 4.3 Assessment evidence

Assessment supports:

- baseline and latest validated score;
- held-out or unseen transfer evidence;
- independent validation of progress;
- category or skill-level validation where the Assessment blueprint supports it; and
- readiness language only when sufficient standardized evidence exists.

Assessment is web-based and is not implemented in Mobile. Mobile may display Assessment results returned by the learning API.

Assessment never becomes the primary next-action recommendation in learning-v1. When Assessment evidence exists, its skill gap may be used as a separate signal when ranking Solo repair candidates.

Detailed Assessment delivery, browser security, session APIs, and web UI are outside this approved contract.

#### 4.4 PvP evidence

PvP supports:

- competitive performance;
- Solo-to-PvP context comparison;
- pressure-context observations; and
- separate Competition advice.

PvP does not determine Solo mastery, does not create a weak-topic label, and never becomes the primary next action in learning-v1.

The current public PvP socket events remain unchanged during V2 migration. The Game Backend maps authoritative match results and logs into canonical attempts without requiring a new client event vocabulary.

#### 4.5 Prohibited aggregate

The system must never calculate or display:

    overall accuracy = (Solo + PvP + Assessment) / 3

Each cross-context comparison must expose both underlying metrics, their sample sizes, and their confidence.

---

### 5. Skill taxonomy and question authority

#### 5.1 Taxonomy contract

The actual CPNS and BUMN skill tree belongs in a versioned, SME-approved content artifact. This document defines the contract that artifact must satisfy.

Each taxonomy release must include:

- schema version;
- content version;
- approval status;
- SME approval state and approver identity or reference;
- target IDs;
- category IDs;
- subcategory IDs;
- stable skill IDs;
- localized labels;
- enabled/disabled state and reason;
- curriculum weight;
- optional prerequisite skill IDs; and
- effective date or release reference.

A stable skill ID must not be reused for a different learning concept. A renamed skill keeps its ID. A materially changed concept receives a new ID or explicit taxonomy migration.

Example hierarchy:

    cpns
    └── tiu
        └── numerik
            └── percentage
                ├── percentage-increase
                ├── percentage-decrease
                └── reverse-percentage

Recommendations target the lowest level that has sufficient, reliable question inventory and evidence. If a leaf skill lacks reliable evidence, aggregation may roll up only through an explicit taxonomy relationship; the service must not infer relationships from labels.

#### 5.2 Required question metadata

Every active learning question must have authoritative server-side metadata:

- stable question ID;
- source key;
- question revision/version;
- bank content version;
- target;
- category;
- optional subcategory;
- primary skill ID;
- optional prerequisite skill IDs;
- difficulty;
- question type;
- expected time when calibrated;
- Standard time limit;
- curriculum weight;
- Assessment eligibility;
- correct answer and explanation;
- optional hint;
- quality/calibration status;
- active state; and
- SME approval state.

The client must not submit target, category, skill, difficulty, version, expected time, curriculum weight, Assessment eligibility, correctness, score, or explanation as authoritative values.

#### 5.3 Question versioning and snapshots

- Editing wording, options, answer, explanation, skill mapping, difficulty, or timing creates a new question revision.
- A Solo, PvP, or Assessment session snapshots the question revision and learning metadata it uses.
- The canonical attempt stores that snapshot reference so later content changes do not rewrite history.
- Derived analytics may exclude a revision that is later invalidated, but the raw attempt remains.
- A correction or invalidation must be auditable and trigger recalculation of affected learner state and quality metrics.

#### 5.4 Safe question payload

Before resolution, the client may receive prompt, options, navigation metadata, timing policy, hint availability, and safe taxonomy labels.

Before resolution, the client must not receive:

- correct option;
- correctness;
- explanation;
- hint content before the hint endpoint is accepted;
- mastery or state result; or
- hidden Assessment blueprint answers.

---

### 6. Learner preferences

V2 adds a minimal learner-preference record. Preferences personalize delivery but do not override evidence safety.

    {
      "preferredMechanicMode": "focus",
      "preferredQuestionSelection": "recommended",
      "timedPracticeEnabled": true
    }

All fields are optional.

- Missing preferences use server policy defaults.
- A preferred mechanic is a preference, not a mastery claim.
- The recommendation engine may recommend Focus when accuracy is low even if Speed is preferred.
- A learner may manually choose Speed below the recommendation threshold, subject to the warning rules in Section 7.
- Exam date, weekly availability, self-reported weaknesses, and competition opt-in are deferred.

---

### 7. Solo experience

Solo configuration has three independent decisions:

1. **Learning objective** — why the session is being recommended.
2. **Mechanic mode** — how the learner answers.
3. **Question selection** — which questions the learner receives.
4. **Delivery policy** — how long the session continues.

The recommendation engine chooses the first three for the primary action. Delivery remains a separately versioned policy.

#### 7.1 Default mobile structure

    Solo
    ├── Recommended Session
    │   └── objective + mechanic + question selection
    └── Customize
        ├── Mechanic: Focus | Standard | Speed
        └── Questions: Balanced | Recommended | Custom

The default screen should not require the learner to configure both axes before every session.

Indonesian example:

> **Sesi yang direkomendasikan**<br>
> Focus · Kenaikan Persentase<br>
> Akurasi mandiri kamu 5 dari 9. Latihan dilakukan tanpa batas waktu agar kamu dapat fokus pada pemahaman.

#### 7.2 Focus

- No visible countdown.
- No automatic question timeout.
- Active response time is recorded silently.
- Hints and post-answer explanations are available.
- Primary decision metric: unseen independent accuracy.
- Recommended when accuracy or evidence confidence is low.
- Animations, content transitions, card selection, background time, and known disconnect time are excluded from valid pace evidence.

#### 7.3 Standard

- Uses the authoritative Standard time limit from the question revision.
- Shows a visible countdown.
- The server owns opened time, deadline, and timeout resolution.
- Hints and post-answer explanations are available.
- Requesting a hint does not pause the timer.
- Primary metrics: accuracy, timeout rate, and completion within the Standard limit.

#### 7.4 Speed

- Uses a personal pace target when enough comparable baseline evidence exists.
- Shows a visible countdown and uses reduced non-learning transition time.
- Hints and post-answer explanations remain available.
- Requesting a hint does not pause the timer.
- A hinted attempt is assisted evidence and is excluded from independent proficiency and fluency-baseline calculation.
- The recommendation engine may recommend Speed only when smoothed unseen independent accuracy is at least 85%, at least five valid comparable pace attempts exist, and the skill pace ratio is above 1.20.

**Proposed learning-v1 personal baseline:**

1. Select the latest ten valid, answered, no-hint, first-attempt Solo observations for the same skill and difficulty.
2. Require at least five observations.
3. Calculate their median effective response time.
4. Set the Speed deadline to 90% of that median, bounded so it never exceeds the authoritative Standard limit.
5. Snapshot the baseline, sample size, and mechanic-policy version in the session.

When a learner manually requests Speed without enough baseline evidence:

- resolve the effective mechanic to Standard;
- return an Indonesian warning;
- label the session as baseline collection;
- do not classify its attempts as Speed evidence.

Example warning:

> Data kecepatanmu belum cukup. Sesi ini menggunakan waktu Standard untuk membangun baseline sebelum latihan Speed dipersonalisasi.

When a learner manually requests Speed below the 85% accuracy gate:

- preserve learner control;
- return a warning that Focus is recommended first;
- never represent the choice as a system recommendation; and
- continue to classify hinted or repeated attempts honestly.

Example warning:

> Kami menyarankan Focus terlebih dahulu. Latihan Speed dapat memperkuat tebakan saat akurasi mandirimu masih berkembang.

#### 7.5 Question-selection methods

**Balanced**

- Follows the SME-approved curriculum distribution.
- Prevents learners from selecting only familiar skills.
- Supports broad evidence collection and coverage maintenance.
- Must use stable curriculum weights, not equal random category selection.
- The initial CPNS content policy is temporarily two-category because the checked-in bank has no TKP inventory: TWK : TIU uses `6 : 7`. For 20, 35, and 50 questions, deterministic largest-remainder allocation produces `9 : 11`, `16 : 19`, and `23 : 27` respectively.
- The initial BUMN content policy uses TKD : AKHLAK = `3 : 1`. For 20, 35, and 50 questions, allocation produces `15 : 5`, `26 : 9`, and `38 : 12` respectively.
- These weights are versioned delivery content policy, not a replacement for the final SME-approved taxonomy. CPNS must add TKP through a later policy version once active TKP inventory exists and is approved.
- A session contains no duplicate question. If one category cannot satisfy its quota, the server deterministically redistributes the deficit across eligible categories. If total unique active inventory still cannot satisfy the selected count, session creation fails with an insufficient-inventory response and suggests a smaller supported count.

**Recommended**

- Selects skills from learner state and the current objective.
- May target low accuracy, due review, missing evidence, slow but accurate performance, or an explicit prerequisite.
- Must not be labeled “Weak Topic” when evidence is insufficient.

**Custom**

- Lets the learner select one or more stable skill IDs.
- May present category/subcategory navigation, but sends stable skill IDs to the server.
- Does not convert a learner-selected skill into a system recommendation.
- Server validation rejects unknown, disabled, cross-target, or unavailable skills.

#### 7.6 The 3 × 3 structure

| Mechanic | Balanced | Recommended | Custom |
|---|---|---|---|
| Focus | Calm broad evidence | Accuracy repair | Untimed learner-selected skills |
| Standard | Normal curriculum application | Consolidation or spaced review | Timed learner-selected skills |
| Speed | Broad fluency challenge when eligible | Accurate but slow skills | Learner-selected pace training |

Not every combination needs equal prominence. The primary recommendation returns one best combination; customization preserves learner control.

#### 7.7 Question opening

The client calls the question-open operation after the question is fully rendered and before answer controls become active.

The server records:

- opened timestamp;
- requested and effective mechanic;
- timer visibility;
- time limit;
- deadline;
- session question identity; and
- open-operation idempotency key.

An answer is rejected until the question has been opened. A repeated open request with the same idempotency key returns the original result and never restarts a timer.

Solo timing is learning evidence, not a high-stakes anti-cheat guarantee. Assessment owns stricter independent validation. Solo anomaly checks must still reject impossible or inconsistent timing evidence.

#### 7.8 Hint request

Hint content is returned only after a server-accepted hint request.

- The operation is idempotent.
- The server records requested time.
- Repeated retrieval does not create multiple hint events.
- Hint usage has no score penalty.
- Hint usage changes evidence classification from independent to assisted.
- The timer continues in Standard and effective Speed.

#### 7.9 Server-authoritative timeout

For Standard and effective Speed:

- the deadline is server-owned;
- reaching the deadline creates one unanswered, incorrect, timed-out attempt;
- the timeout and a concurrently arriving answer compete through one atomic resolution guard;
- whichever authoritative resolution commits first wins;
- the losing operation returns the committed result and creates no second attempt; and
- a client timeout call is reconciliation only, not the source of truth.

Focus never produces an automatic timeout.

#### 7.10 Session completion and product rewards

The initial Solo delivery policy uses the learner-selected fixed count of `20`, `35`, or `50` questions. Manual setup has no default count. A session normally completes after all selected questions resolve; the learner may stop early through an explicit confirmation.

The tower has a normalized maximum of `100` HP. Tower HP is derived from committed results rather than accumulated rounded damage:

    remainingTowerHp = ceil(100 * (questionCount - correctCount) / questionCount)

A correct answer animates the selected character attacking the tower. A wrong answer or timeout leaves tower HP unchanged and uses the character's existing `hit` reaction. The learner has no HP bar. The result presentation distinguishes:

- `tower_destroyed`: all selected questions resolved correctly and tower HP reached zero;
- `questions_completed`: all selected questions resolved but tower HP remains; and
- `user_stopped`: the learner confirmed an early stop and receives a partial result.

Only completion reason **policy_completed** qualifies for:

- Daily Solo mission progress;
- streak activity;
- Hired Pass learning activity;
- a normal completed-session result; and
- the result-exit ad safe break defined by the approved PRD after adoption.

For the initial fixed-count policy, both `tower_destroyed` and `questions_completed` map to completion reason `policy_completed`, with the visible result stored as `policyStopTrigger`. `user_stopped`, inventory-exhausted, and abandoned outcomes do not qualify. Early-stop attempts remain valid learning evidence, but early stop grants no direct Y-Coin, mission, streak, or Hired Pass progression.

The direct Solo result reward is idempotent and never changes competitive rank: `tower_destroyed` grants `10` Y-Coin, `questions_completed` grants `3`, and `user_stopped` grants `0`, subject to a `30` Y-Coin Solo cap per WIB business date.

**Current compatibility:** The current five-question Practice flow continues to use the approved PRD completion and reward behavior until V2 delivery is approved and migrated.

---

### 8. Delivery-policy contract and decision debt

The analytics foundation operates per attempt and does not require a fixed session length.

V2 represents initial Solo delivery through a policy object:

    {
      "policyId": "solo-fixed-count-v1",
      "policyVersion": 1,
      "stoppingRule": "fixed_count",
      "minimumQuestions": 20,
      "maximumQuestions": 50,
      "resolvedQuestionCount": 20,
      "resolvedDurationMinutes": null
    }

`resolvedQuestionCount` is the learner's explicit choice from `20`, `35`, or `50`; there is no manual default.

Every session must snapshot:

- delivery policy ID and version;
- stopping rule;
- any minimum/maximum bounds;
- any resolved count or duration;
- policy inputs relevant to audit;
- completion reason; and
- policy stop trigger when the policy completed; and
- whether the result qualifies as policy completion.

The initial slice approves fixed-count delivery, no within-session duplicates, the target-specific Balanced allocations in Section 7.5, deterministic insufficient-inventory handling, explicit early stopping, and resumable unfinished sessions. Standard deadlines continue while the app is backgrounded; returning to a session reconciles any elapsed deadline with the server.

Difficulty progression, adaptive/mastery stopping, intentional cross-session repetition policy, final CPNS/BUMN taxonomy weights, and Speed personalization remain deferred. They do not block the initial Balanced + Standard delivery slice.

---

### 9. Canonical learning-attempt ledger

#### 9.1 Authority

The authoritative analytical evidence layer is an append-only learning_attempts table.

Solo, PvP, and Assessment may retain separate operational storage, but every accepted result must map exactly once into the canonical ledger. Derived analytics read the canonical ledger, not an ad hoc union assembled differently by each endpoint.

Raw ledger rows are immutable except for privacy-required anonymization. Corrections are represented through auditable correction/invalidation records and new derived classifications.

#### 9.2 Exactly-once source identities

Each source must provide a unique source-attempt key:

| Source | Required uniqueness |
|---|---|
| Solo | Solo answer/source row ID |
| PvP | match ID + card instance ID + learner ID |
| Assessment | Assessment session item ID + learner ID |

The database enforces uniqueness on learning source plus source-attempt key.

- Replaying identical ingestion returns the existing attempt.
- Reusing a key for different source data fails with an idempotency conflict.
- A timed-out question and an answer cannot create separate attempts for one source item.
- A source transaction must commit its operational outcome and canonical ingestion atomically where practical.
- Where cross-service atomicity is impossible, the source uses a durable outbox and idempotent consumer.

#### 9.3 Canonical attempt shape

    {
      "attemptId": "attempt_01JY7D71",
      "source": "solo",
      "sourceAttemptKey": "solo-answer-01JY7D71",
      "dataFidelity": "v2_complete",
      "userId": "user_123",
      "target": "cpns",
      "sessionId": "solo_01JY7CE4",
      "recommendationId": "rec_01JY7A2M",
      "learningObjective": "repair_accuracy",
      "requestedMechanicMode": "focus",
      "effectiveMechanicMode": "focus",
      "questionSelectionType": "recommended",
      "deliveryPolicyId": null,
      "questionId": "q_901",
      "questionVersion": 3,
      "contentVersion": "cpns-2026-08",
      "skillId": "cpns.tiu.numerik.percentage-increase",
      "difficulty": "medium",
      "selectedOptionIndex": 2,
      "isCorrect": true,
      "hintRequested": false,
      "timedOut": false,
      "firstAttempt": true,
      "seenBefore": false,
      "exposureCountBefore": 0,
      "openedAt": "2026-08-31T09:04:10.000Z",
      "answeredAt": "2026-08-31T09:04:29.000Z",
      "clientActiveResponseTimeMs": 18420,
      "serverElapsedTimeMs": 19110,
      "backgroundDurationMs": 0,
      "effectiveResponseTimeMs": 18420,
      "validForAccuracy": true,
      "validForPaceAnalytics": true,
      "validForFluencyBaseline": true,
      "classificationVersion": "evidence-v1",
      "calculationVersion": "learning-v1"
    }

The physical schema may normalize snapshots or use typed columns rather than one JSON document. The behavioral fields and provenance must remain queryable.

#### 9.4 Required attempt dimensions

**Identity and provenance**

- attempt, user, session, source, source-attempt key;
- recommendation ID when applicable;
- ingestion time and source event time;
- data-fidelity level;
- evidence-classification version; and
- calculation version used for any stored derived snapshot.

**Activity context**

- learning objective for Solo;
- requested and effective mechanic for Solo;
- question-selection type for Solo;
- delivery-policy reference when available;
- Assessment blueprint/version for Assessment;
- match/mode reference for PvP; and
- session completion state.

**Question snapshot**

- question ID and revision;
- content version;
- target, category, subcategory, and skill;
- difficulty;
- expected-time/calibration reference;
- Standard time limit;
- curriculum weight; and
- question quality state at presentation.

**Learner action**

- selected option or null timeout;
- server-derived correctness;
- hint request;
- timeout;
- first-attempt/retry state;
- previous exposure state and count;
- optional perceived difficulty;
- explanation-viewed state when captured; and
- abandonment context when relevant.

**Timing**

- opened, answered, and deadline timestamps;
- client active time;
- server elapsed time;
- background/inactive duration;
- effective time;
- pace-validity flags; and
- explicit invalidity reason.

#### 9.5 Legacy backfill

Legacy data must be backfilled without inventing evidence.

Allowed fidelity examples:

- v2_complete — all required V2 fields captured authoritatively;
- legacy_solo — legacy Practice answer with known correctness and limited timing/hint trust;
- legacy_pvp — persisted match log with known result but incomplete exposure or timing context;
- assessment_import — future Assessment result ingested through an approved adapter.

For missing historical fields:

- store null or an explicit unknown value;
- set data-fidelity and exclusion reasons;
- do not infer unseen status from a missing history table;
- do not convert client usedHint into authoritative hint evidence without a server event;
- do not claim question revision when it was not captured;
- do not treat missing background time as zero; and
- do not include lower-fidelity observations in metrics whose eligibility cannot be proven.

Legacy evidence may still support transparent broad activity counts where its correctness and ownership are reliable.

#### 9.6 Corrections, invalid questions, and privacy

- Question invalidation never deletes the raw attempt solely to improve a metric.
- Derived state excludes invalidated question revisions from the next calculation and records the exclusion reason.
- Admin deactivation affects future selection; invalidation controls analytical eligibility.
- Recalculation identifies the affected users and skills rather than rebuilding every learner synchronously.
- Account deletion follows the approved PRD privacy rule: delete or irreversibly anonymize user-owned learning evidence while retaining only permitted aggregate or operational audit data.
- Operational logs must not expose unrevealed answers, access tokens, or unnecessary personal data.

---

### 10. Evidence classification

Classification runs before aggregation. One attempt may qualify for broad activity accuracy while being excluded from independent or pace metrics.

#### 10.1 Valid accuracy evidence

An attempt is valid for activity accuracy only when:

- an answer or authoritative timeout was recorded;
- source ownership and session legitimacy are valid;
- the question ID and captured revision are known;
- the source item was not duplicated;
- the question revision is not analytically invalidated; and
- server-derived correctness is available.

#### 10.2 First-attempt evidence

A first attempt is the first authoritative resolution of one presented session question.

- Network retries do not create additional attempts.
- Future deliberate retries must receive a distinct source item and attempt ordinal.
- A retry is learning activity but is not first-attempt proficiency evidence.

#### 10.3 Independent evidence

An attempt is independent when:

    valid accuracy evidence
    AND firstAttempt = true
    AND hintRequested = false

An unseen independent attempt additionally requires:

    seenBefore = false

Unseen independent Solo attempts are the primary proficiency evidence used for Solo learner state.

#### 10.4 Assisted evidence

When hintRequested is true:

- the attempt counts toward broad activity accuracy;
- the attempt counts toward assisted accuracy;
- the attempt does not count toward independent or unseen-independent accuracy;
- the attempt does not enter a fluency baseline; and
- the result must not increase independent proficiency.

#### 10.5 Repeated-question evidence

When seenBefore is true:

- the attempt may count for activity, practice, and reinforcement;
- the attempt is excluded from unseen-independent accuracy;
- the attempt does not by itself validate retention;
- the exposure count remains available to the dashboard and quality analysis; and
- exact repetition must be intentional under the future delivery policy.

#### 10.6 Pace evidence

**Focus**

Focus uses client active time only when it is plausibly consistent with server elapsed time.

    difference =
      absolute(client active time − server elapsed time)

Focus is valid for broad pace analytics when:

    background duration = 0
    AND known disconnect duration = 0
    AND difference <= maximum(2,000 ms, 15% of server elapsed time)

Otherwise the answer remains eligible for accuracy but validForPaceAnalytics is false.

**Standard and effective Speed**

The server controls the deadline.

    effective response time =
      minimum(server elapsed time, authoritative time limit)

A timed-out attempt may count as capped mode-pace evidence and always counts toward timeout rate. It does not enter the personal fluency baseline.

An attempt is excluded from the personal fluency baseline when it is:

- hinted;
- repeated;
- a retry;
- timed out;
- backgrounded;
- affected by a known disconnect or technical interruption; or
- missing a comparable skill/difficulty identity.

#### 10.7 Retention evidence

Retention evidence must:

- occur after a scheduled delay;
- use a different, equivalent question;
- be unseen before the review;
- be a first attempt;
- be independent; and
- use a valid question revision.

Exact-question repetition is not strong retention evidence.

**Proposed learning-v1 policy:** The first delayed review becomes due seven days after strong, fresh Solo evidence.

#### 10.8 Assessment evidence

Assessment evidence must identify:

- the Assessment session and blueprint version;
- standardized timing policy;
- held-out or unseen eligibility;
- absence of hints and explanations before resolution;
- skill/category mapping supported by the blueprint; and
- official or approved score calculation.

Assessment evidence remains separate even when it contributes an Assessment-gap signal to Solo recommendation ranking.

---

### 11. Aggregation windows and learner-state grain

#### 11.1 Time scopes

| Purpose | Scope |
|---|---|
| Current Solo skill state | Latest 20 eligible unseen independent Solo attempts per user × target × skill |
| Learning trend | Latest 10 versus previous 10 from that state block |
| Dashboard activity | Rolling 30 days |
| Exposure history | Lifetime |
| Assessment progress | Assessment history, baseline, and latest valid result |
| Retention | Delayed equivalent attempts and due schedule |
| Recommendation history | Active and recent recommendation/event history |
| Content quality | Configurable reporting window with sample sizes |

The 30-day dashboard window must not erase old learning history or make lifetime exposure appear unseen.

#### 11.2 Comparable blocks

State and trends compare evidence with the same:

- user and target;
- skill;
- learning source;
- proficiency evidence class;
- and, where pace is involved, mechanic and difficulty.

The service must not compare an assisted repeated Focus block directly with unseen independent Standard evidence and call the difference learning progress.

#### 11.3 Recalculation boundaries

An accepted attempt identifies its affected user, target, skill, source, and mechanic. Recalculation updates only affected projections, plus any recommendation or coverage summary depending on them.

---

### 12. Proposed learning-v1 metrics

Every user-facing percentage must include:

- numerator/correct count where applicable;
- denominator/eligible attempt count;
- unique question count;
- evidence confidence;
- evidence window or as-of time; and
- null rather than zero when the metric has no eligible evidence.

#### 12.1 Activity accuracy

    activity accuracy % =
      correct valid attempts
      ÷ all valid attempts
      × 100

This is descriptive activity, not mastery.

#### 12.2 Independent accuracy

    independent accuracy % =
      correct valid no-hint first attempts
      ÷ all valid no-hint first attempts
      × 100

#### 12.3 Unseen-independent accuracy

    unseen-independent accuracy % =
      correct valid unseen no-hint first attempts
      ÷ all valid unseen no-hint first attempts
      × 100

This is the raw user-facing proficiency metric used alongside sample size.

#### 12.4 Assisted accuracy

    assisted accuracy % =
      correct valid hint-assisted attempts
      ÷ all valid hint-assisted attempts
      × 100

#### 12.5 Hint rate

    hint rate % =
      Solo attempts with a server-accepted hint request
      ÷ all hint-eligible valid Solo attempts
      × 100

#### 12.6 Independence gap

    independence gap =
      assisted accuracy − independent accuracy

A positive gap is described as assistance dependency evidence, not as a psychological cause.

#### 12.7 Smoothed proficiency accuracy

    smoothed accuracy % =
      (correct unseen-independent attempts + 2)
      ÷ (unseen-independent attempts + 4)
      × 100

The +2/+4 neutral prior is a proposed, unvalidated learning-v1 policy.

Example:

    5 correct from 9 unseen-independent attempts

    raw accuracy      = 5 / 9 = 55.56%
    smoothed accuracy = 7 / 13 = 53.85%

Raw accuracy is shown to learners. Smoothed accuracy supports state and recommendation decisions.

#### 12.8 Evidence confidence

Confidence is evaluated in order so every evidence set has exactly one result.

**High**

    eligible attempts >= 15
    AND unique questions >= 8
    AND difficulty levels represented >= 2
    AND latest eligible evidence <= 14 days old

**Medium**

    not High
    AND eligible attempts >= 5
    AND unique questions >= 3
    AND latest eligible evidence <= 30 days old

**Low**

    every evidence set that is neither High nor Medium

Low confidence displays:

> Data masih dikumpulkan.

It must not display:

> Topik ini lemah.

#### 12.9 Median response time

    median response time =
      median of valid effective response times

Median replaces average because interruptions and long-tail timing distort a mean.

#### 12.10 Pace ratio

When a calibrated expected time exists:

    attempt pace ratio =
      effective response time
      ÷ calibrated expected time

    skill pace ratio =
      median of comparable attempt pace ratios

Interpretation:

- 0.80 is approximately 20% faster than expected.
- 1.00 is around expected.
- 1.30 is approximately 30% slower than expected.

Until expected times are calibrated, the system uses a personal comparable baseline and labels the result as personal pace rather than a population benchmark.

#### 12.11 Timeout rate

    timeout rate % =
      authoritative timed-out questions
      ÷ all valid Standard and effective-Speed questions
      × 100

Focus has no timeout rate.

#### 12.12 Retention

    retention % =
      correct delayed unseen independent attempts
      ÷ all delayed unseen independent attempts
      × 100

**Proposed learning-v1 concern threshold:** retention below 75%.

#### 12.13 Learning trend

    accuracy trend =
      raw unseen-independent accuracy of latest 10
      − raw unseen-independent accuracy of previous 10

Trend is null until both blocks contain ten eligible attempts. Trend is expressed in percentage points.

#### 12.14 Curriculum coverage

    coverage % =
      required enabled skills with sufficient evidence
      ÷ all required enabled skills
      × 100

**Proposed learning-v1 sufficient coverage:** at least three unique eligible questions for a skill.

One attempt does not count as coverage.

#### 12.15 Assessment score and improvement

Assessment follows its approved blueprint. Where a simple score is valid:

    Assessment score % =
      correct valid Assessment items
      ÷ all valid Assessment items
      × 100

Where categories are weighted:

    weighted Assessment score =
      sum(category score × blueprint weight)
      ÷ sum(blueprint weights)

    Assessment improvement =
      latest valid Assessment score
      − baseline valid Assessment score

Mobile must not display readiness or validated improvement without valid Assessment evidence.

#### 12.16 Context gaps

    timed application gap =
      Focus unseen-independent accuracy
      − Standard unseen-independent accuracy

    Speed gap =
      Standard unseen-independent accuracy
      − Speed unseen-independent accuracy

    Competition gap =
      Solo Standard unseen-independent accuracy
      − PvP accuracy

    Assessment transfer gap =
      Solo unseen-independent accuracy
      − Assessment accuracy

Each gap is shown only when both sides meet their own minimum evidence rule. Both metrics and sample sizes remain visible.

#### 12.17 Activity and consistency

The dashboard may show:

- active learning days;
- questions answered;
- active learning minutes;
- current streak; and
- recent sessions.

These are engagement indicators, not proficiency evidence.

---

### 13. Solo learner state and Assessment validation

#### 13.1 Ordered Solo state

The following proposed learning-v1 rules are evaluated in order for each user × target × skill:

1. **collecting_data**
   - fewer than five eligible unseen independent attempts; or
   - fewer than three unique eligible questions.
2. **needs_repair**
   - smoothed unseen-independent accuracy below 70%.
3. **developing**
   - smoothed unseen-independent accuracy from 70% inclusive to below 85%.
4. **needs_review**
   - accuracy previously reached at least 85%; and
   - the seven-day review is due, retention is below 75%, or the latest strong evidence is older than 30 days.
5. **needs_fluency**
   - smoothed unseen-independent accuracy is at least 85%;
   - at least five valid comparable pace attempts exist; and
   - calibrated or personal comparable pace ratio is above 1.20.
6. **secure**
   - smoothed unseen-independent accuracy is at least 85%;
   - evidence confidence is Medium or High;
   - no review condition is due; and
   - no eligible fluency concern is present.

A skill may be secure from strong Solo evidence without Assessment. This status means secure in Solo evidence, not independently validated exam readiness.

#### 13.2 Separate Assessment validation

Assessment validation is not encoded inside SoloSkillStatus.

| Validation state | Meaning |
|---|---|
| not_available | No approved Assessment source/result is available |
| insufficient_evidence | Assessment exists but cannot support a stable claim |
| baseline_recorded | A valid baseline exists without a comparable later result |
| validated | Valid latest evidence supports the approved validation rule |
| needs_revalidation | Previous validation is stale or later valid evidence no longer supports it |

The exact web Assessment validation rule is owned by its future approved blueprint.

#### 13.3 Evidence-based language

Allowed:

- “Your independent accuracy is 5 of 9.”
- “Your performance drops in timed Solo sessions.”
- “You are accurate, but your current pace is slower than your baseline.”
- “Assessment has not yet validated this progress.”

Not allowed:

- “You are anxious.”
- “You will pass the exam.”
- “This topic is mastered” based on one short session.
- “Your overall learning score is 82” without a transparent multi-metric definition.

---

### 14. Solo recommendation engine

#### 14.1 Output boundary

The primary recommendation always describes one Solo action.

It answers:

1. What learning objective?
2. Which skill?
3. Which mechanic?
4. Which question-selection method?
5. Why?
6. With what evidence and confidence?

Assessment and PvP never become the primary action. Interview recommendations belong to a separate feature track.

#### 14.2 Recalculation triggers

Recalculate the current recommendation when:

- a Solo session completes;
- affected learner state changes after a canonical attempt;
- a seven-day review becomes due;
- valid Assessment evidence changes a skill gap;
- the current recommendation expires;
- a question invalidation removes material evidence; or
- an admin content action makes the planned inventory unavailable.

PvP may update Competition comparison but does not promote PvP to the primary action.

#### 14.3 Inputs

- minimal learner preferences;
- current Solo learner states;
- separate Assessment skill evidence when available;
- current review schedule;
- curriculum weights and prerequisites;
- available active question inventory;
- recent recommendation history;
- recent skill and question exposure;
- question-quality state; and
- calculation and policy versions.

#### 14.4 Ordered objective gates

The engine selects the first objective with at least one valid candidate:

1. **repair_accuracy**
   - at least one skill is needs_repair.
   - mechanic: Focus.
   - question selection: Recommended.
2. **spaced_review**
   - no repair candidate exists; and
   - at least one skill is needs_review or has a due review.
   - mechanic: Standard.
   - question selection: Recommended.
3. **collect_evidence**
   - no repair or due-review candidate exists; and
   - at least one required skill is collecting_data or below coverage.
   - mechanic: Standard, or Focus when timed practice is disabled.
   - question selection: Balanced or Recommended according to the missing-evidence scope.
4. **build_fluency**
   - no earlier candidate exists; and
   - at least one skill is needs_fluency.
   - mechanic: Speed.
   - question selection: Recommended.
5. **maintain_coverage**
   - used when no earlier objective is eligible.
   - mechanic: Standard unless a supported preference applies.
   - question selection: Balanced.

The system ranks skills only within the winning objective. Scores from different objective formulas are not compared as if they shared the same meaning.

#### 14.5 Normalized components

All components are clamped to 0 through 1.

    accuracy gap =
      clamp((85 − smoothed accuracy) / 85, 0, 1)

    Assessment gap =
      1 − Assessment accuracy as a decimal

    hint dependency =
      hint rate as a decimal

    retention risk =
      1 − retention accuracy as a decimal

When retention evidence is missing:

    retention risk =
      minimum(days since last strong result / 7, 1)

    pace gap =
      clamp(pace ratio − 1, 0, 1)

    uncertainty =
      1 − minimum(eligible attempts / 15, 1)

    curriculum importance =
      skill curriculum weight
      ÷ maximum enabled skill curriculum weight

    repetition penalty =
      minimum(skill attempts in last 24 hours / 5, 1)

#### 14.6 Repair ranking

    repair priority =
      0.40 × accuracy gap
      + 0.25 × Assessment gap
      + 0.15 × hint dependency
      + 0.20 × curriculum importance
      − 0.20 × repetition penalty

Assessment gap is included only when valid Assessment evidence exists for the same skill. When a positive component is unavailable, its positive weights are proportionally redistributed across available positive components before the penalty is applied.

Assessment and Solo accuracy remain separate input metrics; they are not averaged into a mastery score.

#### 14.7 Review ranking

    review priority =
      0.50 × retention risk
      + 0.25 × curriculum importance
      + 0.15 × uncertainty
      − 0.20 × repetition penalty

#### 14.8 Fluency ranking

Fluency candidates must already pass the 85% accuracy and five-pace-attempt gates.

    fluency priority =
      0.60 × pace gap
      + 0.25 × curriculum importance
      + 0.15 × timeout rate
      − 0.20 × repetition penalty

#### 14.9 Evidence and coverage ranking

For collect_evidence:

1. fewer eligible attempts;
2. fewer unique questions;
3. higher curriculum importance;
4. fewer attempts in the last 24 hours;
5. older last-practiced time; and
6. ascending stable skill ID.

For maintain_coverage:

1. overdue review state;
2. older last-practiced time;
3. higher curriculum importance;
4. fewer recent attempts; and
5. ascending stable skill ID.

These rules avoid inventing a cross-objective global score and keep ties deterministic.

#### 14.10 Candidate filtering

Before selection:

- remove candidates without sufficient valid active inventory;
- remove Speed candidates that fail accuracy or pace-evidence gates;
- remove invalidated or disabled skills/questions;
- apply recent-skill repetition penalties;
- validate target and taxonomy version;
- ensure any prerequisite relation is explicit; and
- ensure the proposed combination is supported by an approved mechanic and delivery policy.

**Decision debt:** Final behavior for insufficient inventory and within-session question distribution remains unresolved.

#### 14.11 Recommendation response

    {
      "recommendationId": "rec_01JY7A2M",
      "generatedAt": "2026-08-31T09:00:00.000Z",
      "expiresAt": "2026-09-01T09:00:00.000Z",
      "calculationVersion": "learning-v1",
      "objective": "repair_accuracy",
      "mechanicMode": "focus",
      "questionSelection": {
        "type": "recommended",
        "skillIds": [
          "cpns.tiu.numerik.percentage-increase"
        ],
        "skillLabels": [
          "Kenaikan Persentase"
        ]
      },
      "deliveryPolicyId": null,
      "availability": {
        "runnable": false,
        "reason": "delivery_policy_unresolved"
      },
      "reason": {
        "headline": "Perkuat Kenaikan Persentase",
        "description": "Akurasi mandiri kamu masih 5 dari 9. Focus direkomendasikan agar kamu dapat memperbaiki pemahaman tanpa batas waktu.",
        "evidence": [
          {
            "metric": "unseenIndependentAccuracy",
            "value": 55.56,
            "correctCount": 5,
            "attemptCount": 9,
            "uniqueQuestionCount": 6,
            "confidence": "medium"
          }
        ]
      }
    }

When an approved delivery policy exists, deliveryPolicyId is required and availability.runnable is true. During compatibility migration, a legacy fixed-five adapter may make a current Practice action runnable, but it must be labeled compatibility behavior rather than the V2 delivery default.

#### 14.12 Recommendation events

Track:

- shown;
- accepted;
- dismissed;
- session_started;
- session_completed;
- immediate_result_attached; and
- delayed_result_attached.

Shown, accepted, and dismissed may originate from the client. Session-started and session-completed are normally authoritative server events.

Dismissal reasons may include:

- prefer_another_skill;
- too_difficult;
- too_easy;
- not_enough_time;
- do_not_like_timed_mode; and
- other.

Dismissal changes product feedback data, not the learner's proficiency.

#### 14.13 Recommendation effectiveness

    acceptance rate =
      accepted recommendations
      ÷ shown recommendations

    completion rate =
      completed recommended sessions
      ÷ started recommended sessions

    immediate change =
      post-session unseen-independent accuracy
      − pre-session unseen-independent accuracy

    delayed lift =
      delayed unseen-independent accuracy
      − pre-recommendation unseen-independent accuracy

Delayed lift is stronger than immediate change but remains observational. Causal claims require controlled experiments.

---

### 15. User-facing outputs

#### 15.1 Home next action

Home shows one primary Solo action:

- objective;
- mechanic;
- target skill;
- question-selection type;
- evidence-based reason;
- sample size and confidence;
- estimated duration only when an approved delivery policy can provide one;
- availability/runnable state; and
- one start action plus a Customize alternative.

Home does not lead with leaderboard rank.

#### 15.2 Learning dashboard

The mobile dashboard answers the five questions in Section 1 through:

1. **Next Solo action**
2. **Learning summary**
   - curriculum coverage;
   - unseen-independent Solo accuracy;
   - learning trend when available;
   - current pace compared with an appropriate baseline;
   - evidence confidence.
3. **Skill map**
   - skill label;
   - Solo status;
   - raw unseen-independent accuracy and counts;
   - median comparable pace;
   - confidence;
   - last practiced time;
   - recommended mechanic.
4. **Retention**
   - due review state;
   - delayed evidence count and result;
   - next review time.
5. **Assessment result**
   - validation state;
   - baseline and latest score when available;
   - change in percentage points;
   - date and supported category/skill breakdown.
6. **Activity**
   - active days;
   - answered questions;
   - active learning minutes;
   - recent Solo sessions.
7. **Competition**
   - clearly separate section for rating, tier, match record, PvP accuracy, and a qualified Solo-to-PvP comparison.

The dashboard window query controls visualization and activity history only. It does not rewrite learner state or lifetime exposure.

#### 15.3 Skill map example

| Skill | Solo status | Unseen independent accuracy | Pace | Evidence | Next action |
|---|---|---:|---:|---|---|
| Percentage increase | Needs repair | 5/9 (55.56%) | 1.28× | Medium | Focus |
| Ratio | Developing | 13/17 (76.47%) | 1.10× | High | Standard |
| Arithmetic | Needs fluency | 18/20 (90%) | 1.35× | High | Speed |
| Analogy | Secure | 18/20 (90%) | 0.94× | High | Maintain |

Labels and icons accompany color. Color alone must not communicate status.

#### 15.4 Trend and context visualizations

- Accuracy trend uses equivalent latest-10 and previous-10 blocks.
- Pace trend identifies the baseline and whether the value is personal or calibrated.
- Assessment scores use visually distinct markers from Solo evidence.
- Context comparisons expose sample size and suppress unsupported comparisons.
- The interface may use an accuracy-versus-pace view:
  - low accuracy + slow → Focus;
  - low accuracy + fast → possible rushing pattern, not a diagnosis;
  - high accuracy + slow → fluency work;
  - high accuracy + fast → secure when other state gates pass.

#### 15.5 Empty and low-confidence states

Examples:

> YUDHA masih mengumpulkan data. Selesaikan beberapa soal dari keterampilan yang berbeda agar rekomendasi menjadi lebih akurat.

> Assessment belum tersedia. Kemajuan ini berasal dari bukti Solo dan belum divalidasi melalui Assessment.

The UI must not convert null into 0%, show a fake readiness percentage, or label a skill weak when confidence is Low.

#### 15.6 After-session output

After a Solo session, show:

- objective and skills trained;
- answer and evidence summary;
- important error pattern supported by evidence;
- change from a comparable pre-session block when valid;
- current confidence;
- next review scheduling when applicable; and
- the next Solo recommendation.

Do not declare mastery from one session.

---

### 16. Internal content-quality dashboard

#### 16.1 Surface and authorization

The content-quality dashboard is an authenticated admin web surface backed by the App Backend.

V2 uses one server-managed admin role. Only authenticated users with that role may:

- view item-level quality data;
- create and assign review cases;
- change triage state;
- resolve a review;
- record a review note; or
- deactivate/reactivate a question.

Mobile must not expose this admin surface. Client-supplied role claims are never authoritative.

#### 16.2 Dashboard evidence

For each question revision, show:

- target, taxonomy path, difficulty, and content version;
- active, approval, quality, and review states;
- total valid attempt count;
- unseen-independent attempt count;
- activity and unseen-independent accuracy;
- median valid response time;
- timeout rate;
- hint rate;
- seen-versus-unseen gap;
- distractor selection counts and percentages;
- response distribution by comparable learner-state bands where safe;
- latest use time;
- current flags and case owner;
- related source link/reference; and
- exclusion or invalidation history.

For inventory, show:

- active question count by target and skill;
- difficulty coverage;
- Assessment-eligible inventory;
- skills below delivery minimums;
- missing explanations/hints/metadata;
- version and SME-approval status; and
- recently deactivated or invalidated revisions.

#### 16.3 Quality signals

The dashboard supports signals for:

- suspiciously low or high accuracy;
- non-functioning distractors;
- unusually long response time;
- high timeout or hint rate;
- large repeated-versus-unseen performance gap;
- potential negative or weak discrimination;
- missing skill/difficulty coverage; and
- recommendation plans blocked by inventory.

**Decision debt:** Automatic flag thresholds, minimum sample sizes, and calibrated discrimination formulas are unresolved. Initial UI may expose sortable continuous metrics and manually created cases. It must not pretend unapproved thresholds are authoritative.

#### 16.4 Triage workflow

Recommended case states:

    open → in_review → resolved
                     ↘ dismissed

Each case records:

- case ID;
- question and revision;
- signal or manual reason;
- evidence snapshot;
- admin owner;
- state;
- notes;
- created, updated, and resolved timestamps; and
- final disposition.

Possible dispositions:

- no_issue;
- revise_content;
- revise_answer_or_explanation;
- remap_skill_or_difficulty;
- invalidate_revision;
- deactivate_question;
- reactivate_question.

#### 16.5 Controlled deactivation

- Metrics never deactivate a question automatically.
- An admin must explicitly submit the action and reason.
- Deactivation affects future selection immediately after commit.
- Deactivation is not the same as analytical invalidation.
- If the revision is also invalidated, affected learner state is recalculated while raw attempts remain.
- Every action is auditable.
- Repeated deactivation requests are idempotent.

---

### 17. Public and internal interface families

Examples define behavioral shape. The OpenAPI contract becomes authoritative only after PRD adoption and contract-file updates.

#### 17.1 Common conventions

- External JSON uses camelCase.
- Timestamps are ISO 8601 UTC strings.
- Successful REST responses use a data envelope.
- Every mutation requires an idempotency key.
- Errors use the approved PRD error envelope and stable codes.
- User ownership is enforced by the App Backend and database policies.
- Clients never calculate correctness, deadlines, evidence class, learner state, recommendation priority, Assessment validation, or content-quality action authority.

#### 17.2 Recommendation

    GET /learning/recommendations/current

Returns the single current Solo recommendation described in Section 14.

    POST /learning/recommendations/:recommendationId/events

Client-writable events are limited to shown, accepted, and dismissed. The server normally creates session_started and session_completed from authoritative Solo state.

#### 17.3 Learning dashboard

    GET /learning/dashboard?window=30d

Top-level response:

    {
      "asOf": "2026-08-31T10:00:00.000Z",
      "calculationVersion": "learning-v1",
      "activityWindow": {
        "type": "rolling_days",
        "days": 30
      },
      "target": "cpns",
      "nextAction": {},
      "learningSummary": {},
      "skillStates": [],
      "learningTrend": [],
      "modeComparison": {},
      "retention": {},
      "assessment": {},
      "weeklyActivity": [],
      "recentSoloSessions": [],
      "competition": {}
    }

Every metric object with a percentage follows:

    {
      "value": 72.4,
      "correctCount": 42,
      "attemptCount": 58,
      "uniqueQuestionCount": 31,
      "confidence": "high",
      "asOf": "2026-08-31T10:00:00.000Z"
    }

#### 17.4 Create Solo session

    POST /solo/sessions

Recommended request:

    {
      "idempotencyKey": "mobile-solo-session-01928",
      "characterId": "character-basic-squire",
      "mechanicMode": "focus",
      "questionCount": 20,
      "questionSelection": {
        "type": "recommended"
      },
      "recommendationId": "rec_01JY7A2M"
    }

Custom request:

    {
      "idempotencyKey": "mobile-solo-session-01930",
      "characterId": "character-basic-squire",
      "mechanicMode": "standard",
      "questionCount": 35,
      "questionSelection": {
        "type": "custom",
        "skillIds": [
          "cpns.tiu.numerik.percentage-increase",
          "cpns.tiu.numerik.percentage-decrease"
        ]
      }
    }

Validation:

- custom requires at least one stable skill ID;
- characterId must identify an owned, active character; character choice is visual and never changes grading or damage;
- questionCount must be exactly `20`, `35`, or `50`;
- all skills must be enabled and match the learner's target;
- recommendationId is required when accepting a recommendation;
- the server determines resolved skills, inventory, mechanic, timing, and delivery;
- clients submit the learner's explicit question-count choice; manual setup has no implicit default;
- requested Speed may resolve to Standard baseline collection; and
- a runnable V2 session requires an approved delivery policy.

Response shape:

    {
      "data": {
        "sessionId": "solo_01JY7CE4",
        "status": "active",
        "target": "cpns",
        "learningSource": "solo",
        "learningObjective": "repair_accuracy",
        "requestedMechanicMode": "focus",
        "effectiveMechanicMode": "focus",
        "questionSelection": {
          "requestedType": "recommended",
          "resolvedSkillIds": [
            "cpns.tiu.numerik.percentage-increase"
          ]
        },
        "deliveryPolicy": {
          "policyId": "solo-fixed-count-v1",
          "policyVersion": 1,
          "stoppingRule": "fixed_count",
          "minimumQuestions": 20,
          "maximumQuestions": 50,
          "resolvedQuestionCount": 20,
          "resolvedDurationMinutes": null
        },
        "timerPolicy": {
          "timerVisible": false,
          "hardDeadline": false,
          "timeLimitMs": null,
          "responseTimeRecorded": true
        },
        "warnings": []
      }
    }

The initial operational slice supports Balanced + Standard. Other combinations remain contract-compatible but unavailable until their named policy dependencies are implemented.

#### 17.5 Read and resume boundary

    GET /solo/active-session
    GET /solo/sessions/:sessionId

The active-session endpoint returns the learner's latest active session or null. The owned-session endpoint returns accepted attempts, current authoritative progress, effective policies, and any safe current question.

Unfinished Solo sessions are resumable. Focus has no deadline. Standard and effective Speed retain their server-owned question deadline while the app is backgrounded; resume returns the committed timeout/result or the remaining authoritative deadline and never restarts it.

#### 17.6 Open question

    POST /solo/sessions/:sessionId/questions/:sessionQuestionId/open

Request:

    {
      "idempotencyKey": "open-solo-01JY7CE4-q1"
    }

Timed response:

    {
      "data": {
        "sessionQuestionId": "sq_1001",
        "openedAt": "2026-08-31T09:04:10.000Z",
        "timerVisible": true,
        "hardDeadline": true,
        "timeLimitMs": 30000,
        "deadlineAt": "2026-08-31T09:04:40.000Z",
        "mechanicPolicyVersion": "standard-v1"
      }
    }

Focus returns null timeLimitMs and deadlineAt.

#### 17.7 Request hint

    POST /solo/sessions/:sessionId/questions/:sessionQuestionId/hint

Request:

    {
      "idempotencyKey": "hint-solo-01JY7CE4-q1"
    }

Response:

    {
      "data": {
        "sessionQuestionId": "sq_1001",
        "hint": "Cari selisih nilai awal dan nilai akhir terlebih dahulu.",
        "requestedAt": "2026-08-31T09:04:22.000Z"
      }
    }

Hints are available in Focus, Standard, and effective Speed. The server event, not a client boolean, is authoritative.

#### 17.8 Submit Solo answer

    POST /solo/sessions/:sessionId/answers

Request:

    {
      "idempotencyKey": "answer-solo-01JY7CE4-q1",
      "sessionQuestionId": "sq_1001",
      "selectedOptionIndex": 2,
      "clientActiveResponseTimeMs": 18420,
      "backgroundDurationMs": 0
    }

The client must not send correctness, score, skill, difficulty, question version, hint usage, deadline, or evidence-classification flags.

Response:

    {
      "data": {
        "attemptId": "attempt_01JY7D71",
        "sessionQuestionId": "sq_1001",
        "selectedOptionIndex": 2,
        "correctOptionIndex": 2,
        "isCorrect": true,
        "timedOut": false,
        "responseTime": {
          "clientActiveMs": 18420,
          "serverElapsedMs": 19110,
          "backgroundMs": 0,
          "effectiveMs": 18420,
          "validForPaceAnalytics": true,
          "validForFluencyBaseline": true
        },
        "assistance": {
          "hintRequested": false,
          "independent": true
        },
        "exposure": {
          "seenBefore": false,
          "exposureCountBefore": 0,
          "evidenceType": "unseen_first_attempt"
        },
        "learningEvidence": {
          "countedForActivityAccuracy": true,
          "countedForIndependentAccuracy": true,
          "countedForRetention": false
        },
        "feedback": {
          "explanation": "Persentase kenaikan dihitung dengan..."
        },
        "progress": {}
      }
    }

#### 17.9 Timeout reconciliation

A timeout is created by the server deadline. A client may call the answer endpoint with selectedOptionIndex null only to reconcile state. The request returns the committed timeout and cannot create it twice.

#### 17.10 Complete or stop Solo session

    POST /solo/sessions/:sessionId/finish

The final request/response semantics depend on the approved delivery policy. At minimum the response must expose:

- status;
- completion reason;
- policy stop trigger when applicable;
- whether policy completed;
- answered/correct counts;
- raw accuracy and evidence breakdown;
- median valid time;
- skill results;
- review scheduling;
- mission/streak/Hired Pass eligibility; and
- next recommendation.

The endpoint must not convert a user-stopped session into policy_completed.

#### 17.11 Solo history

    GET /solo/history?skillId=&limit=&offset=

Returns paginated session summaries with requested/effective mechanic, selection type, objective, delivery-policy reference, completion reason, counts, timestamps, and evidence summary.

#### 17.12 Admin content quality

Conceptual endpoint families:

    GET   /admin/content-quality/questions
    GET   /admin/content-quality/questions/:questionId
    GET   /admin/content-quality/review-cases
    POST  /admin/content-quality/review-cases
    PATCH /admin/content-quality/review-cases/:caseId
    POST  /admin/content-quality/questions/:questionId/deactivate
    POST  /admin/content-quality/questions/:questionId/reactivate

All require the server-managed admin role, stable errors, idempotency for mutations, action reasons, and audit logging.

#### 17.13 Assessment boundary

No public Assessment session API is approved by this document.

The future web Assessment system must ingest canonical evidence through a server-owned adapter satisfying Sections 4, 9, and 10. Mobile consumes only Assessment summaries from /learning/dashboard.

#### 17.14 Compatibility endpoints

During migration:

- /practice routes remain available to existing mobile consumers;
- /analytics continues to return its approved shape;
- Lobby may continue adapting the current recommendation shape;
- current Practice source rows are ingested/backfilled with honest fidelity;
- no compatibility adapter may fabricate V2 evidence; and
- deprecation is based on migration gates and observed consumer usage, not an arbitrary date.

---

### 18. Logical data and processing

#### 18.1 Required logical entities

| Entity | Purpose |
|---|---|
| learner_preferences | Minimal optional Solo preferences |
| skill_taxonomy | Versioned SME-approved target/category/subcategory/skill catalog |
| question_skill_mappings | Primary and prerequisite skill mappings by question revision |
| solo_sessions | V2 operational Solo session and policy snapshots |
| solo_session_questions | Selected question revisions, order, purpose, and open/deadline state |
| solo_answers | Operational Solo resolution and idempotency |
| learning_attempts | Append-only canonical evidence ledger |
| learner_skill_state | Versioned derived Solo state and metrics |
| retention_schedule | Due review state and delayed-evidence link |
| learning_recommendations | Stored recommendation, inputs, explanation, and versions |
| recommendation_events | Shown-through-outcome lifecycle |
| assessment_evidence | Future Assessment source references and blueprint summaries |
| question_quality_metrics | Derived item and inventory metrics |
| question_review_cases | Admin triage workflow and evidence snapshot |
| question_quality_actions | Auditable invalidation/deactivation/reactivation history |

These are logical requirements. Physical migrations may extend or rename current tables, introduce new tables, or use compatibility views, provided the behavior and audit boundaries remain intact.

#### 18.2 Source and projection ownership

- App Backend owns Solo, learning dashboard, recommendations, learner state, preferences, and admin APIs.
- Game Backend owns authoritative PvP resolution and emits idempotent source evidence.
- Future web Assessment owns Assessment UX but writes evidence through an approved server adapter.
- PostgreSQL owns durable attempts, projections, policies, review cases, and audit records.
- Mobile and web clients render server authority and never write derived state.

#### 18.3 Prepared state, not dashboard-time recomputation

    canonical attempts
          ↓
    classify affected attempt
          ↓
    recalculate affected learner skill state
          ↓
    update due review and recommendation
          ↓
    dashboard reads prepared projections

Dashboard requests must not scan and recalculate the learner's entire history synchronously.

#### 18.4 Recalculation timing

**On every accepted attempt**

- persist operational resolution;
- append or resolve canonical attempt exactly once;
- update exposure history;
- mark affected projections dirty or update them transactionally.

**On Solo policy completion**

- finalize session summary;
- recalculate affected skills, coverage, review schedule, and recommendation;
- apply eligible mission/streak/Hired Pass effects exactly once;
- attach recommendation outcome.

**On Assessment ingestion**

- update separate validation and transfer-gap projections;
- recalculate affected Solo ranking signal without overwriting Solo state;
- refresh dashboard summary.

**Scheduled/background**

- mark seven-day reviews due;
- expire recommendations;
- refresh content-quality metrics;
- process invalidation recalculations; and
- create coverage snapshots if required.

#### 18.5 Calculation versions

Every derived state and recommendation records:

- calculationVersion;
- evidence-classification version;
- taxonomy version;
- input as-of time;
- attempt range or source watermark; and
- policy versions used for confidence, review, mechanic, and scoring.

Changing learning-v1 creates a new version and recalculates projections from raw evidence. It does not mutate old attempts.

#### 18.6 Security and privacy

- JWT and ownership validation apply to all learner endpoints.
- Admin routes require the server-managed admin role.
- Service credentials remain server-side.
- Correct answers stay hidden until authoritative resolution.
- RLS or equivalent service boundaries prevent cross-user learning reads.
- Assessment results are private to the learner and authorized services.
- Logs use IDs needed for operations and exclude tokens and unrevealed answer keys.
- Account deletion follows the approved PRD anonymization/deletion rule.

---

### 19. Additive compatibility and migration

#### 19.1 Migration principles

- New public and logical V2 contracts use Solo.
- Existing clients continue to receive current Practice and Analytics behavior until migrated.
- Compatibility is an adapter boundary, not a second source of learning truth.
- New V2 fields are additive until every active consumer supports them.
- A cutover gate requires contract tests, telemetry showing migrated consumers, and rollback instructions.
- No migration changes the approved PRD by implication.

#### 19.2 Suggested sequence

1. Add skill/version metadata and canonical-attempt infrastructure.
2. Backfill existing Practice and PvP evidence with fidelity labels.
3. Build learner-state projections alongside current analytics.
4. Expose /learning reads without removing /analytics.
5. Add recommendation lifecycle tracking.
6. Close delivery debt and approve a V2 policy.
7. Add /solo mutations and migrate Mobile.
8. Move mission/streak/Hired Pass sources from legacy completion to policy completion.
9. Remove legacy reads/writes only after consumer and rollback gates pass.

#### 19.3 Compatibility mapping

| Existing surface | Migration behavior |
|---|---|
| /practice/dashboard | Remains current; Mobile later moves to /learning/dashboard and Solo UI |
| /practice/sessions | Continues fixed-five current flow; never labeled V2 delivery |
| /practice/history | Remains until /solo/history migration |
| /analytics | Remains approved response; does not fabricate V2 confidence or unseen evidence |
| practice_* physical tables | Continue as operational/legacy sources or compatibility storage |
| current Lobby recommendation | Adapter until Lobby consumes current learning recommendation |
| current PvP socket events | Remain public contract; server maps results into canonical attempts |
| daily_practice source keys | Continue until a coordinated daily_solo compatibility migration |

#### 19.4 Backward-compatibility exit criteria

A legacy surface may be retired only when:

- all supported clients use the replacement;
- contract and E2E tests pass;
- source evidence is reconciled;
- mission, streak, Pass, and ad behavior is equivalent or explicitly approved;
- monitoring shows no supported legacy traffic;
- rollback remains possible; and
- PRD and OpenAPI contracts approve the removal.

---

### 20. Dependency-ordered delivery gates

These are acceptance gates, not calendar estimates.

#### Gate 1 — Taxonomy and policy approval

- Product adoption and ingestion into this PRD are complete.
- Skill-taxonomy schema and stable-ID rules are accepted.
- A versioned SME-owned skill catalog exists for each enabled target.
- Learning-v1 metric, confidence, state, and recommendation rules are approved or revised.
- Decision debt is assigned owners and exit evidence.

#### Gate 2 — Canonical evidence and legacy backfill

- learning_attempts and source uniqueness are migrated.
- Solo/Practice and PvP ingestion are idempotent.
- Legacy fidelity rules and backfill reports are verified.
- Question revisions, skill mappings, exposure, and invalidation paths exist.
- Privacy, ownership, and anonymization tests pass.

#### Gate 3 — Versioned learner-state analytics

- Evidence classification and all learning-v1 formula tests pass.
- learner_skill_state is rebuildable from canonical attempts.
- Latest-20 state, 10-versus-10 trends, confidence, coverage, and seven-day review work.
- Source lanes remain separate.
- /learning/dashboard supports empty, low-confidence, and migrated users.

#### Gate 4 — Recommendations and dashboards

- Ordered objective gates and deterministic ties pass.
- Recommendation evidence, versions, shown-through-outcome events, and expiry work.
- Mobile shows one Solo action, skill map, retention, Assessment result when available, and separate Competition.
- Admin web dashboard supports authorized metrics and manual triage without automatic deactivation.

#### Gate 5 — New Solo mechanics after delivery debt closes

- An approved delivery policy replaces placeholders.
- Focus, Standard, and personalized Speed timing pass.
- Hint events, question opening, timeout races, and session completion are authoritative and idempotent.
- Mission, streak, Hired Pass, and ad-safe-break behavior uses policy completion.
- Mobile migrates from Practice to Solo with compatibility and rollback evidence.

#### Gate 6 — Assessment ingestion and content-quality operations

- An approved web Assessment blueprint and adapter produce canonical evidence.
- Mobile displays result/validation without implementing Assessment delivery.
- Assessment gaps influence Solo repair ranking only as specified.
- Admin deactivation, invalidation, recalculation, and audit behavior pass.
- Content/SME and QA approve quality workflows and calibrated thresholds when introduced.

---

### 21. Acceptance scenarios

#### 21.1 Evidence classification

- Unseen, no-hint, first Solo answer counts for activity, independent, and unseen-independent accuracy.
- Hint request makes the result assisted even if the client later reports no hint.
- Repeated question counts for activity but not unseen-independent accuracy.
- Retry does not enter first-attempt proficiency.
- Invalidated question revision remains in the ledger but leaves affected projections.
- Lower-fidelity legacy evidence cannot enter a metric whose eligibility is unknown.

#### 21.2 Formula boundaries

- 5 correct of 9 yields 55.56% raw and 53.85% smoothed.
- High confidence wins before Medium when all High conditions pass.
- A recent 15-attempt set with insufficient High diversity but at least three unique questions becomes Medium, not unclassified.
- Old or diverse-insufficient evidence becomes Low.
- Null evidence returns null, not zero.
- Every percentage includes counts and confidence.

#### 21.3 Learner-state ordering

- Fewer than five eligible attempts is collecting_data.
- Smoothed 69.99% is needs_repair.
- Smoothed 70% through 84.99% is developing.
- Strong evidence with a due seven-day review is needs_review before fluency evaluation.
- At least 85%, five valid pace attempts, and ratio above 1.20 is needs_fluency.
- Secure requires Medium/High confidence and no review or fluency condition.
- Secure Solo and Assessment not_available can coexist.

#### 21.4 Recommendation selection

- Any repair candidate prevents review, coverage, fluency, or maintenance from winning.
- Due review wins when no repair exists.
- Evidence collection wins before fluency when earlier gates are empty.
- Assessment gap changes repair ranking but never overwrites Solo accuracy.
- PvP never becomes the primary action.
- Candidate ties end with stable skill ID.
- Missing inventory removes a candidate rather than returning an unrunnable hidden plan.

#### 21.5 Mechanic, hint, and timer behavior

- Focus has no deadline but records validated active time.
- Standard uses the question revision's authoritative limit.
- Speed uses 90% of a median with at least five comparable baseline attempts.
- No Speed baseline resolves to Standard and returns a warning.
- Manual low-accuracy Speed returns a warning and is not a recommendation.
- Hint is available in every mechanic and timed-mode countdown continues.
- Hinted attempts do not enter independent or fluency-baseline metrics.

#### 21.6 Timeout and idempotency

- Server deadline creates exactly one timeout without a client message.
- Answer and timeout racing for one question create one committed attempt.
- Replayed open never restarts the deadline.
- Replayed hint creates one server hint event.
- Replayed answer returns the first committed result.
- Reused idempotency key with different input fails.
- Canonical source-attempt uniqueness prevents duplicate ingestion.

#### 21.7 Dashboards

- New learner sees honest collection messaging and no weak labels.
- No Assessment shows not_available and no readiness percentage.
- Activity window changes do not change lifetime exposure or current latest-20 state.
- PvP information appears only in Competition and qualified context comparisons.
- After-session output does not declare mastery.
- Labels/icons remain understandable without color.

#### 21.8 Admin content quality

- Non-admin users receive forbidden responses.
- Admin creates, assigns, resolves, and dismisses review cases.
- A metric cannot automatically deactivate a question.
- Explicit deactivation prevents future selection and records an audit action.
- Analytical invalidation recalculates affected states but preserves raw attempts.
- Replayed actions remain idempotent.

#### 21.9 Compatibility

- Existing supported Mobile can complete the five-question Practice flow unchanged.
- /analytics remains schema-compatible during the additive phase.
- Compatibility adapters never synthesize unseen, hint, timing, or confidence evidence.
- New and legacy reads reconcile to their documented evidence scopes.
- Removing a legacy route fails the gate when supported traffic remains.

#### 21.10 Privacy and deletion

- Learners cannot read another learner's attempts or Assessment result.
- Admin access is auditable and limited to the server-managed role.
- Account deletion deletes or irreversibly anonymizes learning identity according to the approved policy.
- Aggregate retention does not permit re-identification.
- Logs never reveal unreleased answers or credentials.

---

### 22. Decision-debt register

| ID | Decision debt | Blocked capability | Required exit evidence |
|---|---|---|---|
| D4 | Adaptive/mastery stopping criteria | Adaptive policy | Validated evidence rule and deterministic tests |
| D5 | Final taxonomy weights and Recommended/Custom skill distribution | Delivery beyond the initial target-specific Balanced policy | Curriculum and learning validation |
| D6 | Difficulty progression | Session question sequence | Content/SME policy and inventory analysis |
| D7 | Intentional cross-session repetition | Exposure controls beyond no duplicates within one session | Retention/reinforcement study and content capacity |
| D10 | Whether Speed sessions are shorter | Speed delivery policy | Pace-training prototype data |
| D11 | Final skill catalogs | Skill-level production analytics | Versioned SME approval for CPNS and BUMN |
| D12 | Detailed web Assessment product/API | Assessment creation and execution | Separate approved web Assessment contract and blueprint |
| D13 | Automated content-quality thresholds | Automatic quality flags | Minimum sample, false-positive, and SME calibration study |
| D14 | Population expected-time benchmarks | Population pace labels | Representative calibrated learner data |

No engineer may close a debt item by embedding an undocumented constant. Approved answers must update this PRD, versioned policy/configuration, contracts, and tests together.

---

### 23. Source reconciliation

This document consolidates these workspace-local ignored notes:

- new-improve-analytics-blueprint.md
- new-api-docs.md
- new-analytics-flow.md
- new-question-delivery-debt.md

They may not exist in every clone because docs-archive is gitignored.

| Conflict or ambiguity | V2 resolution |
|---|---|
| Practice versus Solo | Solo is canonical; Practice is compatibility only |
| Checkpoint versus Assessment | Assessment is canonical and web-based |
| Assessment as a recommended action | Primary recommendation is Solo only |
| PvP as a recommended action | PvP remains separate Competition context |
| Five-question V2 session | Explicit decision debt; current fixed-five flow remains compatibility |
| View versus table for canonical attempts | Append-only canonical table |
| 30-day current state versus lifetime aggregate | Latest 20 eligible attempts for state; 30 days for activity; lifetime exposure |
| 80% versus 85% Speed eligibility | 85% plus five valid pace attempts |
| Needs speed versus needs fluency | needs_fluency is canonical |
| Speed hints disabled versus available | Hints available in all mechanics; hinted evidence is assisted |
| Client timeout versus server timeout | Server auto-resolves; client only reconciles |
| Secure requiring Assessment | Solo secure and Assessment validation are separate dimensions |
| Assessment blended into mastery | Separate signal may influence Solo repair ranking but is never averaged into Solo state |
| Generic priority versus objective-specific rules | Ordered objective gates, then within-objective ranking |
| 90-day aggregation versus recent behavior | Latest-20 state and 30-day activity summary |
| Five-question rewards | Future policy_completed; legacy fixed-five behavior continues until migration |
| Read-only versus operational content QA | Full admin web triage and controlled manual deactivation |
| Multiple reviewer roles versus one | One server-managed admin role |
| Smoothed 5/9 example reported as 61.54% in one source | Correct value is 53.85% |

---

## Change control

Product approves behavior and economy changes. App Backend, Game Backend, Mobile, Web, Data, AI, Security, DevOps, Content/SME, and QA approve changes affecting their contracts or acceptance criteria. A decision is complete only after this file, affected versioned catalogs/manifests, contract fixtures, and tests agree in the same change.
