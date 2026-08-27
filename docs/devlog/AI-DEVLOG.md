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

## 2026-07-21 - Dedicated AI Interview PRD and High-Efficiency Architecture Specs

### The Change

- Created dedicated AI Mock Interview PRD & Technical Spec in [`docs/PRD-AI-INTERVIEW.md`](file:/*/PRD-AI-INTERVIEW.md).
- Updated parent [`docs/PRD.md`](file:*/docs/PRD.md) Section 4 to link directly to `docs/PRD-AI-INTERVIEW.md`.
- Documented token efficiency strategy yielding **75%–85% total token reduction** (Anthropic Contextual Retrieval RAG top-2 chunks, Gemini Context Caching, Rolling Summary & Candidate Facts state compression).
- Documented latency budget and protocol analysis (HTTP/2 REST + SSE for Text-to-Text streaming, WebSocket / Socket.IO for Speech-to-Speech live streaming, rejecting unnecessary client-facing gRPC complexity).

### The Reasoning

- Isolating the AI Interview specification into `PRD-AI-INTERVIEW.md` prevents bloated PRD documents while providing AI Engineers with deep, actionable technical benchmarks.
- Protocol analysis shows that 90%+ of latency in Speech/Text AI comes from LLM inference (~300-500ms) and TTS synthesis (~300ms), making gRPC transport overhead savings (~10-20ms) irrelevant compared to the added Flutter/Mobile gRPC-Web proxy complexity. SSE and WebSocket provide optimal perceived latency for streaming tokens and audio chunks.

### The Tech Debt

- Refactor `GroqLlmService` into `GeminiLlmService` supporting Native Gemini API (`@google/genai`) and Context Caching.
- Implement SSE endpoint in NestJS for Text-to-Text token streaming and WebSocket event handlers for voice audio streaming.

## 2026-07-21 - Gemini Flash Reasoning & Modular TTS Provider Architecture

### The Change

- Added `GeminiLlmService` (`apps/backend-api/src/interview/services/gemini-llm.service.ts`) implementing `InterviewLlmClient`:
  - Uses Google Gemini Flash REST API (`gemini-2.5-flash` / `gemini-3.5-flash`) with strict `INTERVIEW_EVALUATION_SCHEMA` validation.
  - Implemented Free Tier rate-limit backoff handling (exponential backoff with jitter on HTTP `429` & `5xx` errors).
- Added `GroqTtsService` (`apps/backend-api/src/interview/services/groq-tts.service.ts`) implementing `InterviewSpeechSynthesisClient`.
- Configured dynamic provider factory injection in `InterviewModule` (`apps/backend-api/src/interview/interview.module.ts`):
  - `INTERVIEW_LLM_CLIENT`: Switchable via `INTERVIEW_LLM_PROVIDER=gemini` (default) vs `groq`.
  - `INTERVIEW_SPEECH_SYNTHESIS_CLIENT`: Switchable via `INTERVIEW_TTS_PROVIDER=groq` (default) vs `elevenlabs`.
- Added unit tests: `gemini-llm.service.spec.ts` and `groq-tts.service.spec.ts`.
- Updated `apps/backend-api/.env.example` with Gemini API configuration and TTS provider toggles.

### The Reasoning

- Isolating LLM and TTS implementations behind injection tokens (`INTERVIEW_LLM_CLIENT`, `INTERVIEW_SPEECH_SYNTHESIS_CLIENT`) allows instantaneous switching between providers (e.g. from free Groq TTS to premium ElevenLabs, or from Groq LLM to Gemini Flash) via simple `.env` flags without changing any orchestration or business logic.
- Gemini Flash Reasoning offers superior context processing and JSON schema adherence for interview rubrics while staying well within Free Tier rate limits through smart retry backoffs.

### The Tech Debt

- Add native Gemini v1beta context cache registration endpoint when session duration exceeds default 30-minute window.
- Implement SSE streaming controller methods for token-by-token real-time feedback rendering.

## 2026-07-21 - Supabase Company Profile SQL Seed & Automation Generator

### The Change

- Created SQL seed script [`infra/supabase/seed_interview_companies.sql`](file:///Users/tri/Documents/code/yudha-app/infra/supabase/seed_interview_companies.sql) covering all 9 BUMN & Ministry JSON fixtures (`adhi-karya`, `bank-indonesia`, `bank-mandiri`, `garuda-indonesia`, `injourney`, `kementerian-keuangan`, `kereta-api-indonesia`, `pertamina`, `perusahaan-listrik-negara`).
- Created JavaScript generator [`apps/backend-api/src/interview/harness/generate-company-seed.js`](file:///Users/tri/Documents/code/yudha-app/apps/backend-api/src/interview/harness/generate-company-seed.js).
- Added Automated Supabase Seeder [`apps/backend-api/src/interview/harness/seed-supabase-companies.ts`](file:///Users/tri/Documents/code/yudha-app/apps/backend-api/src/interview/harness/seed-supabase-companies.ts) and NPM script `"interview:seed"`.
- Added diagnostic validation for `GEMINI_API_KEY` format (verifying `AIzaSy` prefix) in `GeminiLlmService`.
- Added automatic fallback to `response_format: { type: "json_object" }` on Groq retries to bypass server-side strict schema rejections when Groq generates string numbers like `"forty"`.
- Enhanced `InterviewEvaluationValidator` with robust score coercing for word numbers and string numbers.

### The Reasoning

- Identifies root cause of HTTP 404 errors related to API key format validation.
- Prevents 400 Bad Request `json_validate_failed` errors from Groq when LLMs produce word strings for numeric schema properties.

## 2026-07-21 - LLM Fallback Chain Fix & Modular Provider Resilience

### The Change

- Fixed `GeminiLlmService` authentication: switched from deprecated `?key=` query parameter to `x-goog-api-key` HTTP header, required for new Google Auth Keys (`AQ.` prefix format).
- Fixed `INTERVIEW_GEMINI_BASE_URL`: removed `/openai` suffix that conflicted with native Gemini `generateContent` endpoint format.
- Updated default model from retired `gemini-1.5-flash` to `gemini-2.5-flash`.
- Replaced hardcoded fallback model list (`gemini-1.5-flash`, `gemini-1.5-pro`, `gemini-2.0-flash-exp` — all retired) with configurable `INTERVIEW_GEMINI_FALLBACK_MODELS` env variable.
- Updated API key validation to accept both legacy `AIzaSy` and new `AQ.` key formats.
- Added auto-detection and stripping of `/openai` suffix from base URL with warning log.
- Added `"Respond with a valid JSON object."` to system prompt in `InterviewPromptService` to fix Groq `json_object` response format compatibility.
- Created `FallbackLlmService` (`apps/backend-api/src/interview/services/fallback-llm.service.ts`):
  - Implements `InterviewLlmClient` interface.
  - Wraps primary + fallback provider with automatic failover and structured logging.
- Updated `InterviewModule` to wire `FallbackLlmService` as `INTERVIEW_LLM_CLIENT`:
  - Primary provider based on `INTERVIEW_LLM_PROVIDER` (default: gemini).
  - Fallback is always the other provider (groq when gemini is primary, vice versa).
- Simplified `local-interview-harness.ts`: removed manual try/catch fallback logic, now uses `FallbackLlmService` matching production behavior.

### The Reasoning

- Three bugs were compounding: invalid auth method for new `AQ.` keys + wrong base URL path + retired models = every Gemini request returned HTTP 404.
- The 404 was misinterpreted as "quota exhausted" triggering Groq fallback, which also failed because Groq's `json_object` format requires the word "json" in messages.
- `FallbackLlmService` eliminates duplicated fallback logic between harness and production module, ensuring consistent resilience behavior.
- Configurable fallback models via env variable prevents future breakage when Google retires models.

### The Tech Debt

- `gemini-2.5-flash` is scheduled for retirement on October 16, 2026. Plan migration to `gemini-3.5-flash` before then.
- `FallbackLlmService` currently supports exactly 2 providers. If a third provider is added, consider a chain-of-responsibility pattern.
- Add health check endpoint that validates LLM provider connectivity on startup.

## 2026-08-27 - Final-Transcript Indonesian Live Interview Pipeline

### The Change
- Finalized live voice around Groq Whisper Indonesian STT and ElevenLabs Indonesian TTS while preserving the provider-neutral transcription/synthesis interfaces and existing structured evaluation pipeline.
- The gateway now wraps ordered PCM16 in WAV, requests `language: id`, validates the final transcript through interview guardrails, and submits it with the client answer ID as the idempotency key.
- Marked partial transcripts as optional future-adapter behavior; the current lifecycle requires `transcript_final` and never treats raw audio as domain state.

### The Reasoning
- Final-only Groq STT matches the current adapter and avoids presenting fake chunk-received events as transcript deltas. Persisted question text and candidate transcript remain canonical while ElevenLabs only supplies ephemeral playback audio.

### Verification
- Backend speech and interview tests passed, including Indonesian STT input, WAV framing, idempotent submission, TTS event ordering/degradation, and zero-answer completion protection.

### The Tech Debt
- Word-level partial captions and barge-in require a streaming-STT/full-duplex architecture and remain intentionally outside this Android turn-based release.

## 2026-08-27 - Press-and-Hold Speech Turn Boundary

### The Change
- Replaced client VAD as the answer-boundary authority with explicit button release while retaining Groq Indonesian final STT, guardrails, structured evaluation, and ElevenLabs question synthesis.
- Short or interrupted captures are cancelled before STT; valid releases keep the same final-transcript and answer-idempotency pipeline.

### The Reasoning
- Ambient noise should not decide when an interview answer ends. An explicit human gesture provides a deterministic boundary without changing the AI provider or persisted text contract.

### Verification
- Coordinator coverage verifies that only a valid release or the 90-second cap invokes `finish_answer`; cancellation never invokes STT.

### The Tech Debt
- Automatic endpointing could return later as an opt-in mode only after physical-device noise calibration; it is not part of the default live flow.

## 2026-07-23 - Groq Orpheus TTS Free Tier Integration & Modular Architecture

### The Change

- Updated [`docs/PRD-AI-INTERVIEW.md`](file:///Users/tri/Documents/code/yudha-app/docs/PRD-AI-INTERVIEW.md) to establish **Groq Orpheus TTS** (`canopylabs/orpheus-v1-english`) as the primary free-tier Text-to-Speech engine, while preserving the pluggable ElevenLabs architecture for optional high-fidelity production switching.
- Updated [`docs/misc/INTERVIEW-SPEECH-ARCHITECTURE.md`](file:///Users/tri/Documents/code/yudha-app/docs/misc/INTERVIEW-SPEECH-ARCHITECTURE.md) to document Groq Orpheus as default free tier provider and describe the provider switcher token (`INTERVIEW_SPEECH_SYNTHESIS_CLIENT`).
- Updated [`GroqTtsService`](file:///Users/tri/Documents/code/yudha-app/apps/backend-api/src/interview/services/groq-tts.service.ts): changed default TTS model fallback to `canopylabs/orpheus-v1-english` and default voice to `autumn`.
- Updated [`apps/backend-api/.env`](file:///Users/tri/Documents/code/yudha-app/apps/backend-api/.env) and [`apps/backend-api/.env.example`](file:///Users/tri/Documents/code/yudha-app/apps/backend-api/.env.example) to include explicit Groq Orpheus settings (`INTERVIEW_GROQ_TTS_MODEL=canopylabs/orpheus-v1-english`, `INTERVIEW_GROQ_TTS_VOICE=autumn`).
- Added standalone E2E Speech Pipeline harness [`apps/backend-api/src/interview/harness/test-speech-pipeline.ts`](file:///Users/tri/Documents/code/yudha-app/apps/backend-api/src/interview/harness/test-speech-pipeline.ts) and npm command `"interview:speech-test"` to easily execute end-to-end testing (Whisper STT -> Gemini LLM -> Orpheus TTS).

### The Reasoning

- Orpheus TTS hosted on Groq Cloud (`https://api.groq.com/openai/v1/audio/speech`) provides zero-cost voice generation under Groq's free tier, eliminating payment bottlenecks during development and free-tier user testing.
- Preserving `ElevenLabsTtsService` behind NestJS dependency injection (`INTERVIEW_SPEECH_SYNTHESIS_CLIENT`) allows seamless toggling between Groq Orpheus and ElevenLabs via `INTERVIEW_TTS_PROVIDER` without code changes.

### The Tech Debt

- Orpheus TTS currently synthesizes whole turn sentences. Add chunked audio streaming for long interviewer responses if sentence-level latency becomes noticeable on slow mobile networks.





