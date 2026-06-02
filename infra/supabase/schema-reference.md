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
- equipped avatar/arena IDs

The `on_auth_user_created` trigger creates a profile row whenever a new Supabase Auth user signs up.

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
- Users can update only their own profile.
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
