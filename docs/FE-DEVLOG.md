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

## 2026-03-18 - PvP UI parity pass to align with games prototype layout

### The Change
- Refactored `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` into prototype-aligned screen structure while preserving existing battle logic integration.
- Updated pre-battle view to resemble prototype menu flow:
  - hero title/subtitle
  - large mode cards (`VS Bot`, `VS Player`)
  - online-room panel placeholder (`Create Room`, `Join Room`, room code input)
  - start battle CTA
- Reworked in-battle view into arena-oriented layout:
  - top enemy HUD card
  - center arena canvas-style container with tower slots (enemy/player mini + main towers)
  - status banner near arena bottom
  - bottom player HUD card
  - horizontal deck card rail for selecting question cards
- Kept answer flow via modal sheet with option selection wired to existing controller action.
- Reworked result screen into game-over style card (`VICTORY/DEFEAT/DRAW`) with replay and back-to-menu actions.
- Removed obsolete PvP presentation widgets no longer used after layout rewrite:
  - `presentation/widgets/battle_health_panel.dart`
  - `presentation/widgets/question_pick_card.dart`
- Updated PvP widget test assertions to match redesigned UI labels/interactions:
  - `test/widget/features/pvp/presentation/pages/pvp_page_test.dart`

### The Reasoning
- The new layout mirrors teammate prototype information hierarchy (menu -> arena HUD -> card deck -> game-over), reducing visual mismatch across implementations.
- Logic ownership remains unchanged: battle state machine/controller/repositories stay intact so we can keep parity work isolated to presentation.
- Building UI parity before deeper styling helps prevent repeated redesign effort while other features are still pending.

### The Tech Debt
- Arena visuals currently use Flutter-native placeholders (tower blocks/HUD cards) rather than full sprite assets from `apps/games/assets`.
- Online room panel is UX-only and not connected to backend-game matchmaking events yet.
- Timer ring, projectile VFX, and combo/power indicators from prototype are not implemented in this pass.

## 2026-03-18 - PvP parity follow-up fix (test overflow + tool validation)

### The Change
- Fixed small vertical overflow in PvP question deck cards detected by widget test on constrained viewport.
- Updated deck card layout in `pvp_page.dart`:
  - increased deck rail height
  - replaced rigid spacing with adaptive content (`Expanded` question text + tighter spacing)
- Re-ran validation successfully using explicit Flutter SDK path.

### The Reasoning
- Prototype-parity UI introduced denser card composition; widget tests surfaced a real responsive edge case.
- Adapting card internals preserves prototype-like structure while ensuring stable rendering across test/device sizes.

### The Tech Debt
- PvP arena visuals are still simplified placeholders versus full sprite/VFX prototype implementation.
- Further responsive tuning may be needed for very small screens when richer card metadata is added.

## 2026-03-18 - Revised FE design guide to conflict-free v1.1 (light-first + 60/40)

### The Change
- Rewrote `docs/FE-DESIGN.md` into a clean, conflict-free design guide (`v1.1`).
- Locked user decisions into the guide:
  - Logo wordmark uses `Logam` (logo only).
  - Brand balance fixed to `60% professional / 40% game`.
  - Spacing system fixed to `8pt grid` with `4px` micro-exception.
  - App theme direction set to `light-first`.
  - Primary brand/action color remains `Warrior Navy`.
- Removed contradictory rules from previous draft (font conflicts, balance mismatch, CTA ambiguity, dark-mode bias).
- Added Flutter-oriented token mapping guidance for direct implementation in `ThemeData`/`ThemeExtension`.

### The Reasoning
- Previous design doc had conflicting directives that could cause inconsistent implementation.
- The revised guide aligns visual identity with the current logo and product positioning: credible edtech first, gamified arena second.
- Light-first improves usability/readability for study flows while preserving dark intensity for PvP moments.

### The Tech Debt
- Current Flutter UI still contains temporary hardcoded colors in some PvP widgets and needs migration to centralized tokens.
- Font loading/fallback strategy for Logam/Orbitron/DM Sans/JetBrains Mono still needs to be finalized in app assets/runtime.
- Component-level specs (buttons, cards, badges) should be translated into reusable design-system widgets next.

## 2026-03-18 - Revised PvP presentation to align with FE-DESIGN v1.1

### The Change
- Updated shared theme tokens in `apps/mobile/lib/core/theme`:
  - `app_colors.dart` now reflects FE-DESIGN v1.1 tokens (`warriorNavy`, `scholarCream`, `levelUpTeal`, `fireGold`, `surfaceLight`, `surfaceDark`).
  - `app_theme.dart` updated for light-first defaults (navy app bar, cream foreground, refined radii).
- Refactored `features/pvp/presentation/pages/pvp_page.dart` to follow new design rules:
  - light-first pre-battle shell (professional-first visual tone)
  - dark arena/result surfaces only for high-intensity moments
  - navy as primary action color and teal/gold as controlled accents
  - removed most hardcoded off-brand color choices in favor of design-token usage.
- Kept PvP logic untouched (controller/state machine/repository wiring unchanged).
- Validation passed:
  - `dart format lib test`
  - `flutter analyze` (no issues)
  - `flutter test` (all tests passed)

### The Reasoning
- FE-DESIGN v1.1 established explicit direction: 60/40 professional/game, light-first app, navy primary.
- PvP needed visual realignment so UI style and design guide do not diverge while feature development continues.
- Restricting dark usage to arena/result preserves game intensity without turning the whole app into dark mode.

### The Tech Debt
- Some PvP-specific shades remain component-local and should be extracted into dedicated PvP token helpers for stricter consistency.
- Typography family mapping from FE-DESIGN (Orbitron/DM Sans/JetBrains) is documented but not fully wired in Flutter text theme yet.
- Online room panel remains UX placeholder and still needs real backend-game integration.

## 2026-03-18 - PvP arena parity pass with game sprites (prototype-aligned layout)

### The Change
- Updated `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` to a prototype-like in-battle composition:
  - enemy top HUD strip with 4 card backs and HP row
  - arena center with lane/river background and 6 tower sprite placements
  - player bottom HUD strip with avatar/HP and horizontal interactive card deck.
- Replaced the old battle list widgets usage with integrated sprite-based battle UI in the same page.
- Wired card interaction through keyed deck cards (`question-card-<id>`) while keeping existing `BattleController` + state machine flow unchanged.
- Registered game assets in `apps/mobile/pubspec.yaml` (`assets/game/`).
- Updated widget test (`test/widget/features/pvp/presentation/pages/pvp_page_test.dart`) to use stable card keys for tap flow.
- Validation completed:
  - `flutter pub get`
  - `flutter analyze` (clean)
  - `flutter test` (all passed)

### The Reasoning
- We needed closer visual parity with teammate prototype (`apps/games`) before deeper polish to avoid rework.
- Sprite-backed HUD/arena makes the mobile implementation immediately recognizable to the team while preserving FE-DESIGN direction (light shell, darker PvP intensity zones).
- Keeping battle logic untouched ensured the parity pass stayed presentation-focused and low risk.

### The Tech Debt
- Arena background is still Flutter-drawn approximation, not full map/VFX parity from the web prototype.
- Tower HP currently derives from player/opponent HP percentages, not independent per-tower game-state.
- Online mode UI remains placeholder (no real socket/matchmaking wiring yet).
- Deck card metadata (category/icon hierarchy, motion, hit feedback) needs a dedicated polishing pass.

## 2026-03-18 - Gamification foundation (progression model + leaderboard module + PvP reward bridge)

### The Change
- Added new shared gamification progression state:
  - `apps/mobile/lib/features/gamification/domain/entities/progress_tier.dart`
  - `apps/mobile/lib/features/gamification/domain/entities/player_progress.dart`
  - `apps/mobile/lib/features/gamification/application/player_progress_controller.dart`
  - `apps/mobile/lib/features/gamification/application/player_progress_providers.dart`
- Implemented full leaderboard module structure (mock-first, integration-ready):
  - Domain entities for scope/query/entry/page payload.
  - Repository contract + mock repository with pagination-ready `fetchPage`.
  - Riverpod `LeaderboardController` + `LeaderboardState` with loading/success/empty/error + load-more hooks.
- Replaced placeholder `LeaderboardPage` with real UI:
  - progress summary card
  - Global/Weekly scope filter
  - loading / error / empty / success render states
  - list tiles with rank, points, winrate, streak
  - load-more action and refresh flow.
- Bridged PvP result to gamification progression:
  - Added `rewardClaimed` guard field in `BattleState`.
  - Added `markRewardClaimed()` in `BattleController`.
  - Result screen now includes `Claim Reward` and `Leaderboard` CTA; claim updates shared progression exactly once per match result state.
- Added tests:
  - Unit: `player_progress_controller_test.dart`
  - Widget: `leaderboard_page_test.dart` covering loading/success/empty/error states.
- Validation completed:
  - `flutter analyze` (clean)
  - `flutter test` (all passed)

### The Reasoning
- We separated a reusable progression source of truth first so leaderboard and post-match rewards can evolve without coupling game UI to raw values.
- Leaderboard was built as mock-first but API-shaped (`query`, `page payload`, `hasMore`) to minimize rewrite cost when backend endpoints arrive.
- Reward-claim is explicit and one-time per result state to prevent accidental repeated point inflation during replay/demo flow.

### The Tech Debt
- Weekly leaderboard currently uses empty mock data and needs real backend feed.
- Pagination is implemented as hooks/button UX; infinite scroll and request cancellation are not added yet.
- Result reward claiming is UI-driven; server-authoritative reward validation is still required for production fairness.
- Lobby gamification widgets (rank/streak/top teaser quick actions) are intentionally deferred to the next branch.

## 2026-03-18 - Lobby redesign v1 (60/40 command-center layout)

### The Change
- Replaced the old button-list lobby with a simplified command-center style in `apps/mobile/lib/features/lobby/presentation/pages/lobby_page.dart`.
- Implemented new lobby structure:
  - top utility icon actions (`Store`, `Profile`, `Settings` placeholder)
  - single dominant center hero/progress card (avatar, tier, points, streak, winrate)
  - roadmap card with simple node path (`Battle -> Practice -> Top 10`)
  - one primary CTA (`Start Battle`)
  - secondary CTAs (`Practice`, `Leaderboard`) and tertiary exploration action (`Interview`).
- Wired progression display to shared `playerProgressProvider` to keep lobby and gamification values consistent.
- Updated initial widget smoke test (`apps/mobile/test/widget_test.dart`) for new lobby structure and scroll-based CTA assertion.
- Validation completed:
  - `flutter analyze` (clean)
  - `flutter test` (all passed)

### The Reasoning
- We intentionally narrowed lobby decisions to reduce UX confusion: one dominant action at center, supportive actions below.
- The layout keeps 60/40 balance by combining clean information hierarchy (professional) with roadmap/hero affordances (game feel).
- Bot/matchmaking toggles remain inside PvP flow, while lobby serves as a simple entry hub.

### The Tech Debt
- Current character in hero card is icon-based placeholder; final branded character art/animation is still pending.
- Roadmap is currently static and not yet dynamically locked/unlocked by real mission progression state.
- `Settings` action is placeholder only and should be connected when settings screen exists.

## 2026-03-18 - Lobby v1 follow-up refinement (hero emphasis + daily quests)

### The Change
- Refined `apps/mobile/lib/features/lobby/presentation/pages/lobby_page.dart` based on UX feedback:
  - removed roadmap block
  - replaced with compact `Today's Quest` section containing two daily tasks (`Daily Question`, `Daily PvP`)
  - moved `Interview Prep` action to top-left as requested
  - enlarged hero card visual weight (bigger avatar, larger name, increased card height/padding) so lobby remains hero-focused.
- Updated lobby smoke test text assertion in `apps/mobile/test/widget_test.dart` from `Roadmap` to `Today's Quest`.
- Validation completed:
  - `flutter analyze` (clean)
  - `flutter test` (all passed)

### The Reasoning
- The previous roadmap section competed with hero priority and diluted the intended simple lobby focus.
- Daily quest format better supports immediate session goals while keeping the section small and readable.
- Top-left interview action preserves discoverability without competing with primary battle CTA.

### The Tech Debt
- Quest completion states are currently static UI and not yet connected to real completion flags.
- Hero still uses icon placeholder instead of final branded character art/motion.

## 2026-03-18 - Lobby no-scroll stabilization (compact viewport mode)

### The Change
- Refactored lobby body to remain non-scrollable while handling shorter viewport heights safely.
- Added compact-mode responsiveness in `LobbyPage` using `LayoutBuilder` (`compact = maxHeight < 520`):
  - tighter paddings/gaps
  - smaller top controls
  - smaller hero and quest density
  - smaller button vertical spacing in compact state.
- Preserved requested information hierarchy: hero-first + small daily quest + primary CTA.
- Kept `test/widget_test.dart` assertion that lobby has no `Scrollable`.
- Validation completed:
  - `flutter analyze` (clean)
  - `flutter test` (all passed)

### The Reasoning
- Previous no-scroll layout still overflowed on constrained test viewport.
- Compact-mode sizing solves overflow without reintroducing scrolling behavior.

### The Tech Debt
- Compact breakpoints are currently hardcoded and may need design-token-level responsive constants later.

## 2026-03-18 - Lobby layout correction pass (full-width CTA + center redistribution)

### The Change
- Fixed `Start Battle` CTA width to full container width.
- Rebalanced lobby vertical composition to remove top-stacked feel:
  - moved hero + quest into an `Expanded` center region
  - hero card now fills available center space and centers its internal content
  - removed previous spacer-driven large empty gap behavior.
- Kept no-scroll behavior and compact viewport handling.
- Revalidated with full analysis and tests.

### The Reasoning
- Previous no-scroll implementation left visual dead space and made center content feel collapsed.
- Using a center `Expanded` region preserves hierarchy while making the hero visually dominant.

### The Tech Debt
- Final hero visual still uses placeholder icon and should be replaced with branded character art/motion.

## 2026-03-18 - Lobby polish pass (balance and hierarchy tuning)

### The Change
- Tweaked `apps/mobile/lib/features/lobby/presentation/pages/lobby_page.dart` to improve visual balance from the latest UI review:
  - set lobby page background to `AppColors.surfaceLight` to better match light-first design direction
  - changed hero sizing strategy from unconstrained expansion to controlled dynamic height (`~40%` of available body height, clamped) so the card remains dominant without feeling stretched
  - centered middle stack composition (hero + quest) to reduce top-heavy layout feel
  - updated non-compact hero internals to use a single centered expanded region for avatar/name/tier so internal spacing feels intentional
  - upgraded `Today's Quest` card surface with white background + subtle shadow for cleaner card separation.

### The Reasoning
- The previous layout technically fit the viewport, but visual weight was uneven: large blank hero areas and compressed lower sections reduced perceived quality.
- Controlled hero height plus centered composition preserves the requested "hero-first" lobby while keeping no-scroll behavior stable.
- Light card separation aligns better with the 60/40 professional-game balance in `FE-DESIGN.md`.

### The Tech Debt
- Current hero still uses icon placeholder instead of branded character art and motion treatment.
- We were unable to re-run `dart/ flutter` commands from this shell session because they hang in this environment, so final validation should be re-run locally in your IDE terminal before merge.

## 2026-03-19 - Lobby stabilization and hero hierarchy refinement

### The Change
- Fixed runtime zone mismatch in `apps/mobile/lib/app/bootstrap/app_bootstrap.dart`:
  - moved `WidgetsFlutterBinding.ensureInitialized()` and `FlutterError.onError` setup into the same `runZonedGuarded` flow before `runApp`.
- Stabilized hero layout in `apps/mobile/lib/features/lobby/presentation/pages/lobby_page.dart` to prevent vertical overflow on constrained Android viewports:
  - added height-aware dense handling
  - applied constraint-safe center scaling (`Expanded -> Center -> FittedBox(scaleDown) -> Column(mainAxisSize: min)`)
  - added safer text constraints (`maxLines` + ellipsis) for risky rows.
- Applied latest hero-only information hierarchy updates:
  - removed top-right `Profile` icon from header actions
  - added top-right streak metric chip beside `Store` (`Streak <n>`) and kept `Settings`
  - in hero top pills, replaced redundant `Tier` pill with `Winrate`
  - kept `Warrior Tier` text under player name as the only tier label
  - added numeric progress metric under the hero progress bar (`<current> / 400`)
  - removed bottom non-compact stat-chip row (streak/winrate), since those values are now surfaced in requested locations.
- Updated compact hero chips to keep `Points` + `Winrate` only (streak moved to top header metric).

### The Reasoning
- Flutter binding initialization must happen in the same zone as `runApp`; separating them caused the runtime assertion.
- Hero center content previously exceeded available height under certain emulator constraints; combined dense handling + scale-down guard ensures fit without adding scroll.
- This reduces information duplication and makes the hero easier to scan:
  - identity/tier stays in center
  - winrate becomes quick top-left KPI
  - streak is elevated to global top-right quick status near store.
- Numeric progress text clarifies what the bar means at a glance.

### The Tech Debt
- Tier target denominator is currently hardcoded to `400`; should be sourced from progression config once backend/game balancing is finalized.
- Hero density/scaling behavior now uses layered guards; later we should consolidate this into a single responsive token/spec to keep behavior predictable.

## 2026-03-19 - Practice session v1 (mock-backed FE flow)

### The Change
- Replaced placeholder `PracticePage` with a full practice experience in `apps/mobile/lib/features/practice/presentation/pages/practice_page.dart`:
  - Question of the Day card with start action
  - topic/category selector
  - MCQ flow (`select option -> submit -> next`)
  - hint unlock UX with monetization stub states (`locked`, `watch ad`, `buy`, `unlocked`)
  - session summary card at completion.
- Added full practice feature architecture:
  - `domain/entities`: `practice_topic`, `practice_option`, `practice_question`, `practice_hint_state`
  - `data/repositories`: `practice_repository`, `mock_practice_repository`
  - `application`: `practice_state`, `practice_controller`, `practice_providers`.
- Added tests:
  - unit: `test/unit/features/practice/application/practice_controller_test.dart`
  - widget: `test/widget/features/practice/presentation/pages/practice_page_test.dart`.

### The Reasoning
- We implemented mock-first but backend-ready contracts so FE logic can proceed now and repository can be swapped later without UI rewrite.
- Riverpod controller/state keeps progression and hint logic deterministic, testable, and decoupled from widget rendering.
- Question-of-the-day and hint-state flow are included now to cover core demo narrative, not only baseline question rendering.

### The Tech Debt
- Practice data is still static mock data and not yet wired to backend topic/question endpoints.
- Hint monetization actions are UI stubs only and need real ad/purchase integration.
- Flutter tests in this shell timed out repeatedly; local verification should be re-run from IDE terminal before merge.
