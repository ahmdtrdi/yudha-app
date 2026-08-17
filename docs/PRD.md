# YUDHA — Product & Architecture Brief (Single Source of Truth)

> Living document. Update this file directly in the repo as decisions change — do not fork it into a separate Google Doc.
> Last updated: 2026-08-17

---

## 0. One-Liner

**YUDHA (Your Ultimate Digital Hiring Arena)** — a gamified mobile platform that builds job-selection readiness (CPNS/BUMN) through card-based PvP quiz battles, personalized AI analytics, and AI mock interviews with optional voice interaction.

---

## STEP 1 — LEAN BRIEF

### 1.1 MVP Scope

**Target build window:** 4 months, pilot-ready.

**Must-have (MVP — build first):**
| # | Feature | Why it's in MVP |
|---|---|---|
| 1 | Sign up / Log in (email + password, Supabase Auth) | Entry point; delegating auth to Supabase keeps credentials secure and reduces backend complexity |
| 2 | Lobby (progress, daily quest, nav to Practice/PvP/Rank/Profile) | Core hub |
| 3 | Practice Session (stateful, category-based, locked question sets) | Base learning loop with server-enforced question integrity |
| 4 | PvP Learning Battle — vs Bot (card-based arena) | De-risked version of PvP; bot schedules automated turns every 3–6 seconds |
| 5 | PvP Learning Battle — vs Player (matchmaking queue via Socket.IO) | Core differentiator vs. competitors |
| 6 | Real-time card-based battle mechanics (HP, combo-scaled damage, heal, card hand, surrender via Socket.IO) | The product's unique selling point — strategic card selection layered on top of quiz answering |
| 7 | Performance analytics (accuracy, response time, weak topics, winrate) | Powers personalization and retention |
| 8 | Leaderboard / Rank | Retention loop |
| 9 | Curated question bank (TWK/TIU/TKP-aligned, with damage/heal values and time limits) | Content backbone |
| 10 | AI Mock Interview (Groq API, session-based Q&A + per-turn evaluation + final summary) | Key AI differentiator |
| 11 | AI Mock Interview — Voice mode (STT via Groq Whisper, TTS via ElevenLabs) | Premium experience layer on top of the text-first interview engine |
| 12 | Freemium gating (free tier vs. active Hired Pass entitlement) | Needed to validate monetization early, even if payment isn't live yet |
| 13 | Gamification (coins, progression, and equipped cosmetics) | Retention, identity, and monetization readiness |
| 14 | Hired Pass (monthly missions, free/premium reward tracks, and ad-free premium benefit) | Adds a recurring learning and retention loop without changing competitive balance |
| 15 | Cosmetic Store (character skins, arenas, and tower skins) | Gives coins a clear purpose and lets players personalize their arena |

**Explicitly OUT of MVP (icebox):**
- Full community discussion forum
- Content marketplace
- Official competency certification
- Institutional/B2B licensing dashboards
- Payment gateway integration (Hired Pass entitlement can be activated manually in the MVP)
- Production ads SDK integration (the MVP can use ad-placement and ad-free entitlement stubs)
- pgvector semantic search on questions (defer until content volume justifies it)

### 1.2 Core User Flow

```
Splash Screen
   └─ New user?
        ├─ Yes → Sign Up (email, password, username, target: CPNS/BUMN)
        │         → Supabase Auth creates auth.users row
        │         → DB trigger creates profiles row with target
        └─ No  → Log In (email, password)
   └─ Lobby (progress, daily quest, Start Battle CTA)
        ├─ Practice → pick category → server creates session with 5 locked questions
        │              → answer one-by-one → server records response time per answer
        │              → finish session → results (accuracy, score)
        ├─ PvP
        │    ├─ vs Bot → enters arena directly → card-based battle
        │    └─ vs Player → join matchmaking queue → matched → card-based battle
        │         └─ Arena: draw hand of 4 cards → open card → answer within 30s
        │              → correct = damage/heal + advance combo → wrong/timeout = no combat effect + lower combo
        │              → HP updates real-time → each round lasts up to 180s or ends when HP = 0
        │              → first to 2 round wins (maximum 3 rounds) → Results screen
        ├─ Hired Pass → complete daily/weekly learning missions → earn Pass Points
        │              → claim free-track rewards or better premium-track rewards
        ├─ Store → browse character/arena/tower skins → buy with coins → equip
        ├─ Rank → leaderboard view (paginated, with "my rank")
        └─ Profile → performance analytics (winrate, accuracy, weak topics, streak) and equipped cosmetics
   └─ (from Profile/Analytics) → AI Mock Interview
        → choose company, mode (realistic/coaching), response style (text/voice)
        → LLM-generated Q&A with rolling context memory
        → per-turn evaluation (coaching) or final summary (realistic)
        → optional voice: record audio → STT transcript → review → submit as text
```

**Loop:** Battle → Analytics captures weak points → Analytics recommends next practice/interview → back into Practice/Battle. This closed loop is the product's core mechanic — don't break it when scoping tickets.

Before choosing Bot, Casual, or Ranked mode, the PvP entry screen acts as a **loadout step**. The authenticated profile's `target` selects the shared CPNS/BUMN battle background and question pool. Each player keeps an independently equipped, server-owned character and tower; arena remains stored for compatibility but is not a live battle cosmetic. Character cards use three cosmetic tiers—**Basic**, **Rare**, and **Legend**—and expose every character with a complete pose/projectile set: Basic Squire and Pip, Rare Ignis and Brock, plus Legend Drakor and Luna. Loadout remains presentation-only and may not alter battle rules.

PvP effects use a combo chain. A correct Damage or Heal answer uses the player's current combo level before the answer advances it: `x1`, `x2`, and `x3` apply `5`, `10`, and `15` damage or healing respectively. A correct answer advances the next projectile and starts a seven-second window; another correct answer inside that window advances the chain up to `x3`. A wrong answer or timeout causes no damage, healing, or points and lowers the actor's combo by one level. An incoming hit also lowers the defender's combo by one level, while an expired window resets it to `x1`.

### 1.3 Hired Pass & Cosmetic Store

**Hired Pass** is a monthly progression track tied to real learning activity. Daily and weekly missions—such as completing practice sessions, finishing battles, maintaining a streak, or completing an interview—award **Pass Points**. Every player can claim the standard free-track rewards. Players with an active Hired Pass also receive:

- a premium reward track with more coins and higher-quality cosmetics;
- no mandatory ads while the pass is active; and
- premium cosmetics that remain owned after the monthly pass expires.

Free-tier players may see mandatory ads only at safe breaks outside active questions and battles. An active Hired Pass removes those mandatory ads. Hired Pass must remain **non-pay-to-win**: it cannot increase damage, HP, answer time, score, rank points, matchmaking priority, or question accuracy. For the MVP, pass activation and ad behavior may use server-controlled flags until payment and ads SDK integrations are implemented.

The **Store** sells cosmetic-only items using coins earned in the app. Its initial categories are character skins, arena skins, and tower skins. Purchases are permanent, duplicate purchases are rejected, and owned items can be equipped or changed from the Store/Profile. Cosmetic rarity and visual quality may differ, but no item may change battle or learning outcomes.

The player-facing name for `profiles.coins` is **Y-Coin**. The App Backend is authoritative for catalog items, inventory, coins, purchases, beta credits, and equipped character/tower loadout through `/store/*` and `/profile/loadout`. Beta credits remain gated by `ENABLE_BETA_ECONOMY_CREDIT=true`; real-money payment is not implemented. Authenticated clients must refresh server state after mutations and surface ownership/loadout failures instead of retaining divergent local state.

---

## STEP 2 — ARCHITECTURE (Single Source of Truth)

### 2.1 Tech Stack Alignment

| Layer | Choice | Notes — lock version in `package.json`/`pubspec.yaml` before Week 1 |
|---|---|---|
| Mobile frontend | Flutter | Cross-platform; handles localized state management, real-time animation renders, and custom asset slicing |
| App Backend | NestJS (REST) | Handles auth, profile, content, practice, analytics, leaderboard, AI mock interview orchestration |
| Game Backend | NestJS + Socket.IO | Separate service — matchmaking, live card-based battle state, bot opponent logic |
| Database | PostgreSQL via Supabase | Profiles, questions, practice sessions, match history, interview sessions/turns |
| Auth | Supabase Auth (JWT) | Identity management delegated to Supabase; profiles auto-created via DB trigger |
| Cache / real-time state | Redis | Matchmaking queue, pub/sub state sync, session cache — **not** for persistent data |
| AI layer | Groq API (LLM) | AI Mock Interview — answer evaluation, follow-up generation, rolling/final summaries |
| AI Speech — STT | Groq Whisper (`whisper-large-v3-turbo`) | Transcription of candidate voice answers |
| AI Speech — TTS | ElevenLabs (`eleven_flash_v2_5`) | Synthesis of interviewer voice questions |
| Deployment | Docker containers → AWS/GCP | Confirm which cloud provider before Month 4 |

### 2.2 Data Models (core entities)

> Authoritative schema lives in `infra/supabase/bootstrapv2.sql`. This section summarizes the shape.

**`profiles`** (synced from `auth.users` via DB trigger)
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK, FK → auth.users) | |
| username | text, nullable | defaults to email prefix at signup |
| full_name | text, nullable | |
| target | text | `cpns` or `bumn`, set at registration |
| rank_points | int | drives leaderboard ordering |
| total_matches | int | |
| wins | int | |
| losses | int | |
| winrate | float | |
| coins | int | in-app currency for cosmetics |
| equipped_avatar_id | text, nullable | currently equipped avatar cosmetic |
| equipped_arena_id | text, nullable | currently equipped arena cosmetic |
| equipped_tower_id | text, nullable | currently equipped tower cosmetic |
| hired_pass_expires_at | timestamp, nullable | active pass entitlement boundary; null means free tier |
| created_at | timestamp | |
| updated_at | timestamp | |

**`questions`**
| Field | Type | Notes |
|---|---|---|
| id | uuid (PK) | |
| target | text | `cpns` or `bumn` |
| category | text | `TWK`, `TIU`, `TKP` |
| subcategory | text, nullable | finer topic tag |
| prompt | text | question body |
| options | jsonb (string array) | answer options as ordered array |
| correct_option_index | int | 0-based index into options array |
| explanation | text, nullable | shown after answer in practice |
| difficulty | text | `easy`, `medium`, `hard` |
| weight | int | 1–4, retained for future balancing; unused by current battle effects |
| effect | text | `damage` or `heal` |
| damage_value | int | retained for compatibility/future balancing; unused by the current live battle engine |
| heal_value | int | retained for compatibility/future balancing; unused by the current live battle engine |
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
| mode | text | `ranked`, `casual`, `bot` |
| target | text | `cpns`, `bumn` |
| reason | text | `hp_zero`, `surrender`, `disconnect`, `draw` |
| final_state | jsonb | HP, points for both players |
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
| status | text | `active`, `completed` |
| context_snapshot | jsonb | frozen company context at session start |
| rolling_summary | text | compressed conversation memory |
| final_summary | jsonb, nullable | LLM-generated scoring/feedback at completion |
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

**Hired Pass & Store entities**
| Table | Purpose |
|---|---|
| `hired_pass_seasons` | Monthly season window, point thresholds, and free/premium reward definitions |
| `hired_pass_missions` | Daily/weekly mission definitions and awarded Pass Points |
| `user_hired_pass_progress` | Per-user season points, mission progress, and claimed rewards |
| `store_items` | Server-authoritative cosmetic catalog, type, rarity, coin price, and availability |
| `user_inventory` | Permanent ownership of purchased or pass-earned cosmetics |
| `store_purchases` | Idempotent coin transaction record used to prevent duplicate charges |

### 2.3 API Contracts (v0 — agree before building)

**App Backend (REST, NestJS)**

```
# Auth (delegated to Supabase Auth)
POST   /auth/register          { email, password, target, username?, fullName? } → { user, session, message }
POST   /auth/login             { email, password } → { user, session }

# Profile
GET    /profile                → { id, username, full_name, target, rank_points, wins, losses, winrate, coins, equipped_avatar_id, equipped_arena_id, equipped_tower_id, hired_pass_expires_at, ... }
PATCH  /profile                { username?, full_name?, target? } → updated profile row
PATCH  /profile/loadout        { characterId?, arenaId?, towerId? } → { characterId, arenaId, towerId }

# Practice (stateful sessions)
GET    /practice/dashboard     → { categories[], stats per category }
POST   /practice/sessions      { category, subcategory? } → { sessionId, questions[] (locked set of 5) }
GET    /practice/sessions/:id  → session state with questions and answers so far
POST   /practice/sessions/:id/answers   { sessionQuestionId, selectedOptionIndex, responseTimeMs } → { isCorrect, explanation }
POST   /practice/sessions/:id/finish    → { accuracy, totalScore, correctCount }
GET    /practice/history       ?category=&limit=&offset= → [ session summaries ]

# Leaderboard
GET    /leaderboard            ?limit=&offset= → [ { userId, username, rank_points, winrate, ... } ]
GET    /leaderboard/me         → { rank, userId, username, rank_points, winrate, ... }

# Hired Pass
GET    /hired-pass             → { season, passPoints, entitlement, adFree, missions[], rewards[], claimedRewardIds[] }
POST   /hired-pass/rewards/:rewardId/claim → { claimed, rewardId, coins, itemId? }

# Cosmetic Store
GET    /store/items            ?type=character_skin|arena|tower → { coins, items[], ownedItemIds[], equipped }
POST   /store/purchases        { itemId, idempotencyKey } → { purchased, replayed, purchaseId, itemId, coins }
POST   /store/beta-credits     { idempotencyKey } → { credited, replayed, coins } (non-production flag only)

# AI Mock Interview (session + turns)
POST   /interview/sessions     { companyId, targetRole, mode, language?, responseStyle? } → { session, nextQuestion }
GET    /interview/sessions     → [ session summaries ]
GET    /interview/sessions/:id → { session, turns[] }
POST   /interview/sessions/:id/turns      { idempotencyKey, answer: { type, text } } → { nextQuestion | evaluation }
POST   /interview/sessions/:id/complete   → { finalSummary }

# AI Mock Interview — Speech (optional voice layer)
POST   /interview/sessions/:id/speech/transcriptions           multipart: audio file → { transcript, answer }
GET    /interview/sessions/:id/speech/questions/:turnId/audio   → binary audio stream
```

**Game Backend (Socket.IO events, namespace `/match`)**

```
# Client → Server
join_queue          { mode: 'ranked' | 'casual' | 'bot' } # omitted mode defaults to casual
cancel_queue        (no payload)
open_card           { roomId, cardId }
play_card           { roomId, cardId, selectedOptionIndex }
surrender           { roomId }

# Server → Client
queue_joined        { position, queueDepth, mode, target }
queue_cancelled     { reason }
match_found         { roomId, opponentUserId, opponentDisplayName, opponentLoadout: { characterId, towerId }, role, mode, target }
game_state_update   { roomId, status, mode, target, self: { userId, displayName, loadout: { characterId, towerId }, role, hp, points, hand[], openedCardId?, answeredCardIds[], connected }, opponent: { userId, displayName, loadout: { characterId, towerId }, role, hp, points, connected }, phase, outcome? }
open_card_accepted  { roomId, cardId }
card_action_rejected { roomId?, action, reason, message, recoverable }
play_card_result    { roomId, cardId, actorUserId, correct, effect, effectValue }
match_result        { roomId, mode, target, outcome, winnerUserId, loserUserId, reason, progressionPersisted, finalState: { playerA/playerB ratingDelta?, coinsDelta? } }
presence_update     { roomId, players: { [userId]: { connected, reconnectDeadline? } } }
error               { message }
```

**Contract rule for the team:** any change to a request/response shape gets a one-line update in this file in the same PR as the code change — this document *is* the contract, not the code comments.

### 2.4 Service Boundaries (who owns what)

- **App Backend (NestJS/REST):** auth proxy to Supabase, profile CRUD, question bank, practice sessions, analytics, leaderboard, Hired Pass missions/rewards, cosmetic catalog/purchases, and AI Mock Interview orchestration (including speech adapter layer).
- **Game Backend (NestJS/Socket.IO):** matchmaking queue, live card-based battle state, card dealing, damage/heal resolution, bot opponent logic, surrender/disconnect handling.
- **Frontend (Flutter):** consumes both REST (App Backend) and WebSocket (Game Backend) — keep these as two distinct client services in the codebase so devs aren't blocked on each other.
- **AI layer (Groq):** called only from App Backend — never directly from the Flutter client (keeps API keys server-side).
- **Speech layer (Groq Whisper + ElevenLabs):** called only from App Backend — audio is a UX adapter, text transcript remains the domain source of truth.

---

## STEP 3 — BATTLE MECHANICS

### 3.1 Card-Based PvP System

Unlike a simple quiz format, YUDHA uses a **card-based battle system** inspired by arena games. This adds strategic depth on top of knowledge testing.

**Battle flow:**
1. Two players are matched and each receives the same shared question pool.
2. Each player draws a **hand of up to 4 cards** from the pool.
3. Player can open the card whenever they want in the match, a player **opens a card** (locks the question) then **plays the card** by answering within the time limit.
4. The answer is resolved and effects are applied.
5. Answered cards are consumed; gaps in the hand are filled from the remaining pool.
6. When the pool is exhausted, questions are recycled with fresh IDs.
7. Incoming opponent or bot attacks never consume or reshuffle the local player's visible hand; a visible card changes only after that player uses it, regardless of whether the answer is correct or wrong.
8. Each round lasts at most **180 seconds**. A round ends early when either player's HP reaches `0`.
9. After a non-final round, both players receive a **3-second round break**. The next round resets both players to `100 HP`, `0` round points, and combo `x1`, then restores a starting hand from the shared question pool.

**Card effects:**

| Category | Effect | Correct Answer | Wrong Answer / Timeout |
|---|---|---|---|
| TWK | `heal` | Player heals `5 × current combo level`, capped at maximum HP | No HP or points effect; actor's combo lowers by one level |
| TIU (numerik) | `damage` | Opponent takes `5 × current combo level` damage | No HP or points effect; actor's combo lowers by one level |
| verbal | `damage` | Opponent takes `5 × current combo level` damage | No HP or points effect; actor's combo lowers by one level |
| logika | `damage` | Opponent takes `5 × current combo level` damage | No HP or points effect; actor's combo lowers by one level |

**Effect values:**
```
damage = 5 × comboLevel.clamp(1, 3)
heal = 5 × comboLevel.clamp(1, 3)
```
Damage and Heal use the combo level that existed before the correct answer advances the chain, producing `5`, `10`, or `15`. Heal remains capped at maximum HP. Weight remains stored as `1..4` for possible future balancing but does not affect current Damage or Heal resolution. `damage_value` and `heal_value` are likewise retained for compatibility/future tuning and are not used by the current live battle engine.

**Round and match resolution:**
- A match is best-of-three: the first player to win **2 rounds** wins the match, and a match never exceeds **3 rounds**.
- If a player's HP reaches `0`, the round ends immediately. The player with higher remaining HP wins that round.
- If the 180-second round timer expires, the player with higher remaining HP wins that round.
- Equal HP when a round ends produces a tied round; neither player receives a round win.
- After round 3, the player with more round wins wins the match. Equal round wins produce a match draw.
- Player surrender ends the entire match immediately and awards the opponent the match win.
- A disconnected human has a 30-second reconnect grace period while the opponent, card timers, and Bot turns continue. Reconnecting with a newer socket restores current state and cancels only that player's grace timer.
- If the grace period expires, the connected opponent wins with reason `disconnect`. If both human players are offline, the match is persisted as an abandoned draw with zero progression.

Only normal Ranked results mutate rating, Y-Coin, win/loss statistics, and Hired Pass activity. Casual, Bot, and abandoned disconnect draws persist history/logs with zero authoritative deltas.

### 3.2 Bot Opponent Logic

- Bot mode runs through the authenticated Socket.IO Game Backend and schedules server-authoritative turns every 3.3–5.9 seconds.
- Bot prefers damage cards when available; falls back to first available card.
- Bot always answers correctly. Damage and Heal use the Bot's current combo level (`5`, `10`, or `15`).
- Bot uses a fixed server-owned character/tower loadout and the human player's target.
- Bot and PvP rooms fetch active target-specific questions from Supabase's `questions` table. The room recycles that shared pool deterministically for the entire match; every recycled draw receives a fresh public card-instance ID while retaining its source Supabase question ID internally.
- Question exhaustion is not a normal match-end condition.

---

## STEP 4 — AI MOCK INTERVIEW ARCHITECTURE

> **Detailed Specification:** Detailed architecture, token optimization strategy (75%-85% reduction), latency benchmarks, and protocol specifications live in [`docs/PRD-AI-INTERVIEW.md`](file:*/PRD-AI-INTERVIEW.md).

### 4.1 Interview Modes

| Mode | Behavior |
|---|---|
| `realistic` | Simulates a real interview. Evaluations are stored internally per turn but only revealed at session completion as a final summary. Follow-up questions are natural and acknowledge candidate facts. |
| `coaching` | Interactive learning. Per-turn evaluation is returned immediately so the candidate can learn in real time. |

### 4.2 LLM Strategy

- **Reasoning Provider:** Gemini Flash 3.5 / 2.5 API with native Context Caching and JSON Schema Enforcement.
- **Deterministic opening question** avoids wasting an LLM call on a predictable prompt.
- **Rolling summary & Candidate Facts** compresses conversation history to keep prompts within fixed token budgets (~450 tokens history).
- **Anthropic Contextual Retrieval:** Top-2 chunk contextual injection for company profiles (~400 tokens context).
- **Company context** is snapshotted from `interview_company_contexts` at session start so prompt behavior stays stable.
- **Idempotent answer submission** via `idempotencyKey` prevents duplicate LLM evaluations.

### 4.3 Voice & Protocol Layer

Audio is an input-output UX layer, not a source of truth.

- **STT (Groq Whisper):** candidate records audio → uploads to transcription endpoint (`whisper-large-v3-turbo`) → receives text transcript → reviews/edits → submits as text answer.
- **TTS (Groq / ElevenLabs):** interviewer question text is synthesized to audio on demand → streamed to client.
- **Protocol:** HTTP/2 REST + SSE for Text-to-Text streaming, WebSocket (Socket.IO) for Speech-to-Speech live streaming.

---

## STEP 5 — 4-MONTH IMPLEMENTATION PLAN

| Phase / Timeline | Mobile/UI Designer | Backend Engineer | AI Engineer | Game/Project Lead |
|---|---|---|---|---|
| **Month 1** — Infrastructure & Design | Finalize UI/UX in Figma; start Flutter slicing | Scaffold NestJS App Backend; set up Supabase schema with profiles trigger, questions, practice tables | Bulk import question content into Supabase | Scaffold Flutter game loop and mock battle flow |
| **Month 2** — Core Development | Build practice screens, profile/analytics layouts, integrate REST endpoints | Implement Socket.IO match gateway with card-based battle engine; set up Redis for matchmaking | Build Groq interview orchestration with rolling summaries and structured evaluation | Implement card-based PvP arena with damage/heal effects, tower visuals, and bot AI |
| **Month 3** — System Integration | Connect all screens end-to-end; wire practice, PvP, interview, leaderboard, Hired Pass, and Store | Persist match results to Supabase; update profile stats post-match; add Hired Pass/Store and speech endpoints | Add interview voice layer (STT/TTS); curate company context fixtures | Implement room-code/online matches; wire Flutter to live WebSocket backend |
| **Month 4** — Polish & Release | Audit UI from user feedback; end-to-end polish | WebSocket stress testing; concurrent load validation | Optimize prompt performance; token budget tuning | Dockerize services; deploy to AWS/GCP for field testing |

---

## STEP 6 — TECHNICAL RISKS & MITIGATIONS

1. **WebSocket Latency During High Concurrent Match Load:**
   - *Risk:* Network delays or desynchronized calculations during peak testing can disrupt real-time PvP performance.
   - *Mitigation:* Keep game-state records in memory during active battles. Use Redis for matchmaking queues only. Avoid blocking PostgreSQL queries during active battle rounds.

2. **Groq API Token Consumption and Costs:**
   - *Risk:* High volumes of AI-driven mock interviews could deplete token budgets during scale testing.
   - *Mitigation:* Use deterministic opening questions and rolling summaries to minimize LLM calls. Cache common assessment templates. Lock deep AI access behind premium validation. Enforce per-session pending-answer protection to prevent parallel LLM calls.

3. **Fluctuating Exam Syllabus Formats:**
   - *Risk:* Sudden regulatory updates to SKD CPNS or BUMN testing formats could render the question bank obsolete.
   - *Mitigation:* Questions are tagged with structured `category`, `subcategory`, and `target` fields. Content updates can be cleanly targeted without schema changes. The `is_active` flag enables soft-deprecation.

4. **Speech Provider Reliability:**
   - *Risk:* Third-party STT/TTS providers (Groq Whisper, ElevenLabs) may experience downtime or API changes.
   - *Mitigation:* Speech providers are abstracted behind injection tokens. The interview engine remains text-first — voice mode degrades gracefully to text-only if speech services are unavailable.

---
