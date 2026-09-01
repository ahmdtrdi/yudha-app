# YUDHA Supabase Schema Reference

This document explains the schema in `bootstrap.sql` for teammates.

## Auth And Profiles

`auth.users` is managed by Supabase Auth and stores login identities.

`public.profiles` stores YUDHA app data:

- username and full name
- rank points
- match counters
- winrate
- coins
- equipped avatar/arena/tower IDs
- Hired Pass entitlement expiry

The `on_auth_user_created` trigger creates a profile row whenever a new Supabase Auth user signs up.

## Store And Hired Pass

`public.store_items` is the authoritative cosmetic catalog. Ownership is stored
in `public.user_inventory`; purchases and every balance change are recorded in
`public.store_purchases` and `public.coin_transactions`.

Hired Pass seasons, missions, and rewards are stored separately from per-user
progress and claims. Database triggers award mission activity when a practice
session or interview becomes completed. Match finalization records battle
activity in the same transaction as rank and Y-Coin rewards.

All purchase, reward, loadout, and activity mutations use service-role-only
database functions so balance checks, ownership changes, and idempotency happen
atomically.

## Questions

`public.questions` is the backend-authoritative question table.

It includes:

- `prompt`
- four options in JSON array format
- `correct_option_index`
- explanation and hint
- difficulty and weight
- battle effect fields: `damage`, `heal`, values, and time limit

`public.public_questions` is a safe view for client-facing reads. It intentionally hides:

- `correct_option_index`
- `explanation`
- answer metadata

Live PvP should still prefer backend-generated payloads instead of direct table reads.

## Practice

`public.practice_sessions` stores a practice attempt summary.

`public.practice_answers` stores each answer in a session, including selected option, correctness, hint usage, and response time.

## Learning Analytics V2 Foundation

The additive Learning V2 migration keeps the fixed-five Practice flow intact
while introducing a separate canonical evidence and projection boundary:

- `learning_taxonomy_versions`, `learning_skills`, `question_revisions`, and
  `question_skill_mappings` hold versioned content authority. Question answers
  and explanations remain server-only.
- `learner_question_exposures` records lifetime presentation counts without
  inventing exposure for legacy rows.
- `learning_attempts` is the append-only, source-idempotent evidence ledger.
  Versioned `learning_attempt_classifications` decide which metrics each row may
  enter, and `learning_attempt_invalidations` correct evidence without rewriting it.
- `learning_projection_jobs`, `learner_skill_state`, and
  `retention_schedules` hold rebuild work and versioned prepared learner state.
- `learning_recommendations` and append-only `recommendation_events` preserve
  deterministic inputs, availability, expiry, and lifecycle attribution.
- `assessment_evidence` is a minimal import boundary and remains separate from
  Solo proficiency.
- `learning_backfill_runs` and `learning_fixture_runs` make replay, test data,
  and invalidation auditable.

Practice rows gain nullable recommendation, revision, skill, exposure, hint,
and canonical-attempt references. Existing rows retain
`evidence_capture_version = legacy-practice-v1`; no historical revision, hint,
exposure, timing, or skill eligibility is fabricated. Authenticated legacy
column writes remain available where they existed, but every new V2 snapshot
column is service-role-authoritative.

## PvP Match History

`public.match_results` stores one final row per finished match.

`public.match_question_pool` stores the shared card/question queue snapshot for a match. This helps with fairness review, replay, and analytics.

`public.match_logs` stores individual player actions such as:

- `open_card`
- `play_card`
- `surrender`
- `timeout`

These logs are optional for the first persistence slice but useful later for analytics and review.

## AI Interview

`public.interview_mockups` stores one mock interview session summary and feedback.

`public.interview_messages` stores the user/AI/system message history for a mock interview.

## Content And Documents

`public.institutions` stores CPNS/BUMN/Kedinasan or company-style institutions.

`public.documents` stores uploaded or referenced source documents.

`public.document_chunks` stores text chunks for retrieval. It is ready for a future embedding column if vector search is added.

## RLS Summary

- Profiles are readable by authenticated users.
- Profile and economy mutations are server-only; authenticated clients cannot
  directly update rank, coins, loadout, inventory, or Hired Pass state.
- Leaderboard profile reads are allowed for anonymous users.
- Full `questions` has no direct authenticated read policy.
- Practice rows are scoped to the owning user.
- Match result/log/pool reads are scoped to match participants.
- Interview rows are scoped to the owning user.
- Institutions/documents/chunks are readable by authenticated users, with writes expected through backend/admin service-role flows.

## Naming Map

| Concept | Database Name |
| --- | --- |
| Supabase user | `auth.users` |
| Player profile | `profiles` |
| Cosmetic catalog | `store_items` |
| Player cosmetic ownership | `user_inventory` |
| Store purchase | `store_purchases` |
| Y-Coin audit entry | `coin_transactions` |
| Hired Pass season | `hired_pass_seasons` |
| Hired Pass mission | `hired_pass_missions` |
| Hired Pass reward | `hired_pass_rewards` |
| Question bank | `questions` |
| Safe question view | `public_questions` |
| Practice session | `practice_sessions` |
| Practice answer | `practice_answers` |
| Match summary | `match_results` |
| Match shared queue | `match_question_pool` |
| Match action logs | `match_logs` |
| Interview session | `interview_mockups` |
| Interview message | `interview_messages` |
| Institution | `institutions` |
| Document | `documents` |
| Document chunk | `document_chunks` |
