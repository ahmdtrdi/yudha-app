# Backend Development Log

## 2026-06-02 - Backend Game PvP Core Slice

**The Change:**
- Added shared match contracts under `contracts/` for socket events, payloads, player-relative battle state, and public question cards.
- Implemented an in-memory `backend-game` PvP core with local questions, `QuestionDealer`, pure `GameEngine`, `RoomManager`, and `MatchService` orchestration.
- Reworked the `/match` Socket.IO gateway so it stays thin: Supabase auth, event handlers, service delegation, and emits.
- Added focused tests for player-scoped card consumption, public-state redaction, final-state ordering, matchmaking, and active-room queue rejection.

**The Reasoning:**
- YUDHA PvP is an independent real-time card battle, not a shared quiz round, so cards are scoped by `roomId + userId + cardId`.
- The same shared queue seeds both players' hands for fairness, while each player advances through draws independently.
- `game_state_update` is player-relative with `self` and `opponent` so Flutter can render the same room from either player's perspective without guessing roles.


**The Tech Debt:**
- Match results are not persisted to Supabase yet, and profile stats/rank/coins are not updated.
- Reconnect recovery, disconnect win/loss, room codes, bots, countdown timers, leaderboard, analytics, and practice APIs are still future slices.
- The local question pool is only an MVP seed; production should load curated questions from Supabase or a managed content pipeline.
