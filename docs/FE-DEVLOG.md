# FE Development Log

## 2026-03-17 - Flutter architecture baseline setup (structure + Riverpod guardrails + tab shell)

### The Change
- Updated Flutter baseline in `apps/mobile` from default counter app to feature-first architecture wiring.
- Created baseline frontend architecture directories under `apps/mobile` for:
  - `lib/app` (`bootstrap`, `router`, `config`)
  - `lib/core` (`constants`, `errors`, `network`, `theme`, `utils`, `services`)
  - `lib/shared` (`widgets`, `models`, `extensions`, `enums`)
  - `lib/features` (`pvp`, `lobby`, `leaderboard`, `practice`, `profile`, `interview`, `store`) each with `domain`, `data`, `application`, `presentation`
  - `assets` (`images`, `icons`, `lottie`, `fonts`)
  - `test` (`unit`, `widget`, `integration`)
- Added new `docs/FE-DEVLOG.md` to persist frontend implementation decisions.
- Added dependency setup in `pubspec.yaml`:
  - `flutter_riverpod`
  - `go_router`
- Strengthened lint guardrails in `analysis_options.yaml` (`avoid_print`, `always_declare_return_types`, directive ordering, and final-preference rules).
- Replaced default app entry with bootstrap-based startup:
  - `lib/main.dart`
  - `lib/app/bootstrap/app_bootstrap.dart`
  - `lib/app/app_root.dart`
- Added centralized app config and router:
  - `lib/app/config/app_config.dart`
  - `lib/app/router/app_routes.dart`
  - `lib/app/router/app_router.dart`
- Implemented persistent bottom-tab navigation for core sections:
  - `lib/app/router/app_tab_shell.dart`
  - `ShellRoute` setup for Lobby, PvP, Leaderboard, Practice, and Profile.
- Updated lobby navigation so non-tab sections open as detail flows:
  - `Interview` and `Store` now use `context.push(...)`.
- Added core guardrails/services/theme tokens:
  - `lib/core/services/app_provider_observer.dart`
  - `lib/core/theme/app_colors.dart`
  - `lib/core/theme/app_theme.dart`
- Added reusable placeholder UI primitive and routed feature pages:
  - `lib/shared/widgets/feature_placeholder_page.dart`
  - `features/*/presentation/pages/*_page.dart` for lobby, pvp, leaderboard, practice, profile, interview, and store.
- Updated widget test to assert new baseline app behavior:
  - `test/widget_test.dart` now validates lobby as initial route.
- Ran and passed:
  - `flutter pub get`
  - `dart format lib test`
  - `flutter analyze` (clean)

### The Reasoning
- We agreed to start with architecture baseline before feature coding to avoid structural rework during fast hackathon iteration.
- A feature-first + layered split keeps PvP and non-PvP modules isolated while preserving consistent project conventions.
- We needed a production-shaped baseline early so upcoming PvP implementation does not require re-architecture in the middle of feature delivery.
- `main.dart` now remains minimal while startup concerns (ProviderScope, error boundaries) live in bootstrap.
- Route-driven placeholder pages make parallel feature development possible without blocking on backend readiness.
- Centralized theme/config ensures consistent visual and technical defaults across all feature modules.
- `ShellRoute` + bottom tabs give stable section navigation with persistent controls, matching the intended app-like UX pattern.

### The Tech Debt
- Some feature folders will remain empty until the first implementation pass and may need initial placeholders when strict CI checks are added.
- Provider observer currently logs all provider updates; this should be gated by environment/build mode once runtime providers grow.
- Dark theme exists but the app is fixed to light mode for now; adaptive theme mode can be added later.
- Feature pages are structural placeholders only; domain/data/application layers are still empty and need concrete implementation per feature sprint.
- Tab selection currently maps by route prefix and assumes simple flat section paths; nested section routes may need explicit route metadata later.

## 2026-03-18 - Implemented PvP core architecture (state machine + controller + mock adapters + UI)

### The Change
- Replaced PvP placeholder with a working battle flow in `apps/mobile`.
- Added domain entities and enums for battle modeling:
  - `battle_enums.dart`, `battle_question.dart`, `battle_session_seed.dart`, `battle_state.dart`
- Added pure battle rule engine:
  - `domain/services/battle_state_machine.dart`
  - Handles damage/heal resolution, HP clamp, score updates, battle finish detection, and win/lose/draw point delta.
- Added data adapters and contracts:
  - `data/repositories/battle_repository.dart`
  - `bot_battle_repository.dart`, `online_battle_repository.dart`
  - `mock_question_bank.dart`
- Added Riverpod application layer:
  - `application/battle_controller.dart`
  - `application/battle_providers.dart`
  - Supports mode switching (bot/player), session start/reset, and answering questions.
- Added PvP presentation components:
  - `presentation/pages/pvp_page.dart` (pre-battle, in-battle, result states)
  - `presentation/widgets/battle_health_panel.dart`
  - `presentation/widgets/question_pick_card.dart`
- Added tests:
  - Unit: `test/unit/features/pvp/domain/services/battle_state_machine_test.dart`
  - Widget: `test/widget/features/pvp/presentation/pages/pvp_page_test.dart`
- Validation completed successfully:
  - `dart format lib test`
  - `flutter analyze`
  - `flutter test`

### The Reasoning
- We split PvP into domain/application/data/presentation to keep battle rules testable and backend swap easy.
- A pure state machine reduces UI-side logic complexity and enables deterministic unit tests for scoring/HP edge behavior.
- Bot and online repositories share one interface so real socket integration can replace mock adapters without UI rewrite.
- The page-level state transitions (pre-battle -> in-battle -> result) match the product flow while remaining easy to iterate.

### The Tech Debt
- `OnlineBattleRepository` is still a mock and does not yet consume real matchmaking/socket events.
- Question set and opponent behavior are static; adaptive difficulty and server-authoritative validation are not implemented yet.
- PvP UI has functional feedback but still needs stronger motion polish and richer battle effects for final demo quality.
