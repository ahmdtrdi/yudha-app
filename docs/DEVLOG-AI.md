# AI Engineering Development Log

## 2026-06-02 - Groq OSS 120B interview orchestration foundation

### The Change
- Added a NestJS `interview` module under `apps/backend-api/src/interview`.
- Added authenticated endpoints to start, inspect, submit answers to, and complete interview sessions.
- Added a Groq-compatible LLM adapter configured for `openai/gpt-oss-120b`.
- Added strict structured-output evaluation schema wiring and runtime output validation.
- Added backend-owned company context snapshots loaded from Supabase.
- Added Supabase-backed interview session and turn persistence with idempotent answer submission.
- Added per-session pending-answer protection and short Groq retries for transient `429` or `5xx` responses.
- Added deterministic opening questions, rolling summaries, and final summaries to reduce LLM calls.
- Added Supabase migration:
  - `infra/supabase/migrations/20260602000000_interview_ai.sql`
- Updated backend environment examples for Groq and backend-only Supabase credentials.
- Updated `contracts/interview-ai/README.md` with company context ownership and idempotency semantics.
- Added typed Supabase database definitions and cleaned auth request typing used by the new module.
- Fixed baseline backend test dependency mocks encountered during verification.
- Validation passed:
  - `npm run format`
  - `npm run build`
  - `npm run lint`
  - `npm test -- --runInBand`

### The Reasoning
- Groq is isolated behind `InterviewLlmClient` so model or provider changes do not affect session orchestration.
- Sessions and turns are persisted in Supabase instead of process memory so NestJS instances remain stateless and horizontally scalable.
- Company context is resolved once into a session snapshot to keep prompt behavior stable and avoid repeated database reads during a session.
- A deterministic opening question and deterministic final aggregation reserve OSS 120B calls for answer evaluation, where model reasoning has the most value.
- Prompt sections are ordered from stable to dynamic to improve the chance of provider-side prompt cache hits.
- Pending-answer uniqueness prevents parallel submissions in one session from consuming OSS 120B quota twice.

### The Tech Debt
- The initial company context resolver uses curated priority-based retrieval. Hybrid retrieval with embeddings should be added after document volume justifies it.
- Distributed concurrency limiting is not included yet. Add Redis-backed rate limiting before running multiple API replicas under meaningful traffic.
- Failed answer claims require a new `idempotencyKey` for a deliberate retry.
- Apply the new Supabase migration before exercising interview endpoints.
- Replace the manually maintained database typing file with generated Supabase types once CLI generation is wired into the project.
- The local dependency install reported Node `23.11.0` engine warnings and `20` dependency vulnerabilities. Standardize local and CI runtime on Node `22` LTS, then review `npm audit`.
