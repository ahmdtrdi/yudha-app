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

## 2026-06-02 - Local Groq harness and interview experience modes

### The Change

- Added a TypeScript local harness:
  - `apps/backend-api/src/interview/harness/local-interview-harness.ts`
  - `apps/backend-api/src/interview/harness/fixtures/local-company-context.fixture.ts`
- Added `npm run interview:harness` for local Groq testing without Supabase.
- Added `--mode=realistic` and `--mode=coaching` harness options.
- Updated prompt behavior so realistic mode keeps follow-up questions natural and coaching mode produces interactive feedback.
- Updated API response exposure:
  - realistic mode stores turn evaluations internally and returns feedback at session completion
  - coaching mode returns turn evaluation immediately
- Added `GROQ_API_KEY` as the recommended environment variable while retaining backward compatibility with `INTERVIEW_LLM_API_KEY`.
- Extracted `InterviewSummaryService` so API orchestration and local harness use the same rolling and final summary logic.
- Updated strict Groq structured output handling:
  - all JSON Schema properties are required, with nullable metadata fields
  - OSS 120B uses low reasoning effort for interactive latency
  - completion budget defaults to `2048` so reasoning does not truncate feedback fields
  - `json_validate_failed` receives one bounded retry

### The Reasoning

- Supabase availability should not block prompt evaluation or context-grounding experiments.
- A local fictional company fixture gives the AI engineer a repeatable way to inspect whether follow-up questions use supplied context rather than generic interview language.
- Realistic simulation and coaching are different product experiences even though both can use the same internal scoring call.

### The Tech Debt

- The harness fixture is intentionally local and fictional. Add more fixture scenarios for adversarial grounding, weak answers, and Indonesian language quality checks.
- Final realistic feedback is currently deterministic aggregation of per-turn evaluations. Add a separate optional final synthesis call only after measuring whether it materially improves user value.

## 2026-06-02 - Curated company fixtures and conversational candidate memory

### The Change

- Replaced the single fictional harness fixture with curated local JSON fixtures for Pertamina, Bank Mandiri, and Kementerian Keuangan.
- Added an interactive CLI company selector plus `--company` and `--role` overrides for repeatable local Groq tests.
- Reused one company briefing formatter for Supabase-backed snapshots and local fixtures.
- Added structured `candidateFacts` extraction so the rolling summary preserves explicit candidate details such as name, education status, and field of study.
- Adjusted the prompt and opening question to begin with broad interview topics before moving into deeper role-specific questions.
- Required the first follow-up after an introduction to briefly acknowledge the candidate's stated status or field of study before asking a broad next question.

### The Reasoning

- Local JSON fixtures mirror the profile, context, and source data that will later be stored in Supabase while keeping prompt iteration independent of database availability.
- Curated official-source summaries are safer and cheaper to prompt than injecting raw scraped pages.
- Explicit candidate facts let realistic-mode follow-ups acknowledge the candidate naturally without inventing personal details.

### The Tech Debt

- Add an ingestion pipeline only after the Supabase schema is available; retain human review before publishing scraped company context.
- Candidate facts currently live inside the bounded rolling summary. Promote them to a dedicated session field if longer interviews show memory loss.

## 2026-06-02 - Interview AI CLI usage guide

### The Change

- Added `docs/misc/INTERVIEW-AI-CLI.md` with local Groq harness setup, commands, flags, output interpretation, and troubleshooting.
- Linked the guide from `apps/backend-api/README.md`.

### The Reasoning

- AI engineers need one operational entry point for prompt experiments without reading implementation files or depending on Supabase availability.
- The guide separates dry-run prompt inspection from live Groq testing so quota use is explicit.

### The Tech Debt

- Keep the CLI guide synchronized when supported fixture IDs, flags, or Groq defaults change.

## 2026-06-02 - Interview speech architecture scaffold

### The Change

- Added a speech architecture scaffold inside `apps/backend-api/src/interview`:
  - `interview-speech.controller.ts`
  - `speech/interview-speech.constants.ts`
  - `speech/interview-speech.types.ts`
  - `services/interview-speech.service.ts`
  - `services/interview-audio-validator.service.ts`
  - `services/groq-stt.service.ts`
  - `services/elevenlabs-tts.service.ts`
- Added authenticated endpoints for:
  - audio transcription via `POST /interview/sessions/:sessionId/speech/transcriptions`
  - interviewer question synthesis via `GET /interview/sessions/:sessionId/speech/questions/:turnId/audio`
- Updated interview session validation and responses so `responseStyle` now supports `text` or `voice`.
- Updated session responses so question payloads expose `audioAvailable` when voice mode is active.
- Added interview repository turn lookup needed for safe per-question TTS.
- Added speech-related environment variables to `apps/backend-api/.env.example`.
- Added `docs/misc/INTERVIEW-SPEECH-ARCHITECTURE.md`.
- Validation passed:
  - `npm run build`
  - `npm run lint`

### The Reasoning

- The interview domain remains text-first so all scoring, summaries, idempotency, and harness flows continue to operate on stable text input.
- Speech is modeled as an adapter layer around the existing interview lifecycle rather than being embedded inside answer submission.
- Groq Whisper Turbo is a practical default STT choice because it is cheap, already aligned with the Groq stack in this backend, and sufficient for turn-based interview recording.
- ElevenLabs is isolated behind a synthesis client so voice quality can improve without coupling the rest of the interview module to ElevenLabs-specific APIs.
- Synthesizing only stored `question` turns prevents the TTS endpoint from becoming a generic arbitrary-text proxy.

### The Tech Debt

- The current speech flow is turn-based, not realtime. Add streaming STT only when the UI actually needs partial transcripts or live turn detection.
- TTS responses are not cached yet, so replaying the same interviewer question will call ElevenLabs again.
- Audio uploads are validated after multipart parsing. Add tighter transport-level file limits if abuse or large uploads become a concern.
- Transcript metadata is returned to the client but not persisted yet. Add per-turn speech metadata storage only if replay, analytics, or auditability justify the schema growth.
