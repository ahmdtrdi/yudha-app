# Product Dev Log

## 2026-08-17 — Consolidate the MVP product contract

### Change

- Rewrote `docs/PRD.md` in English as the single source of truth for YUDHA MVP product behavior, business rules, service boundaries, public contracts, delivery gates, and release acceptance.
- Resolved the documented gaps for Practice, battle effects and progression, WIB daily missions and streak, target-owned arenas, Private rooms, beta Y-Coin behavior, Hired Pass seasons, ad stubs, deterministic recommendations, and paid AI Interview sessions.
- Defined provider-neutral text SSE, recorded-voice, and live-voice contracts; stable REST/socket errors; mutation idempotency; authoritative ledgers; versioned Store catalogs; and versioned Hired Pass season manifests.
- Marked archived gap documents and `docs/PRD-AI-INTERVIEW.md` as subordinate to the canonical MVP contract when conflicts exist.

### Product reasoning

- Product mechanics are fixed in the PRD so clients and services cannot independently invent progression, monetization, battle, or Interview behavior.
- Content that must vary by release is bounded to checked-in, validated catalogs and season manifests without weakening the mechanics in the PRD.
- The beta economy remains paymentless: the repeatable `100 Y-Coin` `GRATIS` credit and once-per-season beta Hired Pass activation are server-authoritative, while real payment and production ads remain post-MVP.
- Daily rank missions, Ranked deltas, Y-Coin, and seasonal Pass Points are separate balances with explicit ordering, expiry, and idempotency rules.

### Remaining implementation debt

- Audit Mobile, App Backend, Game Backend, database migrations, AI adapters, deployment configuration, catalogs, season manifests, and automated tests against the rewritten contract.
- Remove production local-authority fallbacks and reconcile any existing endpoint, event, schema, or enum that differs from the PRD.
- Build and preserve acceptance evidence for WIB boundaries, concurrent ledger mutations, two-instance Redis behavior, all Interview transports, two-device journeys, accessibility, recovery, and the pilot load targets.

No product feature code was changed in this documentation-only consolidation.

## 2026-08-19 — Hired Pass Beta Testable Economy Flow

### Change

- Completed the paymentless Hired Pass beta journey from season content to mission progress, Pass Points, reward-track claims, and Premium entitlement activation.
- Kept missions and rewards release-controlled through the checked-in August season manifest: six missions and eight free/premium rewards.
- Defined beta Premium activation as a button-driven, once-per-season server mutation with no real payment provider involved.
- Preserved the product economy rules: rewards are server-authoritative, Premium rewards require active entitlement, and claims are idempotent.

### Product reasoning

- The beta flow exercises the real progression, entitlement, Y-Coin, and inventory paths while removing only the payment boundary.
- Testing against the same season manifest and atomic claim behavior reduces the gap between beta validation and the eventual paid entitlement flow.
- Free and Premium tracks remain visibly distinct so testers can verify both access rules and claim behavior.

### Remaining implementation debt

- The latest mobile/backend source must be redeployed to Railway before beta activation is available through the production API URL.
- Real payment checkout and entitlement purchase remain post-beta work; the beta button is intentionally not a payment simulation.
- A duplicate question in the full content sync still needs separate content cleanup, although the dedicated Hired Pass sync is available.

## 2026-08-31 — Consolidate the Learning System V2 draft contract

### Change

- Added `docs/LEARNING-SYSTEM-V2-DRAFT.md` as the consolidated product-and-technical proposal for skill-level evidence, Solo mechanics, learner state, deterministic recommendations, mobile learning analytics, future web Assessment evidence, and internal content-quality operations.
- Resolved conflicting source terminology and policy proposals: Solo is the V2 domain name, Assessment is a separate web validation lane, PvP remains Competition evidence, the primary recommendation is Solo-only, and Solo secure status remains separate from Assessment validation.
- Defined the proposed `learning-v1` formulas, latest-20 state window, 10-versus-10 trend, exhaustive confidence rules, 85% Speed eligibility, seven-day review, personal Speed baseline, server timeout authority, append-only attempt ledger, and additive compatibility path.
- Added an explicit delivery-policy debt register rather than treating the current five-question Practice implementation as a permanent V2 invariant.
- Updated `docs/MASTER.md` so the draft is discoverable while remaining subordinate to the approved PRD.

### Product reasoning

- A single review document prevents the analytics blueprint, API examples, formula flow, and delivery-debt discussion from becoming competing specifications.

## 2026-09-02 — Standardize Reusable Skills & SOP Documentation (`docs/skill/`)

### Change

- Created `docs/skill/` directory with standard operating procedures and canonical domain specifications:
  - `docs/skill/deploy_web.md`: Panduan eksekusi kilat deployment Flutter Web ke Vercel via CLI dan verifikasi environment variables.
  - `docs/skill/question_taxonomy.md`: Panduan taksonomi dan kategorisasi bank soal YUDHA (CPNS vs BUMN), pemetaan subkategori, dan format `primarySkillId`.
  - `docs/skill/content_pipeline.md`: Panduan sinkronisasi konten kurikulum, pengayaan bank soal HOTS, dan unit testing.
  - `docs/skill/supabase_ops.md`: Panduan tata kelola schema database, migrasi inkremental, dan postchecks integritas.
- Updated `docs/AGENTS.md` to establish the rule for AI Agents to read and contribute to `docs/skill/`.
- Updated `docs/MASTER.md` to reflect the new `docs/skill/` directory in the repository documentation index.

### Product reasoning

- Providing standardized, bite-sized skill files enables AI agents and human developers to execute critical, repeatable workflows (such as deployment and content classification) deterministically without context drift or ambiguity.
- Aligning question taxonomy explicitly with visual domain contracts ensures future question imports and solo practice modes adhere strictly to canonical CPNS and BUMN blueprints.

### Remaining implementation debt

- None. All new documentation files are integrated into the repository guidelines and verified against existing codebase patterns.

- Separating raw immutable evidence from versioned learner state allows formula calibration without rewriting learning history.
- Separating Solo, PvP, and Assessment preserves the meaning and strength of each environment while still allowing qualified context comparisons.
- Keeping the current Practice flow behind compatibility adapters lets evidence and analytics foundations progress without silently deciding the unresolved V2 delivery policy.
- Making numerator, denominator, unique-question count, confidence, and evidence source visible prevents short or assisted sessions from being presented as mastery.

### Remaining decision and implementation debt

- Product research must decide V2 stopping rules, session length, topic allocation, difficulty progression, repetition, inventory fallback, resume behavior, and continue-after-completion behavior before the canonical Solo builder can ship.
- Content/SME must approve stable CPNS and BUMN skill catalogs and later calibrate question-quality thresholds.
- A separate web Assessment contract must define its blueprint, delivery, security, and ingestion implementation.
- The draft must be reviewed and adopted into `docs/PRD.md` before any V2 behavior or public contract becomes authoritative.
- OpenAPI, shared types, migrations, source ingestion, projections, Mobile/Web surfaces, compatibility telemetry, and automated acceptance tests remain implementation work after approval.

No product feature code or approved PRD behavior was changed in this documentation-only consolidation.

## 2026-08-31 — Adopt Learning System V2 into the canonical PRD

### Change

- Promoted the approved Learning System V2 contract into Section 11 of `docs/PRD.md` and advanced the canonical product contract to version 2.0.
- Reconciled conflicting legacy language across the PRD: new domain and public contracts use Solo, while `/practice/*`, `/analytics`, and physical Practice records remain temporary compatibility surfaces.
- Replaced the fixed five-question, client-timed, blended 90-day recommendation assumptions with the approved versioned evidence, state, recommendation, timer, hint, dashboard, admin, migration, and acceptance contracts.
- Preserved the current five-question Practice delivery until Learning V2 Gate 5, while making `policy_completed` the only future Solo completion eligible for missions, streaks, Hired Pass activity, and normal-completion effects.
- Marked `docs/LEARNING-SYSTEM-V2-DRAFT.md` as an adopted historical design record and updated `docs/MASTER.md` to point all authority to the PRD.

### Product reasoning

- Approval makes the PRD the only active location teams need to interpret when implementing Learning V2.
- Embedding the full contract retains exact formulas, thresholds, weights, payload examples, tie-breakers, acceptance cases, provenance, and explicit debt instead of reducing approval to a summary.
- Keeping delivery debt visibly blocked prevents implementation teams from treating five questions—or any other unstated stopping behavior—as the permanent V2 design.

### Remaining decision and implementation debt

- Product must close the Gate 5 session-length, stopping-rule, allocation, progression, repetition, inventory-fallback, resume, and continue-after-completion decisions before new Solo delivery ships.
- Content/SME must approve the actual CPNS/BUMN skill catalogs; a separate contract must define detailed web Assessment implementation; automatic question-quality thresholds remain uncalibrated.
- OpenAPI/shared types, migrations, canonical ingestion, legacy backfill, projections, Mobile/Web surfaces, authorization, telemetry, and automated acceptance tests remain implementation work.

No product code was changed by this PRD adoption.
