# YUDHA — Product & Architecture Brief (Single Source of Truth)

> Living document. Update this file directly in the repo as decisions change — do not fork it into a separate Google Doc.
> Last updated: 2026-07-20

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
| 6 | Real-time card-based battle mechanics (HP, damage, heal, reflected damage, card hand, surrender via Socket.IO) | The product's unique selling point — strategic card selection layered on top of quiz answering |
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
        │         └─ Arena: draw hand of 4 cards → open card → answer within 10s or passed X seconds/minutes (will decide later)
        │              → correct = damage/heal → wrong = reflected damage
        │              → HP updates real-time → battle ends when HP = 0
        │              → Results screen (outcome, score, remaining HP)
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

Before choosing Bot or Player mode, the PvP entry screen now acts as a **loadout step**. Players choose one owned character and one owned arena; that selection persists across sessions and is rendered in the live battle. Locked cosmetics route back to the Store or Hired Pass. Loadout remains presentation-only and may not alter battle rules.

### 1.3 Hired Pass & Cosmetic Store

**Hired Pass** is a monthly progression track tied to real learning activity. Daily and weekly missions—such as completing practice sessions, finishing battles, maintaining a streak, or completing an interview—award **Pass Points**. Every player can claim the standard free-track rewards. Players with an active Hired Pass also receive:

- a premium reward track with more coins and higher-quality cosmetics;
- no mandatory ads while the pass is active; and
- premium cosmetics that remain owned after the monthly pass expires.

Free-tier players may see mandatory ads only at safe breaks outside active questions and battles. An active Hired Pass removes those mandatory ads. Hired Pass must remain **non-pay-to-win**: it cannot increase damage, HP, answer time, score, rank points, matchmaking priority, or question accuracy. For the MVP, pass activation and ad behavior may use server-controlled flags until payment and ads SDK integrations are implemented.

The **Store** sells cosmetic-only items using coins earned in the app. Its initial categories are character skins, arena skins, and tower skins. Purchases are permanent, duplicate purchases are rejected, and owned items can be equipped or changed from the Store/Profile. Cosmetic rarity and visual quality may differ, but no item may change battle or learning outcomes.

The player-facing name for `profiles.coins` is **Y-Coin**. During the mobile beta, the client exposes simulated top-up packages plus an unlimited `+100 Y-Coin` beta-credit action so the catalog can be tested without real payment. These simulated credits, purchases, loadouts, Hired Pass activation, points, and reward claims are persisted locally on-device until the server-authoritative Store/Hired Pass endpoints are wired. The UI must label simulated payment clearly; production balance mutation remains server-owned.

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
| weight | int | 1–4, drives battle impact calculation |
| effect | text | `damage` or `heal` |
| damage_value | int | base damage when answered correctly |
| heal_value | int | base heal when answered correctly |
| time_limit_seconds | int | per-question timer (default 10s for PvP) |
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
| reason | text | `hp_zero`, `surrender`, `question_exhaustion`, `draw` |
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
GET    /profile                → { id, username, full_name, target, rank_points, wins, losses, winrate, coins, equipped_avatar_id, equipped_arena_id, equipped_tower_id, ... }
PATCH  /profile                { username?, full_name?, equipped_avatar_id?, equipped_arena_id?, equipped_tower_id?, ... } → updated profile row

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
GET    /hired-pass             → { season, passPoints, entitlement, adFree, missions[], rewardTracks[] }
POST   /hired-pass/rewards/:rewardId/claim → { claimedReward, coins, inventory[] }

# Cosmetic Store
GET    /store/items            ?type=character_skin|arena|tower → { items[], ownedItemIds[] }
POST   /store/purchases        { itemId, idempotencyKey } → { purchase, coins, inventoryItem }

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
join_queue          { mode?: 'ranked' | 'casual' }
cancel_queue        (no payload)
open_card           { roomId, cardId }
play_card           { roomId, cardId, selectedOptionIndex }
surrender           { roomId }

# Server → Client
queue_joined        { position, queueDepth }
queue_cancelled     { reason }
match_found         { roomId, opponentUserId, role }
game_state_update   { roomId, status, self: { userId, role, hp, points, hand[], openedCardId?, answeredCardIds[], connected }, opponent: { userId, role, hp, points, connected }, phase, outcome? }
open_card_accepted  { roomId, cardId }
card_action_rejected { roomId?, action, reason, message, recoverable }
play_card_result    { roomId, cardId, correct, effect, effectValue }
match_result        { roomId, outcome, winnerUserId, loserUserId, reason, finalState }
presence_update     { roomId, players }
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

**Card effects:**

| Category | Effect | Correct Answer | Wrong Answer / Timeout |
|---|---|---|---|
| TWK | `heal` | Player heals by full impact | Opponent heals by half impact |
| TIU (numerik) | `damage` | Opponent takes full impact damage | Player takes half impact (reflected) |
| verbal | `damage` | Opponent takes full impact damage | Player takes half impact (reflected) |
| logika | `damage` | Opponent takes full impact damage | Player takes half impact (reflected) |

**Impact formula:**
```
impact = 8 + (weight.clamp(1, 4) × 6)
```
Weight 1 → 14, Weight 2 → 20, Weight 3 → 26, Weight 4 → 32.

**Win conditions:**
- Opponent HP reaches 0 → **Win**
- Player HP reaches 0 → **Lose**
- Both HP reach 0 simultaneously → **Draw**
- Player surrenders → opponent **Wins**

**Rating deltas:** Win = `+20`, Lose = `-12`, Draw = `0`.

### 3.2 Bot Opponent Logic

- Bot mode uses `BotBattleRepository` and schedules automated turns every 3.3–5.9 seconds.
- Bot prefers damage cards when available; falls back to first available card.
- Bot always answers correctly (damage is full impact, heal is full impact).
- Bot actions resolve independently from the player's visible four-card hand so real-time incoming damage cannot replace a card the player has not played.

---

## STEP 4 — AI MOCK INTERVIEW ARCHITECTURE

### 4.1 Interview Modes

| Mode | Behavior |
|---|---|
| `realistic` | Simulates a real interview. Evaluations are stored internally per turn but only revealed at session completion as a final summary. Follow-up questions are natural and acknowledge candidate facts. |
| `coaching` | Interactive learning. Per-turn evaluation is returned immediately so the candidate can learn in real time. |

### 4.2 LLM Strategy

- **Provider:** Groq API with configurable model (currently `openai/gpt-oss-120b`).
- **Deterministic opening question** avoids wasting an LLM call on a predictable prompt.
- **Rolling summary** compresses conversation history to keep prompts within token budgets.
- **Candidate facts** (name, education, field of study) are extracted and preserved in the rolling summary for natural follow-ups.
- **Company context** is snapshotted from `interview_company_contexts` at session start so prompt behavior stays stable.
- **Structured output** with strict JSON Schema validation and bounded retry for `json_validate_failed`.
- **Idempotent answer submission** via `idempotencyKey` prevents duplicate LLM evaluations.

### 4.3 Voice Interaction Layer

Audio is an input-output UX layer, not a source of truth.

- **STT (Groq Whisper):** candidate records audio → uploads to transcription endpoint → receives text transcript → reviews/edits → submits as normal text answer.
- **TTS (ElevenLabs):** interviewer question text is synthesized to audio on demand → streamed to client.
- Both providers are abstracted behind injection tokens (`INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT`, `INTERVIEW_SPEECH_SYNTHESIS_CLIENT`) so they can be swapped without touching orchestration code.

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
