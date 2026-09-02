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
- Added new `docs/devlog/FE-DEVLOG.md` to persist frontend implementation decisions.
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
- Rewrote `docs/design/FE-DESIGN.md` into a clean, conflict-free design guide (`v1.1`).
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
- Light card separation aligns better with the 60/40 professional-game balance in `docs/design/FE-DESIGN.md`.

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

## 2026-03-19 - Personal profile v1 (performance + settings)

### The Change
- Replaced placeholder profile page with a functional personal module in `apps/mobile/lib/features/profile/presentation/pages/profile_page.dart`:
  - profile header with avatar placeholder and tier/points identity
  - performance analytics cards (winrate, tier, total matches, best streak)
  - rank trend indicator card (derived from `lastDelta`)
  - settings panel with Bahasa labels: language selector (`ID`/`EN`), daily notification toggle, sound toggle, haptic toggle.
- Added profile application/domain state layer:
  - `domain/entities/profile_language.dart`
  - `domain/entities/profile_settings.dart`
  - `application/profile_settings_controller.dart`
  - `application/profile_settings_providers.dart`
- Added tests:
  - unit: `test/unit/features/profile/application/profile_settings_controller_test.dart`
  - widget: `test/widget/features/profile/presentation/pages/profile_page_test.dart`.

### The Reasoning
- Personal features need shared, testable settings state instead of local widget state to stay scalable for future backend persistence.
- Performance cards are sourced from existing gamification progression state so profile reflects real in-app progress immediately.
- Bahasa-first labels match current product language context while still allowing quick language switching UX.

### The Tech Debt
- Profile settings are still in-memory only and not persisted locally/remote.
- Rank trend currently derives from `lastDelta` as a short-term proxy; historical trend data should come from backend analytics later.
- Flutter test execution in this shell remains unstable/timeouts; local verification should be re-run in IDE terminal before merge.

## 2026-03-19 - Bottom nav and icon system consolidation (session merge)

### The Change
- Consolidated multiple iterative nav passes into one final implementation:
  - generated and wired spec-based SVG nav assets in `apps/mobile/assets/icons/navigation/`
  - added `flutter_svg` and registered icon assets in `apps/mobile/pubspec.yaml`
  - replaced default `NavigationBar` behavior with custom tab rendering in `apps/mobile/lib/app/router/app_tab_shell.dart`
  - finalized active/inactive visual system: active navy tile for icon, always-visible labels, inactive tint, and light nav shell with subtle top shadow.
- Kept route behavior stable (`context.go(route)`) across all tabs.

### The Reasoning
- We made several short visual iterations in one session; this merged record captures the final state without repeating intermediate styling experiments.
- Custom tab rendering was required to match the approved icon hierarchy and active-state composition more precisely than stock `NavigationBar`.

### The Tech Debt
- Final spacing and icon stroke weight still need one device QA pass across target Android sizes.
- Some local `flutter`/`dart` validations from this shell timed out; final verification should be re-run from IDE terminal before merge.

## 2026-03-19 - Lobby hierarchy and hero refinements (session merge)

### The Change
- Consolidated lobby iterations into the final hierarchy in `apps/mobile/lib/features/lobby/presentation/pages/lobby_page.dart`:
  - hero identity block, then `TODAY'S QUESTS`, then one `START BATTLE` primary CTA
  - restored top utility row with streak on the left and settings on the right
  - restored daily quest progress count badge and removed redundant labels
  - removed decorative hero orbs and fixed a follow-up syntax issue from the refactor.
- Moved Interview Prep access into practice flow via `apps/mobile/lib/features/practice/presentation/pages/practice_page.dart`.

### The Reasoning
- This keeps lobby focused and scannable while preserving key quick actions you asked to keep.
- Merging these edits removes log noise from multiple small tweak entries in the same uncommitted session.

### The Tech Debt
- Quest completion values are still static placeholders and should be wired to real daily progression state.
- Settings action is still a placeholder snackbar.
- Local formatting and analyze commands were inconsistent in this shell; run a final local pass before commit.

## 2026-03-19 - PvP pre-battle polish (Indonesian copy + arena layout)

### The Change
- Rebuilt the pre-battle view in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` to mirror the provided Battle Arena mock:
  - hero board with "Kamu" vs selected opponent badge and centered VS chip
  - Indonesian copy throughout (PILIH LAWAN, BOT/PEMAIN, MASUK ARENA, info note)
  - selection cards replace the old segmented control while still driving `BattleMode`
  - info banner and primary CTA restyled to match reference.

### The Reasoning
- Aligns the PvP entry flow with the approved visual hierarchy and Bahasa-first UX while keeping existing controller hooks intact.

### The Tech Debt
- Need to re-run `dart format`/`flutter analyze` locally (commands time out here).

## 2026-03-19 - PvP import recovery fix

### The Change
- Restored the missing `battle_state.dart` import in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` after the pre-battle rebuild.

### The Reasoning
- `BattleState` was used by the rebuilt page but not imported, which caused the hot-restart type errors.

### The Tech Debt
- The rebuilt PvP page still needs a full local analyze/format pass once the layout pass is stable.

## 2026-03-19 - PvP arena visual refinement pass

### The Change
- Refined the pre-battle arena in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` based on UI review:
  - removed the internal arena title
  - added grid lines, corner brackets, center rings, and anchor markers so the arena feels designed rather than placeholder
  - enlarged avatars and added pedestal bars beneath them
  - restyled the top hint/toast and lower info strip into the same teal guidance language with dot indicator
  - upgraded `MASUK ARENA` into an Orbitron CTA with arrow icon
  - tightened the lower spacing so the CTA sits closer to the navbar.

### The Reasoning
- The previous pass had correct structure but weak visual hierarchy; this refinement makes the pre-battle scene carry the identity instead of relying on labels.
- Matching the hint strip and toast styling reduces mixed UI language and makes the screen feel more intentional.

### The Tech Debt
- Still needs a final local `flutter analyze` and device QA pass after the visual tweaks.

## 2026-03-19 - PvP in-battle arena restoration

### The Change
- Restored the gameplay arena portion in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` after the pre-battle rebuild:
  - enemy/player HUD strips
  - tower battlefield panel
  - question card rail
  - dark in-arena status banner styling
  - tower HP bars and values.

### The Reasoning
- The previous recovery preserved pre-battle but accidentally replaced the actual battle arena with a temporary placeholder, which broke the intended game view.

### The Tech Debt
- PvP file now mixes two polish tracks (pre-battle and in-battle) in one page; later we should consider splitting arena sections into dedicated widgets/files for safer iteration.

## 2026-03-19 - PvP result screen polish

### The Change
- Redesigned the finished-state result screen in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` to match the provided victory/defeat reference:
  - large outcome badge and title (`VICTORY` / `DEFEAT` / `DRAW`)
  - score comparison card
  - compact lower metrics row
  - rating change strip
  - `CLAIM REWARD`, `Play Again`, and `Back to Lobby` actions
  - dedicated claimed-reward banner state.

### The Reasoning
- The previous result state was functionally correct but visually much weaker than the pre-battle and arena screens.
- This pass makes the post-battle moment feel like a proper payoff screen while still using real state that already exists in the battle model.

### The Tech Debt
- The battle state currently does not track granular stats like exact correct answers, total damage dealt, or total healed, so the lower metric row uses only stable values already present in state.
- Final typography/spacing should still be validated on device after local format/analyze.

## 2026-03-19 - Result screen behavior cleanup

### The Change
- Updated the finished-state behavior in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`:
  - hid the top battle status/error banner once the match reaches finished state
  - changed the lower reward strip label from `Rating change` to `EXP`
  - removed result-screen scrolling by switching the finished layout to a bounded `LayoutBuilder` column.

### The Reasoning
- The result screen should feel like a dedicated payoff screen, not a continuation of the in-battle state with leftover notifications.

### The Tech Debt
- Final compact spacing still needs a quick device QA pass to confirm every element fits cleanly on shorter Android screens.

## 2026-03-19 - Result screen overflow fit pass

### The Change
- Added compact and very-compact density handling in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` for finished-state layout:
  - scaled down result badge size
  - reduced vertical spacing and card paddings
  - reduced score/metric typography sizes in compact view
  - reduced action button heights and back-link spacing
  - made claimed-reward banner compact-aware.

### The Reasoning
- This keeps the result page non-scrollable while preventing bottom overflow on short Android viewports.

### The Tech Debt
- Needs one local visual pass to ensure compact mode still matches the intended design proportions.

## 2026-03-19 - Result screen spacing rebalance + CTA emphasis

### The Change
- Rebalanced the finished-state vertical flow in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` by replacing a fixed lower gap with flexible spacing (`Spacer`) to reduce dead space while keeping non-scroll behavior.
- Promoted `CLAIM REWARD` to a stronger primary CTA using teal fill and white Orbitron label.
- Kept `Play Again` as a secondary outlined action for clearer action hierarchy.

### The Reasoning
- The compact overflow fix removed clipping but left visual dead space at the bottom; flexible spacing keeps the layout filled more naturally across device heights.
- Reward claim is the primary post-battle action, so it should have stronger visual weight than replay.

### The Tech Debt
- Final balancing should still be validated on both win/lose states and smaller Android emulator presets.

## 2026-03-19 - PvP in-battle surrender action

### The Change
- Added an in-battle `Menyerah` button in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`.
- Wired the button to existing battle controller surrender flow (`controller.surrenderBattle`) so players can end a match early from the arena state.
- Kept the change incremental in the current PvP page structure (no file replacement).

### The Reasoning
- Surrender is a core battle control for UX and demo completeness, especially during bot testing and faster iteration loops.
- Wiring through the controller preserves single-source state transitions (`inBattle -> finished`) and keeps UI logic minimal.

### The Tech Debt
- `surrenderBattle()` currently uses a fixed rating delta and does not yet apply mode-specific penalties/rules.
- The new button uses a compact danger-outline style; final spacing and emphasis should be tuned in the next PvP visual polish pass.
- `flutter analyze` timed out in this shell session, so local IDE-terminal verification is still needed.

## 2026-03-19 - PvP in-battle status popup + duplicate message cleanup

### The Change
- Updated `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` so in-battle status/error updates are now shown as temporary floating pop-up notifications (`SnackBar`, 3s) instead of persistent top banners.
- Limited persistent `_StatusBanner` rendering to pre-battle only.
- Removed redundant dynamic status source from the arena panel by keeping the arena hint text static (`Pilih kartu untuk menyerang atau heal.`).

### The Reasoning
- The same status message was being shown in multiple places during battle, which felt repetitive.
- Temporary pop-up notifications preserve feedback but clear themselves after a few seconds, matching your requested behavior.

### The Tech Debt
- Notification style currently uses Material `SnackBar`; if we want stricter visual parity with the custom teal info strip, we can replace this with a bespoke in-app toast component.
- Shell-based format/analyze remains unstable in this environment, so final local verification is still recommended before commit.

## 2026-03-19 - PvP in-battle HUD and notif de-duplication tweaks

### The Change
- Updated `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`:
  - split right-side HUD metrics into two compact stacks with labels (`HP` under percentage and `PTS` under points)
  - added a left circular marker to dark in-arena status banner style
  - made arena hint message nullable and only visible while `answeredQuestionIds` is empty
  - after any card is answered, the static `Pilih kartu untuk menyerang atau heal.` hint now disappears.

### The Reasoning
- This removes redundant simultaneous messaging between static arena hint and transient battle notifications.
- Explicit `HP` and `PTS` labels improve readability of the compact HUD values.

### The Tech Debt
- HUD label sizing is tuned for current layout and should still be checked on very small screens.
- If we want richer UX later, the initial hint can be animated/faded instead of conditionally removed.

## 2026-03-19 - PvP arena UI parity between Bot and Player modes

### The Change
- Normalized PvP arena-facing labels in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` so Bot and Player modes share the same visual presentation.
- Updated enemy labels to a neutral `Lawan` across:
  - pre-battle arena preview enemy badge
  - in-battle enemy HUD header
  - result score card opponent column.
- Simplified `_ArenaPreview` by removing mode-dependent label branching now that arena visuals are unified.

### The Reasoning
- You asked to keep arena UI consistent between bot and player paths; this removes mode-specific visual differences while still preserving mode selection controls.
- Mode choice remains functional (Bot/Player cards), but arena composition now reads as one consistent battle template.

### The Tech Debt
- Online mode still behaves as mock battle data and room-key join flow is not yet wired; only UI parity was normalized in this pass.

## 2026-03-19 - PvP app bar controls rework (result-only back + icon surrender confirm)

### The Change
- Updated `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` app bar behavior:
  - removed back arrow from pre-battle and in-battle screens
  - added back arrow only on result state (`BattlePhase.finished`) and wired it to `controller.resetBattle` (back to pre-matchmaking flow)
  - moved surrender control to top-right app bar as icon-only flag button during in-battle.
- Added surrender confirmation dialog before applying `controller.surrenderBattle()`.
- Removed old inline `Menyerah` row from `_InBattleSection`, allowing enemy HUD/deck region to sit fully at the top.

### The Reasoning
- This matches the requested interaction hierarchy: arena should stay clean and use compact top-bar controls.
- Confirmation guard prevents accidental surrender taps while keeping the control accessible.

### The Tech Debt
- If needed later, dialog visual styling can be aligned further with the custom PvP theme instead of default AlertDialog look.

## 2026-03-19 - PvP battlefield visual parity pass (checker field + larger towers + lane separation)

### The Change
- Updated `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` arena rendering to better match `apps/games/js/game.js` field style:
  - replaced plain gradient field with custom-painted battlefield (`_BattlefieldPainter`) using checker-like grass tiles
  - added central dirt lanes and river treatment with foam highlights and river edge lines.
- Repositioned tower alignments so enemy towers are clearly above the river and player towers below it.
- Increased in-arena tower presence:
  - larger tower sprite sizes
  - added stone-like tower pads
  - slightly larger HP bars/value text for readability.

### The Reasoning
- You requested parity with teammate’s arena visual language and clear side separation by river.
- Previous tower coordinates made enemy mini towers sit too close to the river; new alignment restores top-vs-bottom battlefield readability.

### The Tech Debt
- River motion in Flutter is currently static visual styling; if needed we can add lightweight animation later for closer parity with the JS version.
- Final pad/tower scaling should still be validated on multiple screen heights to avoid overlap with temporary status banner.

## 2026-03-19 - PvP mini-tower river clearance tweak

### The Change
- Adjusted mini tower vertical positions in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`:
  - enemy minis from `-0.36` to `-0.48`
  - player minis from `0.36` to `0.48`
- Kept current arena style and tower scale unchanged.

### The Reasoning
- The previous larger tower assets were still visually touching/crossing the river boundary line.
- This spacing tweak increases side separation so enemy/player side control reads clearly.

### The Tech Debt
- Depending on target device aspect ratios, we may still need one more small per-breakpoint adjustment for perfect balance.

## 2026-03-19 - PvP full tower formation separation from river

### The Change
- Updated all tower alignments in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` to move both mini and main towers farther from river center:
  - enemy main: `-0.62 -> -0.70`
  - enemy minis: `-0.48 -> -0.56`
  - player main: `0.63 -> 0.71`
  - player minis: `0.48 -> 0.56`

### The Reasoning
- You requested full formation separation (not minis only) so bases and towers stay clearly on their own side.

### The Tech Debt
- If we add larger tower FX later, we may need per-device responsive offsets to keep perfect spacing on short screens.

## 2026-03-19 - PvP tower spacing pass #2 (further river separation)

### The Change
- Pushed tower formation farther from river again in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`:
  - enemy main: `-0.70 -> -0.72`
  - enemy minis: `-0.56 -> -0.62`
  - player main: `0.71 -> 0.72`
  - player minis: `0.56 -> 0.62`

### The Reasoning
- Follow-up spacing request to ensure bases no longer visually touch the river boundary line.

### The Tech Debt
- Final vertical offsets should still be quickly verified on a shorter-height emulator profile to confirm no clipping at top/bottom extremes.

## 2026-03-19 - PvP player-room code flow in Flutter pre-battle

### The Change
- Implemented room-code UX in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` for `PEMAIN` mode, following `apps/games/index.html` multiplayer pattern:
  - added `ROOM PLAYER` panel when online mode is selected
  - added `Buat Room` action that generates a 6-char room code
  - added room code input field (uppercase, max 6)
  - shows generated code hint (`Kode dibuat: ...`).
- Updated start-battle guard for online mode:
  - `MASUK ARENA` now requires a valid room code (min 4 chars) before continuing
  - shows floating warning snackbar if code is missing/invalid.
- Converted `_PreBattleSection` from stateless to stateful to manage room-code UI state.

### The Reasoning
- You requested parity with teammate web flow where VS Player requires room-code input/join behavior.
- This enables frontend validation and user flow now, while backend/socket room wiring can be integrated later.

### The Tech Debt
- Room code is UI/local state only; it is not yet sent to backend matchmaking/session APIs.
- `Buat Room` currently generates local mock code and does not represent a real hosted room lifecycle.

## 2026-03-19 - PvP player room-code moved to popup (overflow fix)

### The Change
- Refactored pre-battle online-room UX in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` to remove the inline room panel from the page body.
- `MASUK ARENA` flow now behaves as requested:
  - `BOT` mode starts directly
  - `PEMAIN` mode opens a room-code popup dialog before starting.
- Added room-code dialog actions:
  - `Buat Room` (generate 6-char code)
  - input/join code field (uppercase, max 6)
  - validation (`min. 4` chars) before entering arena.
- Updated info-strip copy for player mode to explain the popup flow.

### The Reasoning
- The inline room block caused severe vertical overflow on target device height.
- Moving online-code flow into a dialog preserves the same pre-battle layout footprint as bot mode while keeping room behavior available.

### The Tech Debt
- Room code remains local/mock state and still needs real backend room lifecycle integration.
- Dialog style currently uses standard AlertDialog; can be themed later for stronger PvP visual consistency.

## 2026-03-19 - PvP room-code validation update (prototype + generated code)

### The Change
- Updated player room popup validation in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`:
  - now accepts either fixed prototype code `1234`
  - or generated `Buat Room` code from the same dialog.
- Replaced dialog validation snackbar path with inline `errorText` inside the dialog input.
- Added helper hint text in dialog describing valid code options.

### The Reasoning
- You requested `1234` to be one valid option while still supporting generated controller-style room code.
- Inline dialog error feedback is safer and simpler than dispatching snackbar from popup flow.

### The Tech Debt
- Validation is still client-side mock logic; real room ownership/join checks should move to backend/game-service integration later.

## 2026-03-19 - PvP explicit invalid-code messaging

### The Change
- Updated room popup invalid-code error text in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` to explicit `Code not found` messaging.

### The Reasoning
- Makes the failure mode clear and prevents ambiguous behavior when a wrong room code is entered.

### The Tech Debt
- Error copy is still hardcoded; can be localized later with i18n resources.

## 2026-03-19 - PvP room-code validation tightened (remove 1234 bypass)

### The Change
- Removed fixed `1234` acceptance from player room popup validation in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`.
- Updated dialog helper text and invalid-code message to reference generated room code only.

### The Reasoning
- You requested removing the prototype bypass so room entry follows one consistent flow.

### The Tech Debt
- Generated code is still local session state and not yet backend-authoritative.

## 2026-03-19 - PvP room dialog lifecycle stabilization (back/error crash fix)

### The Change
- Refactored `_showRoomCodeDialog` in `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`:
  - removed temporary local dialog controller/dispose pattern
  - reused persistent `_roomCodeController` from widget state
  - wrapped dialog content in `SingleChildScrollView`.

### The Reasoning
- This reduces controller lifecycle race risk when dismissing dialog after invalid input and pressing back.
- Scrollable dialog content prevents keyboard-related overflow when input/error text expands.

### The Tech Debt
- Dialog logic is still inline in page file; extracting to a dedicated widget would further reduce state coupling.

## 2026-03-19 - Onboarding step 1 (app icon config + splash loading route)

### The Change
- Added onboarding splash/loading page:
  - `apps/mobile/lib/features/onboarding/presentation/pages/splash_page.dart`
  - Shows centered brand logo, `YUDHA` title, loading copy, and progress spinner.
  - Auto-redirects to lobby after `1.8s`.
- Added routing support for splash-first launch:
  - `apps/mobile/lib/app/router/app_routes.dart` adds `AppRoutes.splash`.
  - `apps/mobile/lib/app/router/app_router.dart` sets splash as `initialLocation` and registers splash route outside tab shell.
- Added launcher icon and native splash tooling config in `apps/mobile/pubspec.yaml`:
  - `flutter_launcher_icons`
  - `flutter_native_splash`
  - Configured with `assets/branding/logo-color.png` and cream background.
- Updated root widget test to reflect new startup flow:
  - `apps/mobile/test/widget_test.dart` now asserts splash first, then lobby.

### The Reasoning
- We need a brand-first onboarding entry before feature screens, even in the current prototype stage.
- Keeping splash route outside the tab shell avoids bottom-nav flashing during loading.
- Using package-based icon/splash tooling is faster and safer than manual platform file edits for hackathon iteration.

### The Tech Debt
- Icon/splash generators still need to be executed locally (`flutter pub get`, `dart run flutter_launcher_icons`, `dart run flutter_native_splash:create`) because this shell cannot run Flutter/Dart binaries.
- Splash duration is fixed (`1.8s`) and not yet tied to real app initialization/auth checks.

## 2026-03-19 - Launcher icon asset swap to `app-icon.png`

### The Change
- Updated `apps/mobile/pubspec.yaml` launcher icon config:
  - `image_path` -> `assets/branding/app-icon.png`
  - `adaptive_icon_foreground` -> `assets/branding/app-icon.png`
- Kept `adaptive_icon_background` and splash configuration unchanged.

### The Reasoning
- You added a dedicated icon asset and asked to use it as the app launcher icon source.
- Keeping splash unchanged preserves the current onboarding look while isolating icon updates.

### The Tech Debt
- Icon generation still needs to be rerun locally (`flutter pub get` and `dart run flutter_launcher_icons`) to apply this swap into Android resources.

## 2026-03-19 - First-time profile onboarding gate (name + target) and dynamic player naming

### The Change
- Added first-time profile identity flow:
  - New route `AppRoutes.profileSetup` (`/profile-setup`).
  - New page `apps/mobile/lib/features/profile/presentation/pages/profile_onboarding_page.dart` to collect:
    - display name
    - target belajar (`CPNS` or `BUMN`)
- Updated splash routing logic in `apps/mobile/lib/features/onboarding/presentation/pages/splash_page.dart`:
  - after splash delay, route to lobby if profile complete
  - otherwise route to profile setup.
- Extended profile state model:
  - Added `ProfileTarget` enum (`cpns`, `bumn`).
  - Added `displayName`, `target`, and `isProfileComplete` to `ProfileSettings`.
  - Added `completeProfile`, `setDisplayName`, and `setTarget` in `ProfileSettingsController`.
- Added progress sync hook:
  - Added `setDisplayName` in `PlayerProgressController`.
  - On profile setup submit, name is written to both profile settings and player progress state.
- Replaced hardcoded `Kamu` player labels in PvP presentation with dynamic profile name:
  - pre-battle arena avatar label
  - in-battle player HUD
  - result screen player score label.
- Added target editing section in profile page:
  - segmented control for `CPNS`/`BUMN`
  - active target label and target in profile header card.
- Updated tests to reflect new flow/state:
  - root widget test now expects splash -> profile setup on first load
  - profile page widget test adds target assertions
  - profile settings controller unit test adds complete profile case.

### The Reasoning
- You asked for first-time personalization right after splash, then full app personalization based on name.
- Gating setup from splash keeps the flow deterministic and avoids users reaching main tabs with anonymous placeholder identity.
- Keeping target in profile settings (instead of battle domain) keeps exam-path preferences separate from game logic.

### The Tech Debt
- Identity state is currently in-memory only; app restart will ask setup again until persisted (e.g., local storage).
- PvP battle engine status copy still contains hardcoded `Kamu` in domain-layer status messages; UI labels are already dynamic.
- We still need a local format/analyze/test run in your machine because Flutter/Dart binaries are unavailable in this shell.

## 2026-03-19 - Onboarding session consolidation summary

### The Change
- Consolidated overlapping onboarding notes into one mental grouping:
  - `Onboarding step 1 (app icon config + splash loading route)`
  - `Launcher icon asset swap to app-icon.png`
- Kept distinct onboarding milestone separate:
  - `First-time profile onboarding gate (name + target) and dynamic player naming`

### The Reasoning
- The two icon/splash entries describe the same implementation track (same files, same setup phase), with the second being a targeted asset correction.
- The profile gate entry is structurally different (new route, state model changes, UX flow, and personalization propagation), so it should remain independent.

### The Tech Debt
- Current onboarding history is now easier to scan, but persistence work is still pending (`displayName` and `target` are not yet stored locally).

## 2026-03-20 - Authentication UI (Login and Sign Up Parity)

### The Change
- Added a mocked `authProvider` in `lib/features/auth/application/auth_providers.dart` to simulate UI authentication state.
- Created `LoginPage` (`/login`) allowing users to enter Email and Password.
- Repurposed `ProfileOnboardingPage` (`/profile-setup`) into an explicit Sign Up flow by adding Email and Password fields before the Name and Target inputs.
- Updated `SplashPage` routing: now redirects unauthenticated users to `/login` immediately.
- Updated widget tests to reflect the new Splash -> Login default path.
- Configured "Login" button to bypass profile completion checks temporarily for mockup UI testing.

### The Reasoning
- We needed basic authentication UI flows (Login and Sign Up) to prepare for real backend/Firebase wiring.
- Converting the existing Profile Onboarding directly into a Sign Up page reduces the number of separate steps a user must take during account creation. 
- A simple mock `authProvider` prevents blocking UI work while the backend auth service is built.

### The Tech Debt
- Authentication is purely in-memory UI mock logic; it does not persist across hot restarts or interact with a real auth backend yet.
- Verification checks for email/password validity are purely checking for non-empty fields right now.
- `LoginPage` redirects directly to `AppRoutes.lobby` without verifying `isProfileComplete` due to mock constraints; real server connection will need to restore this flow accurately.

## 2026-03-20 - Leaderboard UI Polish (Hero & Podium Cards)

### The Change
- Completely rewrote `apps/mobile/lib/features/leaderboard/presentation/pages/leaderboard_page.dart`.
- Added `_HeroRankCard` to display the current user's Rank, Tier, POIN, WINRATE, STREAK, and an XP progress bar, matching the new Navy app bar layout.
- Extracted the top 3 leaderboard entries into a dedicated `_TopThreePodium` layout, with specialized styled cards (Rank 1 center gold, Rank 2 left grey-blue, Rank 3 right bronze).
- Updated `_LeaderboardTile` to act as "Other Ranks" starting from index 3, adding a special green highlight background and "KAMU" badge for the current user.
- Updated widget tests in `leaderboard_page_test.dart` to expect the new labels, checking for `Belum ada rekor minggu ini.` and the new podium item layout paths.

### The Reasoning
- Bringing the Rank page layout up to total visual parity with the provided high-fidelity design prototype `PAPAN PERINGKAT`.
- Extracting the podium component physically forces the top 3 items to be visually distinct and correctly elevated visually from the standard `ListView` flow.

### The Tech Debt
- XP values in the hero card (`120 / 400`) are currently hardcoded mock data as we don't have level progression boundaries mapped in the state yet.
- Top 3 Podium logic assumes the `entries` array is strictly sorted by points natively from the controller.

## 2026-03-20 - Leaderboard Scope Simplification & Static Rank Fix

### The Change
- Removed the `_ScopeToggle` (Global/Weekly segment button) entirely from `LeaderboardPage` to make the leaderboard purely Universal.
- Refactored `_normalizeEntries` in `LeaderboardController` to stop force-inserting the current user into the continuous array if their points haven't naturally beaten anyone in the loaded tier.
- Updated `LeaderboardPage` to fallback to a sticky `...` icon and a detached `Kamu` rank tile at the bottom of the `ListView`.
- Locked the "Kamu" fallback mock rank to precisely `#13` out of the global mocked database instead of using `entries.length + 1`.

### The Reasoning
- The Global/Weekly filter cluttered the UI when a purely Universal leaderboard better matches the high-fidelity mockups.
- Statically fixing the mock rank to `#13` resolves the "rank bouncing" UX flaw. Previously, evaluating rank dynamically off the visible page array meant paginating the list caused the artificial rank to inexplicably jump (e.g., #9 to #17). The static sticky tile natively mimics a professional "1-20 ... my position" layout exactly.

## 2026-03-20 - Practice & Interview UI Polish

### The Change
- Refactored `practice_page.dart` into a pure Dashboard that renders CPNS grids (TWK/TIU/TKP) or BUMN grids (SOAL KEMAMPUAN + Interview Prep) dynamically bound to the user's `ProfileSettings.target`.
- Isolated the active quiz execution flow into a dedicated `/practice/quiz` route (`practice_quiz_page.dart`), complete with "dashed-to-solid" hint mechanics, a custom animated progress AppBar, and stylized rounded option inputs.
- Scrapped the `FeaturePlaceholderPage` in `interview_page.dart` to unleash a robust 3-state BUMN Interview Simulator (`ready -> recording -> processing`).
- Built precision UI primitives for the Wawancara simulator: alternating `_ChatBubble` lists, an animated transforming Hero container (tracking "PERTANYAAN" to "JAWABAN"), and a dynamic `_buildBottomRecorderBar()` hot-swapping between the gold microphone, red simulated waveforms, and blue loading indicators.
- Injected synthetic testing data across the components and bypassed infinite loop widget hooks with hard duration `pump` functions to verify navigation stability.

### The Reasoning
- Disentangling the generic challenge pickers from the intricate Quiz gameplay and Interview sessions aligns the UI with the final product's UX. Creating rigid mock state machines (like `InterviewState.recording`) immediately paves the way for the real backend audio stream integration without touching the UI scaffolding ever again.

## 2026-06-02 - Mobile Interview AI Client Wiring

### The Change
- Added a dedicated mobile interview state/data layer under `apps/mobile/lib/features/interview/`:
  - launch config and chat/evaluation entities
  - backend repository for `POST /interview/sessions`, `POST /interview/sessions/:id/turns`, and session completion
  - Riverpod controller/provider family for session start, answer submit, completion, errors, and final summary state
- Replaced the mock interview recorder page with a typed chat client that starts an AI interview session, submits candidate answers, renders AI questions, shows coaching notes, and exposes compact chat history from the top-right history button.
- Added a dedicated "Latihan Interview AI" entry card to the Practice dashboard and passes CPNS/BUMN-specific company/role launch config into the interview route.
- Added `http` to the mobile dependencies and a unit test for the interview controller flow.
- Cleaned encountered analyzer issues in auth, leaderboard, and practice files; leaderboard hero XP now uses real tier progress values instead of unused mocked defaults.

### The Reasoning
- Backend already exposes the Interview AI workflow behind authenticated NestJS endpoints, so mobile should call the API rather than keep the old local mock state machine.
- Keeping the HTTP repository behind an `InterviewRepository` abstraction lets real Supabase auth token plumbing replace the temporary dart-define token source later without rewriting the page/controller.
- Passing `InterviewLaunchConfig` through route `extra` keeps Practice responsible for selecting the target company/role while keeping `InterviewPage` reusable.

### The Tech Debt
- Mobile auth is still a mock boolean and does not expose a Supabase access token. For now, the client reads `YUDHA_API_BASE_URL` and `YUDHA_SUPABASE_ACCESS_TOKEN` from dart defines; this should be replaced by real auth/session wiring.
- The Interview API has no mobile session list endpoint yet, so the history button shows only the current in-memory chat, not past saved sessions.
- The existing practice quiz widget test still hangs in isolation on this Windows test runner; the new interview controller test and the practice dashboard entry test pass.

## 2026-06-02 - Mobile Supabase Auth Foundation

### The Change
- Added `supabase_flutter` to the mobile app and initialized Supabase from dart defines in `AppBootstrap`.
- Extended `AppConfig` with `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `YUDHA_API_BASE_URL` dart-define values.
- Replaced the mock boolean auth provider with a Supabase-aware `AppAuthState`, exposing authenticated status and the active session access token through Riverpod providers.
- Updated Login and Sign Up flows to call Supabase auth APIs and surface loading/error states.
- Updated the Interview API config to use the logged-in Supabase access token instead of a temporary manual token define.

### The Reasoning
- Interview endpoints are guarded by Supabase auth, so mobile needs a real session/token foundation before replacing mocks across the app.
- Keeping credentials in dart defines avoids committing project credentials while still making local and CI/dev builds explicit.
- Exposing the access token through a small provider gives future backend repositories one shared place to read auth state.

### The Tech Debt
- Login and sign-up now authenticate with Supabase, but profile creation/sync still depends on backend/Supabase triggers and has not yet replaced the local profile settings cache.
- Auth route guarding is still lightweight; `SplashPage` checks auth once after a delay instead of using router-level redirects bound to auth state.
- Supabase credentials still need to be provided by each developer through local run configuration or CI secrets.

## 2026-06-03 - Real Profile Hydration for Mobile Progress

### The Change
- Added a backend-backed mobile profile/progress repository under `apps/mobile/lib/features/gamification/data/repositories/` for authenticated `GET /profile` requests.
- Wired `playerProgressProvider` to hydrate from the authenticated Supabase session token instead of relying on seeded mock stats.
- Replaced the old fake initial progression values with zeroed fallback defaults in `PlayerProgress.initial()`.
- Synced the backend `username` into local profile settings so the existing profile/lobby UI keeps one visible display name after hydration.
- Updated lobby rank progress rendering to use shared `PlayerProgress` tier getters instead of hardcoded `400`-point math.
- Updated and expanded gamification tests to cover backend hydration behavior.

### The Reasoning
- `GET /profile` already exists in backend API and returns the authoritative rank/stat fields, so mobile should consume that instead of shipping fake win/loss/point values.
- Hydrating through the existing Riverpod provider keeps lobby, profile, leaderboard, and PvP consumers on the same progress source without page-level network code.
- Keeping a zeroed fallback state is safer than showing fabricated stats when auth or network is unavailable.

### The Tech Debt
- Backend profile payload does not currently provide streak, best streak, or last delta, so those still start at `0` and only change from local runtime PvP actions.
- `ProfileSettings.target` is still local-only; backend profile hydration currently syncs the username but not exam target/preferences.
- Failed profile fetches currently fall back silently to local defaults. We should surface a lightweight sync/error state once more real backend-backed screens depend on the same data.

## 2026-06-03 - PlayerProgress Projection Boundary Tightening

### The Change
- Added a dedicated backend snapshot model for profile-owned progress fields in `apps/mobile/lib/features/gamification/data/models/player_progress_snapshot.dart`.
- Refactored the player progress repository contract to return the backend snapshot instead of returning the full `PlayerProgress` domain model directly.
- Updated the backend profile repository to map `/profile` JSON into the snapshot shape only.
- Added `mergeSnapshot(...)` to `PlayerProgress` so the mobile domain model remains the projection that combines backend-owned fields with client-owned runtime fields.
- Exposed `hydrateFromRepository()` on `PlayerProgressController` and updated tests to verify backend hydration preserves local-only fields like `streak`, `bestStreak`, and `lastDelta`.

### The Reasoning
- We chose the “local domain projection” model intentionally: backend owns persisted identity/rank/match counts, while mobile still owns runtime-only values that are not yet part of the backend contract.
- Returning a snapshot from the repository prevents the backend response shape from quietly becoming the app state shape.
- Merging snapshots into `PlayerProgress` keeps UI code stable and makes future backend additions easier to absorb without rewriting feature screens.

### The Tech Debt
- The projection boundary is now explicit, but we still need to decide whether streak-related fields should eventually be server-authoritative once match syncing is implemented.
- `target` and other profile preferences still live in separate local settings state, so profile identity is cleaner now but not yet fully unified.

## 2026-06-03 - Practice Dashboard Data Made Repository-Driven

### The Change
- Added practice dashboard domain entities for repository-driven progress and recent activity:
  - `practice_dashboard.dart`
  - `practice_recent_activity.dart`
- Extended `PracticeTopic` with repository-owned dashboard metadata (`groupTitle`, `badgeLabel`, `questionCount`) so the Practice page no longer hardcodes CPNS/BUMN card grids in the widget tree.
- Refactored `PracticeRepository` to expose `fetchDashboard(target)` plus topic question loading.
- Added `BackendPracticeRepository` as the default mobile repository, expecting backend endpoints for:
  - `GET /practice/dashboard?target=...`
  - `GET /practice/topics/:id/questions`
- Kept the existing local practice data as a fallback inside the backend repository so the app still renders while backend practice endpoints do not yet exist.
- Updated `PracticeController` and `PracticeState` to load and store repository-provided dashboard progress, question of the day, and recent activity.
- Rewrote `PracticePage` to render grouped topic sections and recent activity from state instead of hardcoded tile data.

### The Reasoning
- The immediate goal was to remove UI-owned fake data from the Practice screen without blocking the mobile branch on missing backend endpoints.
- Making the backend repository the default provider gives us one clean cutover path once the API is ready, while the seed fallback keeps the feature usable during the transition.
- Moving section labels, counts, and recent activity into repository data makes the page honest about where its content comes from and keeps future product changes out of the widget layout.

### The Tech Debt
- `apps/backend-api` still does not expose a practice module, so the current backend repository falls back to seeded local data on request failure.
- Practice progress and recent activity are repository-driven now, but the fallback values are still static seed data until real backend responses exist.
- The practice widget test continues to hang on this Windows runner in its second case after rendering `renders practice quiz page and transforms hint`; analyzer and practice unit tests pass, so this should be revisited separately as a test-runner issue.

## 2026-06-03 - Leaderboard Made Backend-First With Real Rank Support

### The Change
- Added a backend-first leaderboard repository in `apps/mobile/lib/features/leaderboard/data/repositories/backend_leaderboard_repository.dart`.
- Updated the leaderboard payload model to support real current-user metadata from API responses:
  - `currentUserRank`
  - `currentUserEntry`
- Extended leaderboard state to store repository-provided current-user rank/entry instead of relying on page-local prototype values.
- Refactored `LeaderboardController` so synthetic current-user insertion only happens when the repository does not provide current-user leaderboard data.
- Replaced the page-level fixed `#13` prototype rank in `leaderboard_page.dart` with repository/state-driven rank handling.
- Switched the default mobile provider from `MockLeaderboardRepository` to the backend-first repository, while keeping the mock repository as fallback data until the backend endpoint exists.

### The Reasoning
- The leaderboard feature already had a repository/controller split, so the highest-value cleanup was to move user-rank ownership into the data layer and remove page-owned prototype behavior.
- Real leaderboard APIs often return both a visible page of ranked users and a separate current-user rank that may live outside the current page window. The payload/state needed to express that directly.
- Keeping the mock repository only as a fallback preserves the current experience while making the mobile app ready to consume a real leaderboard endpoint without another UI rewrite.

### The Tech Debt
- `apps/backend-api` still does not expose a leaderboard endpoint, so the backend-first repository currently falls back to the mock repository on request failure.
- The current fallback still reports prototype-style user rank data, but it now does so through the repository payload instead of hardcoded widget logic.

## 2026-06-03 - Online PvP Wired to Backend-Game Socket Match Flow

### The Change
- Added a dedicated mobile online-match bridge for PvP:
  - `apps/mobile/lib/features/pvp/data/repositories/online_battle_repository.dart`
  - `apps/mobile/lib/features/pvp/data/repositories/socket_online_battle_repository.dart`
  - `apps/mobile/lib/features/pvp/domain/entities/online_battle_update.dart`
- Added `socket_io_client` to `apps/mobile/pubspec.yaml` and introduced `YUDHA_GAME_BASE_URL` in `apps/mobile/lib/app/config/app_config.dart` with the backend-game default `http://10.0.2.2:3001`.
- Rewired `battle_providers.dart` so online PvP now uses the authenticated Supabase access token and connects to the real `/match` Socket.IO namespace instead of the old seeded `MockQuestionBank`.
- Split `BattleController` behavior by mode:
  - bot mode still uses the local `BattleStateMachine`
  - online mode now queues through backend-game, opens cards through the gateway, submits answers to the server, and updates UI state from `queue_joined`, `match_found`, `game_state_update`, `play_card_result`, `match_result`, and presence/error events.
- Updated `BattleQuestion` so `correctOptionIndex` can be absent for server-owned cards, and adjusted the PvP question sheet in `pvp_page.dart` to stop grading online answers locally.
- Removed the old fake room-code start flow from the PvP page and changed the online entry copy to queue-based matchmaking.
- Updated the PvP widget test to use a controller-driven setup that remains stable after the online/bot split.

### The Reasoning
- `backend-game` already owns the real online match lifecycle through Socket.IO, so the mobile app should stop pretending online PvP is just another local question seed.
- Keeping bot mode on the existing local state machine avoids destabilizing the offline/demo-friendly path while we wire online mode to server-authoritative actions.
- The backend intentionally does not expose the correct answer in public card payloads, so the mobile question UI needed to stop validating online answers client-side for fairness.
- Introducing a small online repository boundary keeps the socket/event mapping isolated from the battle page and makes future backend-game contract changes easier to absorb.

### The Tech Debt
- Online PvP is now wired to the real socket flow, but backend-game still serves seeded local questions in `QuestionService`; the content source is backend-owned, not yet database-backed.
- The current online result mapping still derives mobile rating delta locally (`+20/-12/0`) because backend-game does not yet return a dedicated rating delta payload.
- Opponent identity in mobile currently falls back to a shortened user-id label because the match payload does not provide a display name.
- `flutter analyze` still reports older lint drift inside `pvp_page.dart` (deprecated color channel API usage and unused legacy elements) that predates this socket wiring pass.

## 2026-06-03 - Interview Session History Wired to Backend Sessions API

### The Change
- Extended the mobile interview repository contract to support backend-backed session browsing:
  - `listSessions()`
  - `getSession(sessionId)`
- Added new interview session record models in `apps/mobile/lib/features/interview/domain/entities/interview_session_record.dart` for:
  - session summaries from `GET /interview/sessions`
  - session transcript/detail from `GET /interview/sessions/:sessionId`
- Updated `BackendInterviewRepository` to:
  - call the new sessions list endpoint
  - call the session detail endpoint
  - map backend turns into existing `InterviewMessage` chat entities
  - preserve evaluations/final summaries for completed coaching sessions.
- Added Riverpod async providers in `interview_providers.dart` for interview history list and per-session detail loading.
- Reworked the top-right history action in `interview_page.dart`:
  - it now opens a backend-backed session list instead of showing only current in-memory messages
  - tapping a session opens a transcript/detail bottom sheet with final score summary and per-turn coaching notes when available.
- Added repository parsing tests for the new list/detail endpoints and updated the existing interview controller fake repository to satisfy the expanded contract.

### The Reasoning
- Backend now owns real session persistence, so the mobile history UI should stop pretending that “history” only means the current chat already loaded in memory.
- Keeping live interview chat in the existing `InterviewController` while moving history browsing into dedicated async providers keeps the active session flow stable and avoids mixing historical transcript loading with answer-submission state.
- Reusing the existing `InterviewMessage` entity for transcript detail keeps the transcript UI visually consistent with the active chat page and reduces mapping duplication.

### The Tech Debt
- Opening a past session currently shows a transcript/detail sheet rather than fully restoring that session into the live interview screen. That was the safer first cut because the screen config still comes from the route launch payload.
- Session summaries currently display `companyId` in humanized form because the list endpoint does not yet return a friendly company display name.
- The active chat screen and history detail sheet now share transcript semantics, but not a shared reusable widget yet; that can be extracted later if the interview UI keeps growing.

## 2026-06-03 - Leaderboard Wired to Backend List and My-Rank Endpoints

### The Change
- Updated the mobile leaderboard backend repository to consume the real backend-api contract:
  - `GET /leaderboard?limit=...&offset=...`
  - `GET /leaderboard/me`
- Mapped backend leaderboard rows into the existing mobile `LeaderboardEntry` model using backend-owned fields:
  - `userId`
  - `username`
  - `rankPoints`
  - `winrate`
  - `streak`
- Marked the current user directly from the backend `/leaderboard/me` response so the loaded leaderboard can recognize the user row without fabricating it locally.
- Kept the existing mock leaderboard repository as a fallback only when the backend request path fails.
- Updated the leaderboard hero card to prefer server-provided current-user rank data when available, while still falling back to local player progress for display if the backend payload is missing.
- Added a repository test covering both the list endpoint and the `me` endpoint merge behavior.

### The Reasoning
- The backend leaderboard module now owns the ranking contract, so the mobile client should consume the authoritative list and the authoritative current-user rank instead of inventing either on the page layer.
- Using a separate `/leaderboard/me` call matches the backend shape cleanly and avoids guessing current-user position from the visible page window.
- Keeping the fallback repository in place preserves app usability in local/offline cases without making the fake behavior the primary path anymore.

### The Tech Debt
- The controller still contains a legacy fallback path that can synthesize the current user from local progress if backend current-user data is absent. That is useful as a safety net, but it is still local logic.
- The leaderboard page still keeps the existing `scope` state machinery even though the backend module is currently global-only. We can trim that once we decide whether the UI should keep a scope toggle at all.

## 2026-06-03 - PvP Arena Menu Duplicate Class Fix

### The Change
- Removed the stale in-file `_ArenaMenuSection` implementation from `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart`.
- Kept `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/arena_menu_section.dart` as the single source of truth for the arena menu part implementation.
- Verified the duplicate class symbols are gone and reran `flutter analyze` on `lib/features/pvp/presentation/pages/pvp_page.dart`, which now completes without the previous frontend compiler crash.

### The Reasoning
- `pvp_page.dart` already declares `part 'pvp_page/arena_menu_section.dart';`, so keeping another private `_ArenaMenuSection` and `_ArenaMenuSectionState` inside the same library created duplicate canonical names.
- The Dart frontend crash was a library-structure issue rather than a Gradle issue, so the safest fix was to remove only the duplicated block and preserve the split part-file architecture already in place.

### The Tech Debt
- `flutter analyze` still reports pre-existing warnings and deprecation infos in `pvp_page.dart` unrelated to this crash, including deprecated color channel accessors and a few unused private elements/parameters.
- The large `pvp_page.dart` library remains easy to regress when widgets are split out incrementally; if we keep refactoring it into `part` files, we should continue cleaning up the original file immediately after extraction to avoid duplicate declarations.

## 2026-06-03 - PvP Split Part Duplicate Cleanup

### The Change
- Trimmed `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` down to the shared imports/constants, `part` declarations, and the `PvpPage` orchestration widget.
- Removed the remaining stale copied declarations for the question sheet, arena entry, in-battle scene, result status section, and their helper widgets/painters from the main library file.
- Ran `dart format` on the PvP page library and part files after the cleanup.
- Ran `flutter pub get` to refresh local package resolution, then verified `flutter analyze lib/features/pvp/presentation/pages/pvp_page.dart` and `flutter build apk --debug` both pass.

### The Reasoning
- The next compiler crash showed `_InBattleSectionState` had the same duplicate canonical-name problem as the arena menu.
- Because all extracted sections were already included with `part` directives, the clean fix was to keep one declaration owner per private class: the dedicated part file.
- Clearing all stale copied sections at once prevents the compiler from surfacing the same failure repeatedly for the next duplicated state/helper class.

### The Tech Debt
- The PvP page is now structurally cleaner, but the part-file library is still large and tightly coupled through private declarations. A future pass could split this into public widgets with explicit imports once the UI stabilizes.

## 2026-06-03 - Auth Signup Error Visibility

### The Change
- Updated `apps/mobile/lib/features/auth/application/auth_providers.dart` so unexpected login/signup exceptions are logged and surfaced with a more useful banner message instead of always collapsing into the generic "Gagal ... Coba lagi beberapa saat." fallback.
- Added a friendlier connectivity-specific message for socket/client/host-lookup failures during Supabase auth requests.

### The Reasoning
- The registration flow in the Flutter app talks directly to Supabase Auth, not to `backend-api`, so a generic fallback hid the real failure mode and made local debugging harder.
- Preserving unexpected exception text lets us distinguish between Supabase validation errors and runtime/config/network issues on-device.

### The Tech Debt
- This improves visibility, but it does not change the underlying auth architecture. Mobile signup/login still bypass the backend auth controller entirely.

## 2026-06-03 - ProfileTarget Signup Type Fix

### The Change
- Updated `apps/mobile/lib/features/auth/application/auth_providers.dart` to accept `ProfileTarget?` in `signUp(...)` instead of `dynamic`.
- Kept the Supabase signup payload using `target.name`, but now with a statically typed enum value so the getter resolves correctly.

### The Reasoning
- `ProfileTarget` is an enum, but `target?.name` was being invoked through a `dynamic` parameter. That turns the enum-name access into a runtime dynamic call, which caused `NoSuchMethodError` on registration.
- Typing the parameter correctly lets Dart resolve the enum `name` getter at compile time and removes the runtime crash.

### The Tech Debt
- The auth provider still serializes target metadata inline for Supabase user data. If this payload grows, a small dedicated mapper would make the contract clearer.

## 2026-06-03 - Lobby Hero Stat Layout Cleanup

### The Change
- Removed the temporary settings button from `apps/mobile/lib/features/lobby/presentation/pages/lobby_page.dart` now that profile settings already live on the profile screen.
- Moved streak into the hero card stat row so winrate, streak, and points are shown together at the same visual level.
- Simplified the top of the lobby layout by removing the separate streak chip/header row.

### The Reasoning
- The old top row split related player stats across two different surfaces and kept a settings shortcut that duplicated the profile destination conceptually.
- Grouping winrate, streak, and points in one row makes the hero card feel more intentional and keeps the player summary easier to scan.

### The Tech Debt
- The lobby hero card still owns several responsibilities at once: identity, tier progress, and headline stats. If the lobby grows further, it may be worth splitting that card into smaller presentational widgets.

## 2026-06-03 - Profile Logout Action

### The Change
- Added a logout button below the haptic feedback toggle in `apps/mobile/lib/features/profile/presentation/pages/profile_page.dart`.
- Wired the button to the existing `authProvider.logout()` flow and redirected back to the login route after sign-out.

### The Reasoning
- Once profile became the home for account-level controls, logout belonged there as a direct action instead of being hidden elsewhere or left unavailable.
- Placing it beneath the toggle group keeps account exit behavior close to the rest of profile controls without mixing it into the performance section.

### The Tech Debt
- Logout currently returns to the login route immediately after local sign-out. If we later add remote session management, account switching, or sign-out confirmation, this action may need a dedicated flow.

## 2026-06-03 - Profile Logout Confirmation Overlay

### The Change
- Added a confirmation dialog to the logout action in `apps/mobile/lib/features/profile/presentation/pages/profile_page.dart`.
- The logout button now asks the user to confirm before calling `authProvider.logout()` and routing back to login.

### The Reasoning
- Logout is a high-impact account action, so it benefits from a small confirmation pause to prevent accidental taps.
- Reusing a styled dialog keeps the interaction consistent with the rest of the app's modal treatment while preserving the existing logout flow.

### The Tech Debt
- The confirmation copy and button states are still static. If we later introduce async logout progress, cross-device sessions, or destructive-action patterns app-wide, this dialog should likely move into a shared confirmation component.

## 2026-06-03 - Auth Form Input Guards

### The Change
- Added a shared auth input validator in `apps/mobile/lib/features/auth/presentation/auth_input_validators.dart`.
- Updated both `apps/mobile/lib/features/auth/presentation/pages/login_page.dart` and `apps/mobile/lib/features/profile/presentation/pages/profile_onboarding_page.dart` to validate email format and minimum password length before submit.
- Email now requires a valid `name@provider.domain` shape, and password now requires at least 6 characters.

### The Reasoning
- The login and signup forms previously only checked for non-empty fields, which let obvious invalid input travel all the way to the auth request layer.
- Sharing one validator keeps login and signup behavior aligned and makes future auth input rules easier to update in one place.

### The Tech Debt
- The current email validation is intentionally lightweight and regex-based. If the auth UX gets more complex later, we may want richer per-field validation states or localized rule messaging.

## 2026-06-03 - Auth Error Localization And Reset

### The Change
- Translated Supabase's `Invalid login credential` auth message into Indonesian in `apps/mobile/lib/features/auth/application/auth_providers.dart`.
- Added a shared `clearError()` path on the auth notifier so the login/register pages can clear stale banner state when the user switches screens.
- Cleared the shared auth error state when entering or switching between login and signup screens so a login failure no longer leaks into the register page.

### The Reasoning
- Login and registration share the same auth notifier, so a failure on one screen can remain visible on the other unless we intentionally reset it.
- Mapping the most common credential error into Indonesian makes the app feel more local and avoids surfacing backend phrasing directly to users.

### The Tech Debt
- The auth error mapping is still string-based for the Supabase response message. If we need broader localization later, we may want a small auth error translation layer instead of branching on raw message text.

## 2026-06-03 - Auth Error Reset Timing Fix

### The Change
- Deferred the login/register `clearError()` calls with `WidgetsBinding.instance.addPostFrameCallback(...)` in `apps/mobile/lib/features/auth/presentation/pages/login_page.dart` and `apps/mobile/lib/features/profile/presentation/pages/profile_onboarding_page.dart`.

### The Reasoning
- Clearing the shared auth provider directly in `initState` caused a Riverpod mutation-during-build error on screen entry.
- Moving that reset to the first post-frame callback preserves the stale-banner cleanup behavior without mutating provider state during widget construction.

### The Tech Debt
- The auth pages still coordinate shared notifier cleanup from the UI layer. If auth screen transitions grow more complex later, this reset behavior may be cleaner as router-level or notifier-owned navigation state handling.

## 2026-06-03 - Email Confirmation Auth Flow

### The Change
- Added a dedicated confirm-email screen at `apps/mobile/lib/features/auth/presentation/pages/email_confirmation_pending_page.dart` and routed it through `AppRoutes.confirmEmail`.
- Updated signup so a created-but-not-yet-confirmed account no longer proceeds into the app; it now routes to the confirmation screen when Supabase returns a user without a session.
- Localized the unconfirmed-email login failure into Indonesian and added a shortcut from the login page to the confirm-email screen for already-registered but unverified users.

### The Reasoning
- The app previously treated signup as fully complete even when Supabase still required email verification, which left the next user action to fail with a raw auth error.
- A dedicated confirmation step makes the flow legible both for brand-new signups and for users who already created an account but have not clicked the verification email yet.

### The Tech Debt
- The current confirmation UX is informational only. If we want a smoother recovery path later, the next improvement would be adding resend-confirmation support from the app.

## 2026-06-04 - Resend Confirmation Email Action

### The Change
- Added `resendConfirmationEmail(...)` to `apps/mobile/lib/features/auth/application/auth_providers.dart`, backed by Supabase Auth `resend` for signup confirmation emails.
- Upgraded `apps/mobile/lib/features/auth/presentation/pages/email_confirmation_pending_page.dart` into a stateful auth screen with a resend button, loading state, and inline success/error feedback.

### The Reasoning
- The confirmation screen already explained what to do next, but it still left the user stuck if the original verification email never arrived.
- Adding resend directly on the screen makes the confirm-email flow self-recovering without forcing the user to leave the app or restart signup.

### The Tech Debt
- The resend flow currently reports status inline on the confirmation page only. If we expand account recovery later, it may make sense to centralize confirmation and resend messaging across auth screens.

## 2026-06-04 - Confirmation Page Copy Polish

### The Change
- Reworded the email verification page copy in `apps/mobile/lib/features/auth/presentation/pages/email_confirmation_pending_page.dart` into more natural Indonesian, including the title, instructions, resend success message, and return-to-login button label.

### The Reasoning
- The confirmation flow already worked, but the wording still felt partly translated instead of written for Indonesian-speaking users.
- Tightening the copy makes the next-step instructions easier to follow, especially for first-time signup and resend scenarios.

### The Tech Debt
- The confirmation copy is now more consistent, but the rest of the auth funnel still mixes a few product-specific English terms with Indonesian UI text. A broader copy pass would make the experience feel more unified.

## 2026-07-20 - Arena Visual Rebuild And Real-Time Card Flow

### The Change
- Rebuilt the arena entry, mode selection, battle board, question sheet, and result state around a simpler clay-like chibi visual system documented in `docs/design/GAME-DESIGN.md`.
- Replaced the legacy battle PNG set with ten generated hero, tower, turret, and category-card assets under `apps/mobile/assets/game/`, then added larger towers, lane stones, shrubs, river banks, team zones, and a wider bridge to the live arena.
- Added distinct effects per category: an arcing electric bolt for Numerik, a wavy speech spell for Verbal, a fast spinning puzzle core for Logika, and a protective leaf bloom for TWK.
- Kept bot turns active while the question sheet is open. The selected question is temporarily reserved so the bot can consume another card without stealing the question being answered, and the sheet closes safely if the match ends underneath it.
- Recycled exhausted question cards while a battle is still active and added controller/state-machine/widget regressions for recycling, reservation, and real-time bot damage.

### The Reasoning
- The previous arena mixed many small decorative sprites and generic combat effects, which made the board feel busy yet visually empty at its focal points. Larger landmarks and a smaller set of repeated clay props give the field a clearer hierarchy.
- Opening a card is part of the combat interaction, not a pause state. Reserving only that card preserves the real-time rule while preventing the UI and bot from resolving the same question concurrently.
- Category-specific shapes, colors, and trajectories make attacks readable from motion alone and give each card a stronger gameplay identity.

### The Tech Debt
- The projectile effects are currently Flutter-drawn rather than authored as reusable animation files. If combat timing or art direction grows substantially, moving them to a dedicated animation format would make iteration easier.
- The arena has behavioral widget coverage but no screenshot/golden baseline yet, so future visual changes still need an emulator pass across the supported phone sizes.

## 2026-07-20 - AI Interview Setup, Text Fixes, And Voice Wiring

### The Change
- Added a pre-interview setup flow in `apps/mobile/lib/features/interview/presentation/pages/interview_setup_page.dart` and routed Practice through `/interview/setup` before launching the chat screen.
- Extended `InterviewLaunchConfig` with `responseStyle`, passed it through `BackendInterviewRepository.startSession(...)`, and stopped hardcoding interview sessions to text mode.
- Added `audioAvailable` to `InterviewMessage` and preserved backend audio availability when mapping live questions and historical transcript turns.
- Updated the interview screen with voice-mode affordances:
  - speaker playback on interviewer bubbles via `just_audio`
  - microphone recording/transcription via `record`
  - transcript review in the existing answer composer before submit.
- Improved text-mode bugs from the AI Interview plan: `_humanizeCompanyId(...)` now handles hyphenated slugs, completed sessions hide the composer behind a finished-session banner, and retry resumes an existing session when possible instead of always creating a new one.
- Expanded the interview repository/controller contract with session resume, STT upload, and question audio URL helpers, plus a controller regression test for retry/resume behavior.

### The Reasoning
- The backend already exposes `responseStyle`, speech transcription, and question-audio endpoints, so the frontend needed to stop flattening every interview into the old hardcoded text path.
- Putting company, mode, and response-style selection in a setup screen keeps the interview chat focused on the session itself while giving the backend the right launch payload up front.
- Treating voice capture as transcript-first keeps the answer submission contract unchanged: audio becomes editable text, then flows through the same `submitAnswer(...)` path as typed answers.
- Resuming by `sessionId` on retry is safer than blindly starting over because network failures can happen after the backend has already created a session.

### The Tech Debt
- The setup company list is static and should eventually come from backend-owned `interview_company_profiles` data.
- Voice playback/recording needs emulator/device verification, especially Android microphone permission behavior, temp-file handling, and authenticated audio streaming headers.
- The current audio UI is functional but local to `interview_page.dart`; if voice mode grows, playback and recording should move into smaller reusable widgets/services.
- Dependency resolution for `record` needs a follow-up check because the current locked Linux plugin/platform-interface combination can fail Dart compilation even when building Android.

## 2026-07-20 - AI Interview Compile Error Fixes

### The Change
- Added the missing `InterviewSessionDetailRecord` import to `apps/mobile/lib/features/interview/application/interview_controller.dart` so retry/session-resume code can see the detail model.
- Updated `apps/mobile/pubspec.yaml` from `record: ^5.2.0` to `record: ^6.2.1` and refreshed `apps/mobile/pubspec.lock`, moving the package graph to `record_linux 1.3.1` with `record_platform_interface 1.6.0`.

### The Reasoning
- `InterviewSessionDetailRecord` already existed in the interview domain layer; the controller compile error was just a missing import after adding retry/resume behavior.
- The previous `record 5.2.1` graph allowed an incompatible mix of `record_linux 0.7.2` and `record_platform_interface 1.6.0`, where Linux did not implement the newer interface methods. `record 6.2.1` keeps the app within the current Dart SDK constraint while resolving Linux to an implementation that matches the newer platform interface.

### The Tech Debt
- Sandbox validation could not complete because local Flutter/Dart commands either hung through the shell shim or exited after dependency resolution while trying to write Dart telemetry outside the workspace. The next local check should be `flutter pub get`, then `flutter analyze`, then `flutter run` on the Android emulator.

## 2026-07-20 - AI Interview Analyzer Cleanup

### The Change
- Replaced the deprecated `DropdownButtonFormField.value` usage with `initialValue` in `apps/mobile/lib/features/interview/presentation/pages/interview_setup_page.dart`.
- Updated the interview controller test fake repository to implement the new voice contract methods: `transcribeAnswerAudio(...)` and `getQuestionAudioUrl(...)`.

### The Reasoning
- Flutter 3.33 deprecated `value` for form-field initial state, so the setup screen needed the new API to keep analyzer clean.
- The repository abstraction expanded for voice mode, and test doubles must implement the full interface even when a test only exercises text/retry behavior.

### The Tech Debt
- The fake repository returns static voice responses. Broader voice-flow tests should cover transcription success/failure and question-audio URL behavior once the emulator path is stable.

## 2026-07-21 - Debug Cleartext Audio Playback Allowance

### The Change
- Added a debug-only Android network security config at `apps/mobile/android/app/src/debug/res/xml/debug_network_security_config.xml`.
- Updated `apps/mobile/android/app/src/debug/AndroidManifest.xml` so debug builds permit cleartext HTTP traffic to local development hosts used by the emulator.

### The Reasoning
- Interview TTS playback streams audio through `just_audio`/ExoPlayer from the local NestJS backend during development.
- Android blocks cleartext HTTP media by default, so local `http://10.0.2.2:3000` audio URLs failed even though the backend route and auth flow were reachable.
- Keeping this in the debug source set avoids loosening release networking policy.

### The Tech Debt
- Production audio playback should use HTTPS URLs. If we add staging builds, they should get their own explicit network-security policy instead of reusing debug allowances.

## 2026-07-21 - Voice Interview Room UI

### The Change
- Added a voice-mode room surface in `apps/mobile/lib/features/interview/presentation/pages/interview_page.dart` for sessions launched with `responseStyle == 'voice'`.
- Replaced the voice-mode transcript list area with a navy/teal visual panel containing:
  - current listening/thinking state copy
  - a simple animated audio visualizer orb
  - the current interviewer question
  - a compact latest-answer preview
  - the existing TTS play action for the current question.
- Kept the existing bottom answer composer available in voice mode so users can either record speech or type manually.
- Synced recorder start/stop events into `InterviewState.isRecording` so the voice room can react while the mic is active.

### The Reasoning
- Voice mode needed to feel distinct from text chat without changing the underlying interview flow.
- The room layout keeps the primary interaction focused on listening/responding while preserving the typed fallback at the bottom.
- Using existing brand colors avoids introducing a purple voice-assistant theme that would clash with the YUDHA visual system.

### The Tech Debt
- The visualizer is decorative and timer-driven; it does not yet react to live microphone amplitude.
- The transcript/history still exists in text mode and history sheets, but voice mode does not currently expose an inline full transcript while the session is active.

## 2026-07-21 - Practice Session Backend Wiring

### The Change
- Replaced the practice dashboard's obsolete topic-question requests with the authenticated NestJS practice contract for dashboard loading, five-question session creation, per-answer submission, and session finishing.
- Removed `mock_practice_repository.dart` and all production fallback behavior so backend, authentication, timeout, and payload failures now surface as explicit retryable errors.
- Added server-session entities and state for session IDs, locked questions, answer explanations, correct-option feedback, response timing, and final server summaries.
- Updated the practice dashboard to create sessions from backend categories/subcategories and removed the unsupported mock-only daily challenge.
- Updated the quiz flow to send `responseTimeMs` and `usedHint`, wait during answer submission, render server-owned correctness/explanations, and show the final accuracy, correct count, and score.
- Replaced practice tests that depended on the deleted seed repository with test-local repository fakes covering session creation, response-time submission, completion, dashboard rendering, and hint display.

### The Reasoning
- A silent fallback made backend outages look like valid practice content and obscured whether PRD #3 was actually integrated.
- The backend owns question selection and correctness, so the frontend now treats the returned five-question set as locked and never embeds correct answers before submission.
- Response time starts when each server question becomes active and is sent with that answer, while the final answer response remains a summary fallback if the separate finish request is interrupted.

### The Tech Debt
- Hint ad/purchase monetization remains out of scope; the current hint is an optional reveal whose usage is reported to the backend.
- The backend dashboard does not expose a question-of-the-day payload, so that UI is hidden until a real server contract exists.
- Practice session resume is not yet wired to the dashboard's `activeSession`; starting a category currently creates a fresh server session.
- Targeted analysis reached only three cleanup findings before the Windows Dart telemetry permission failure; those findings were patched, but a final local `flutter analyze` and manual emulator pass are still required.

## 2026-07-22 - Practice Identifier Display Formatting

### The Change
- Humanized backend-owned practice category and subcategory identifiers when mapping dashboard topics, quiz topic labels, and recent-session titles.
- Converted snake_case, kebab-case, and lowercase identifiers into readable title case while preserving known acronyms such as `TWK`, `TIU`, `TKP`, `CPNS`, `BUMN`, and `AKHLAK`.
- Added a backend repository regression test proving that display labels are humanized while session creation still sends the original raw category and subcategory identifiers.

### The Reasoning
- Backend identifiers are stable API values and must remain unchanged in request payloads, but rendering them directly produced lowercase labels such as `kepribadian` and `pelayanan_publik`.
- Keeping formatting at the repository mapping boundary gives every practice screen consistent display values without coupling UI widgets to backend naming conventions.

### The Tech Debt
- The formatter handles identifier-style labels, not arbitrary localized copy. If the backend later exposes dedicated localized display labels, those should replace frontend-derived labels.
- Targeted analysis reported no issues before the known Dart telemetry permission failure. The targeted Flutter test runner timed out without producing output on this Windows environment and still needs local confirmation.

## 2026-07-23 - AI Interview Feedback, Results, And Voice Recovery

### The Change
- Replaced invalid interview setup company IDs with six reviewed backend company profiles and complete human-facing company names and default roles.
- Preserved the backend's six evaluation dimensions, candidate facts, and suggested rewrite in the mobile domain mapping.
- Expanded coaching feedback into a compact, optional detail view with readable score dimensions, strengths, improvements, and a suggested answer rewrite.
- Added a dedicated completed-session result view with overall score, dimension breakdown, strengths, improvement areas, latest rewrite, and clear navigation actions.
- Humanized company and interview-mode identifiers across active sessions, history, and session details.
- Added friendly timeout and API failure copy at the repository boundary so backend implementation details no longer appear in the interface.
- Hardened voice mode with local permission guidance, transcription retry, temporary recording cleanup, guarded recorder actions, playback retry, and audio subscription cleanup while keeping typed answers available.
- Added regression coverage for the reviewed company catalog, complete evaluation mapping, summary dimensions, and non-blocking transcription failures.

### The Reasoning
- The setup picker must send IDs that the backend can actually resolve; displaying known-good profiles avoids a session failing only after the user finishes setup.
- Coaching data is useful when it is progressively disclosed. A short summary keeps the conversation readable, while deeper feedback remains one tap away.
- Voice features are an optional input path, so microphone, transcription, or playback failures should stay close to those controls and must not make the entire interview look broken.
- Final results deserve a stable review surface instead of a completion banner because users need to compare dimensions and leave with concrete next steps.

### The Tech Debt
- The reviewed company catalog remains frontend-owned until the backend exposes a company-profile listing endpoint. Seeded profiles without complete interview context remain intentionally hidden.
- The visualizer is still state-driven rather than connected to live microphone amplitude.
- Streaming interview responses are not wired because the current backend contract does not expose an SSE or WebSocket endpoint.
- Targeted Dart analysis reported no issues. The targeted Flutter test command timed out after 130 seconds without producing a test failure on the current Windows runner and still needs local confirmation.

## 2026-07-23 - Practice Hint Compile Fix

### The Change
- Removed the stale `setHintToBuy()` call from the practice quiz hint action and kept the current `unlockHint()` controller flow.

### The Reasoning
- The backend-wired practice controller no longer defines a purchase-selection step, and the UI already unlocks and reports hint usage through the active session state.

### The Tech Debt
- Hint monetization remains intentionally unwired until a real ad or purchase contract exists; the current hint action unlocks the server-provided hint directly.

## 2026-07-23 - Flutter-Compatible Arena Audio Dependency

### The Change
- Downgraded the direct `audioplayers` constraint from `^6.8.1` to `^6.7.1` and regenerated `apps/mobile/pubspec.lock` for Flutter 3.41.4.

### The Reasoning
- `audioplayers 6.8.1` requires Flutter 3.44 or newer, while 6.7.1 supports the project's installed SDK and retains the APIs used by the arena audio controller.

### The Tech Debt
- The dependency can be upgraded again when the project standardizes on Flutter 3.44 or newer. Keep the Flutter SDK and lockfile in sync when doing so.

## 2026-07-23 - Readable Voice Interview Prompts

### The Change
- Removed the four-line cap from the voice-room question and placed long prompts in a flexible vertical scroll area.

### The Reasoning
- Opening questions can include enough company and role context to exceed four lines. Scrolling preserves the complete prompt without displacing the answer composer on smaller phones.

### The Tech Debt
- The latest-answer preview remains intentionally compact because the editable full answer is available in the composer.

## 2026-07-23 - Interview Feedback Bottom Sheet

### The Change
- Replaced the inline expandable coaching feedback with a compact transcript summary that opens a modal bottom sheet.
- Added a fixed score and close header above a scrollable body containing dimensions, strengths, improvements, and the suggested rewrite.

### The Reasoning
- Detailed feedback can exceed the interview viewport. Moving it outside the transcript prevents layout overflow and preserves the user's chat position.
- A modal bottom sheet provides familiar close, swipe, and system-back interactions for long mobile content.

### The Tech Debt
- The sheet uses a fixed 92 percent height rather than multiple draggable snap points; those can be added if user testing shows a need.

## 2026-07-23 - Voice Question Scroll Fades

### The Change
- Added adaptive opacity fades to the top and bottom edges of the scrollable voice-interview question.
- The bottom fade appears only while more text remains, while the top fade appears after the user scrolls away from the beginning.

### The Reasoning
- The fades communicate that long prompts can be scrolled without adding permanent controls or covering the question with a background color that conflicts with the voice-room gradient.

### The Tech Debt
- Fade depth is currently fixed as a percentage of the question viewport; it can be tuned after checking a broader range of device heights.

## 2026-07-23 - Backend-Wired Profile Editing

### The Change
- Added typed, authenticated profile loading and updating through the existing `GET /profile` and `PATCH /profile` endpoints.
- Updated the profile header to use the backend `full_name`, `username`, and target values, with pull-to-refresh and human-readable loading and error states.
- Added a focused profile editor with an explicit save action, saving feedback, validation, retry-friendly errors, and an unsaved-changes confirmation.
- Removed the language preference so Indonesian remains the fixed application language, while keeping device preferences such as notifications, sound, and haptics locally persisted.
- Synced successful profile updates into the existing local profile and player-progress state, and made player progress prefer the backend full name.
- Added repository, controller, persistence, and profile-page tests for loading and saving profile data.

### The Reasoning
- Identity and preparation-target changes affect backend-owned user data, so they require an explicit save action and use the returned server profile as the source of truth.
- Device-only preferences can remain immediate local toggles because the current backend contract does not expose fields for them.
- Removing the unused language control avoids presenting a setting that does not change the application's language.

### The Tech Debt
- Performance analytics remain outside this change and should be wired to the existing analytics endpoint in the next profile slice.
- Notification and haptic preferences are persisted but still need to be consumed by their respective runtime features.
- The avatar remains initials-based until the cosmetics or media owner exposes an editable avatar contract.
- Targeted Dart analysis reported no issues. The targeted Flutter test command timed out without producing a failure on the current Windows runner and still needs local confirmation.

## 2026-07-23 - Visible Profile Edit Action

### The Change
- Set the profile app bar edit icon to the application's primary blue.

### The Reasoning
- The inherited app bar icon color did not provide reliable contrast against the light profile background.

### The Tech Debt
- None.

## 2026-07-23 - Automatic Practice Target Refresh

### The Change
- Made the practice dashboard controller react to changes in the saved profile target.
- Changing between CPNS and BUMN now recreates the stale practice state and fetches the matching server-filtered dashboard automatically.

### The Reasoning
- The profile target updated successfully, but the long-lived practice provider retained categories loaded for the previous target until pull-to-refresh was used.
- Keeping this dependency at the provider boundary applies the refresh consistently without coupling the profile editor to the practice page.

### The Tech Debt
- The practice dashboard still relies on the backend profile as the authoritative target; the local target dependency is used only to invalidate stale frontend state.

## 2026-07-23 - Backend-Wired Profile Performance

### The Change
- Added a typed, authenticated analytics data layer for `GET /analytics`, covering practice accuracy, total answers, average response time, category performance, weak subcategories, and battle results.
- Replaced the profile's runtime-derived performance cards with server-backed accuracy, response time, PvP winrate, and answered-question metrics.
- Added readable category progress and focused practice recommendations, including humanized backend identifiers.
- Added calm loading, empty, retry, stale-data error, and pull-to-refresh behavior for the analytics section.
- Added repository, controller, and profile widget coverage for the analytics contract and rendered performance summary.

### The Reasoning
- Performance claims should come from persisted learning and battle history rather than local runtime proxies that reset between sessions.
- Category and weak-topic context makes the numbers actionable without exposing raw backend identifiers or presenting the profile like an operational console.
- The existing analytics endpoint stores practice accuracy as a percentage and battle winrate as a `0..1` ratio, so each value is formatted according to its established contract.

### The Tech Debt
- Rank and streak trends are not shown because the current backend contract does not expose historical rank or streak data.
- Weak-topic recommendations follow the backend threshold of at least five answered questions and accuracy below 60 percent; changing that behavior remains backend-owned.
- Targeted Dart analysis reported no issues. The targeted Flutter test command timed out without producing a failure on the current Windows runner and still needs local confirmation.

## 2026-07-23 - AI Interview Lifecycle And Voice Reliability

### The Change
- Made live interview controllers route-scoped so starting the same configuration again cannot reuse a completed session or stale final summary.
- Added unfinished-session shortcuts on the setup screen and active-session continuation from history using the existing session detail endpoint.
- Added pending-answer recovery that preserves the draft and idempotency key across ambiguous failures, reconciles server state before retrying, and uses a fresh key when the backend explicitly marks the previous claim as failed.
- Attached coaching evaluations to their corresponding candidate answers so earlier turn feedback remains available from the conversation.
- Invalidated interview history and detail providers after session mutations so active/completed states refresh immediately.
- Added confirmation before completing or leaving an active interview, disabled premature completion, and enforced the backend's 5,000-character answer limit.
- Hardened repository errors for connection failures, malformed responses, answer-processing conflicts, oversized/unsupported audio, and failed idempotency claims.
- Added voice safeguards for a 90-second recording limit, the backend's 10 MB upload limit, app-background cancellation, local transcription errors, one-time question autoplay, prepared-audio reuse, and single-player playback.
- Added focused controller and repository regression coverage for resume, answer recovery, fresh idempotency keys, REST lifecycle mapping, and multipart transcription.

### The Reasoning
- A successful AI provider harness does not protect the mobile app from stale Riverpod state, ambiguous network outcomes, duplicate answer submissions, or interrupted recordings.
- Reconciliation through the persisted session endpoint keeps retries safe while preserving the backend's idempotency ownership.
- Resume belongs on setup as well as history so users do not need to create a new session merely to reach an unfinished one.
- Voice remains transcript-first: recordings produce editable text and never bypass the existing text answer contract.

### The Tech Debt
- Text SSE and streaming voice remain unwired because the backend exposes neither the required SSE endpoint nor a WebSocket interview gateway.
- The reviewed company catalog remains frontend-owned until the backend exposes a readiness-aware company listing endpoint.
- Prepared question audio is reused only for the lifetime of its visible player; cross-session or persistent TTS caching remains backend-owned.
- The visualizer remains state-driven rather than connected to live microphone amplitude.
- Automated tests were not run for this change by request; the complete text, coaching, realistic, resume, retry, microphone, STT, and TTS flows require manual emulator validation.

## 2026-07-23 - Clearer AI Interview Results

### The Change
- Reworked the completed interview summary into a clearer visual hierarchy with a labeled overall score, an Indonesian readiness label, and a more compact completion header.
- Grouped score dimensions, strengths, and improvement areas into restrained result panels so long feedback remains easier to scan.
- Tightened result card radii and added consistent separators between feedback items without changing the backend response contract.

### The Reasoning
- The previous result screen presented several long sections with too little visual separation, making the most useful next actions difficult to find.
- Readiness labels give the numeric score immediate meaning while keeping the interface human-facing rather than exposing implementation details.

### The Tech Debt
- Strengths, improvements, and suggested answers are generated by the AI service. The frontend cannot reliably translate arbitrary model output, so the AI prompt must map `id` to Bahasa Indonesia and explicitly require every user-facing feedback field to use Indonesian.
- Automated tests were not run by request; the completed interview screen still requires manual validation with short, long, empty, and duplicated feedback values.

## 2026-07-24 - Server-Authoritative Leaderboard

### The Change
- Removed the mock leaderboard repository and the backend repository's silent fallback so API, authentication, and response-contract failures now reach the existing user-facing error state.
- Added the backend-owned `rank` and `totalMatches` fields to leaderboard entries and preserved API ordering without removing, inserting, re-sorting, or renumbering users in Flutter.
- Kept the current user in the loaded leaderboard page when present and reserved the separate highlighted row for users whose authoritative rank is outside the loaded page.
- Replaced unsupported streak values with real match totals in the hero and leaderboard rows.
- Removed dormant global/weekly scope state because the current backend and PRD expose one global leaderboard.
- Localized the leaderboard error and retry controls and added focused contract coverage for rank mapping, current-user merging, match totals, and API failure propagation.

### The Reasoning
- Rankings and competitive statistics must remain server-authoritative; silently replacing failures with demo users made broken integration appear healthy.
- The backend already returns each row's absolute rank, so deriving positions from a filtered Flutter list caused duplicate podium ranks and shifted every player below the current user.
- A missing streak field is not equivalent to a zero streak. Match totals are available in the current contract and can be displayed honestly.

### The Tech Debt
- The leaderboard endpoint does not return a total row count, so the client still infers whether another page may exist from the page size and can make one final empty request.
- Weekly rankings and persisted streaks remain unavailable until the backend exposes explicit contracts for them.
- Equipped cosmetic IDs are returned by the backend but the leaderboard still uses a generic shield because cosmetic asset resolution is owned by the broader gamification/store work.

## 2026-07-24 - PvP-Aligned Application UI System

### The Change
- Added `AppTypography` as the shared non-PvP typography source with Fredoka headings, DM Sans interface copy, and JetBrains Mono metrics.
- Updated the light and dark application themes with the shared typography roles plus consistent app bars, cards, form fields, filled/outlined/text buttons, dialogs, bottom sheets, snackbars, and dividers.
- Replaced every remaining non-PvP Orbitron override with the appropriate PvP-aligned font role across authentication, onboarding, lobby, leaderboard, practice, interview, and profile flows.
- Standardized explicit letter spacing to zero and aligned non-PvP page backgrounds to the shared scholar-cream surface.
- Updated the persistent tab shell to use the shared body style and a quieter selected-state shape.
- Preserved existing Fredoka, DM Sans, and JetBrains Mono work in Store, Hired Pass, and shared economy widgets while bringing their inherited controls and surfaces under the same theme.

### The Reasoning
- PvP already had a clear hierarchy: friendly Fredoka headings, highly readable DM Sans content, and monospaced competitive metrics. Reusing those roles gives the rest of the app one identity without making utility screens look like battle screens.
- Central theme ownership keeps common controls consistent and reduces the need for page-level styling overrides.
- The pass intentionally changed presentation only so the recently merged zero-point onboarding fix, signup skip, persistent login, and database mapping corrections remain untouched.

### The Tech Debt
- Several older pages still define their own large card radii and shadows. They now share typography, controls, and surfaces, but a future component-by-component layout pass can reduce those remaining local visual differences.
- The PvP source was intentionally excluded. It should still be manually checked after hot restart because shared theme changes can affect any PvP widget that relies on inherited Material defaults.
- Dart formatting and targeted Flutter analysis both timed out without diagnostics in the current Windows environment. `git diff --check`, installed-SDK theme type inspection, and static font/surface audits passed; mobile viewport and increased-text-scale validation remain manual.

## 2026-07-24 - New Launcher And Splash Branding

### The Change
- Switched the Android launcher and adaptive icon source to `app-icon-new.png` with a `#1C405D` adaptive background.
- Updated the native Android launch screen and Android 12 splash theme to use the same blue background and new circular icon treatment.
- Reworked the Flutter splash screen to use a circle-clipped new icon, matching blue background, and light loading treatment.
- Regenerated the checked-in Android launcher, adaptive foreground, splash, and background resources at their existing density sizes.

### The Reasoning
- Launcher artwork remains square so Android can apply each device's system icon mask without clipping the mark twice.
- Splash artwork uses transparent circular variants to preserve the requested silhouette consistently across the native and Flutter launch stages.
- Matching native and Flutter splash colors avoids a visible background flash while the Flutter engine starts.

### The Tech Debt
- The repository currently has no `apps/mobile/ios` project, so only Android native resources were generated even though the splash configuration remains ready for iOS.
- The official Dart icon generator timed out in the current Windows environment, so Android resources were regenerated deterministically at the existing exact density sizes.
- Launcher icons are cached by Android and cannot be validated through hot reload; final verification requires uninstalling and reinstalling the app on an emulator or device.

## 2026-07-24 - Refined Splash Icon Framing

### The Change
- Reframed the splash artwork as a softly rounded square tile with the circular app icon inset inside it.
- Matched the tile proportions, subtle border, and circular inner artwork across the native Android and Flutter splash stages.

### The Reasoning
- The previous standalone circle appeared to float against the full-screen background and changed scale between the native and Flutter launch stages.
- A stable outer tile gives the mark clearer visual structure while retaining the circular icon treatment requested for the artwork itself.

### The Tech Debt
- Native splash changes still require an uninstall and reinstall because Android caches launch resources.
- The official Dart splash generator remains unavailable on the current Windows runner, so the checked-in native splash bitmaps are maintained at the project's existing density sizes.

## 2026-07-24 - Direct Square Splash Artwork

### The Change
- Removed the nested tile and circular crop from both native Android and Flutter splash artwork.
- Displayed the original square `app-icon-new.png` directly with only lightly rounded corners in both launch stages.

### The Reasoning
- The source artwork already provides its own complete background and composition, so additional framing obscured its intended square silhouette.
- Using the same direct asset treatment prevents a shape change between the native launch screen and the Flutter loading screen.

### The Tech Debt
- Android splash resources remain cached and require an uninstall and reinstall for reliable visual validation.

## 2026-07-24 - Restrained Lime Accent

### The Change
- Added `#C0FF72` as the shared `growthLime` brand accent.
- Applied the accent to shared progress indicators, selected controls and chips, floating actions, text selection, and the active navigation edge.
- Added matching light and dark color-scheme roles while preserving navy as the primary action color.

### The Reasoning
- Concentrating the lime on active, progressive, and selected states gives the interface more energy without competing with content or weakening familiar navy actions.
- Theme-level ownership keeps the accent consistent across non-PvP screens and avoids scattering near-duplicate color literals through feature widgets.

### The Tech Debt
- Feature widgets with explicit local progress or selection colors intentionally retain their semantic colors and can be reviewed individually in a later visual QA pass.
- Shared inherited styles should be checked on PvP screens after hot restart even though no PvP source files were changed.

## 2026-07-25 - Post-Match Weakness Analysis And Focused Practice

### The Change
- Added per-match player answer history for bot and online battles, including incorrect answers caused by card timeouts.
- Added a deterministic performance analyzer that identifies the lowest-accuracy category and the question card answered incorrectly most often.
- Added a post-match insight card for wins, losses, and draws with category accuracy, the most-missed prompt, and a focused practice action.
- Connected the result action to the Practice flow so the closest unlocked topic is selected and its quiz session starts automatically.
- Added unit and widget coverage for weakness ranking, local and online answer capture, battle-to-practice topic matching, result rendering, and automatic Practice navigation.

### The Reasoning
- Keeping answer analysis in the client battle state makes the feedback immediately available after either bot or online matches without changing the authoritative match outcome and economy contracts.
- Category ranking compares exact correct-to-total ratios, then uses mistake count and correct count as deterministic tie-breakers so uneven card exposure does not distort the recommendation.
- Online card snapshots preserve the prompt until the server result arrives because authoritative state updates may remove a played card from the visible hand first.
- Practice matching prioritizes an exact subcategory such as Numerik, Verbal, or Logika before falling back to a high-level category such as TIU, TWK, TKP, or AKHLAK.

### The Tech Debt
- A reconnected online match can only analyze answer events observed after the client reconnects because the current server snapshot does not include historical per-card correctness.
- Online battle cards do not currently expose their source subcategory. When only a high-level category is available and Practice requires a subcategory, the client starts the first matching unlocked topic.

## 2026-08-18 - Server-Authoritative Mobile Bot Mode & Local Simulation Elimination

### The Change
- Routed mobile Bot mode through the Game Backend via Socket.IO WebSocket on `/match` gateway, unifying all match modes (Casual, Ranked, Bot) under `SocketOnlineBattleRepository`.
- Added `OnlineMatchmakingMode.bot` to domain enums and wired socket repository `createSession` to emit `join_queue` with `{ mode: 'bot' }`.
- Completely removed dead client-side offline bot and question storage code:
  - Deleted `apps/mobile/lib/features/pvp/data/repositories/bot_battle_repository.dart`
  - Deleted `apps/mobile/lib/features/pvp/data/repositories/mock_question_bank.dart`
- Refactored `BattleController`:
  - Removed offline `_botRepository` dependency and `botBattleRepositoryProvider`.
  - Removed offline simulation timers (`_comboTimer`, `_roundTimer`, `_roundClockPaused`) and manual turn resolution methods (`resolveTurn`, `resolveOpponentTurn`, `answerBotQuestion`).
  - Unified `startBattle()`, `prepareQuestion()`, and `answerQuestion()` to flow strictly through `_onlineRepository` and server updates (`game_state_update`, `play_card_result`, `match_result`).
- Cleaned up presentation components in `PvpPage`:
  - Updated `_ArenaMenuSection` to trigger bot matchmaking via `OnlineMatchmakingMode.bot`.
  - Removed `_botTimer`, local attack scheduler, and `onBotAnswer` callback from `_InBattleSection`.
- Updated unit and widget test suites (`battle_controller_test.dart`, `pvp_page_test.dart`, `leaderboard_page_test.dart`, `interview_controller_test.dart`) to validate server-authoritative bot flows, mock event streams, and distinct idempotency key generation.

### The Reasoning
- `apps/backend-game` already implements server-authoritative Bot sessions (`BotBattleService`) with Supabase-backed question loading, combat engine validation, and automated bot pacing (3.3s–5.9s).
- Running local offline game rules and bundled question JSONs created architectural divergence, maintenance overhead, and vulnerability to client manipulation.
- Unifying all battle modes under a single thin presentation client guarantees consistent game mechanics, accurate post-match performance analytics, and seamless match progression telemetry.

### The Tech Debt
- Zero new technical debt introduced.
- Successfully eliminated substantial legacy client-side simulation tech debt, duplicate game logic, and obsolete offline mock question assets.

## 2026-08-19 - Backend API Response Integration & Practice Completion Refresh

### The Change
- Integrated the mobile Lobby flow with `GET /lobby/summary`:
  - parsed the backend response envelope and nested profile data
  - mapped rank points, streak, profile identity, and daily missions into `PlayerProgress`
  - made Today's Quests render completion state from backend mission data.
- Integrated the Leaderboard repository with the updated backend response shape:
  - supports paginated `data.items` responses
  - preserves compatibility with the previous list-shaped payload
  - reads pagination metadata from either the response metadata or page object.
- Wired Practice sessions to the backend API for dashboard loading, session creation, answer submission, and idempotent session completion.
- Added idempotency keys to Practice answer and finish requests and covered the request payloads in repository tests.
- Fixed stale Lobby progress after the first Practice session of the day by rehydrating `playerProgressProvider` after the final answer succeeds, so points and Today's Quest update before returning to the Lobby.
- Added widget coverage for the completion-triggered player progress refresh.

### The Reasoning
- The mobile repositories remain responsible for translating backend response contracts into stable domain models, keeping presentation widgets independent from envelope and pagination details.
- Shared Lobby state is refreshed at the mutation boundary because Practice completion changes server-owned rank points and daily mission state while the existing provider remains alive across tab navigation.
- Idempotency keys are generated at the API boundary so retries do not duplicate answer or completion effects.

### The Tech Debt
- Lobby, Leaderboard, and Practice response parsing still contain compatibility branches for older payload shapes; these can be removed once all deployed backend environments use the canonical contract.
- Player progress hydration currently keeps the previous state if the refresh request fails, so a transient completion-refresh error can still leave the Lobby stale until a later refresh.

## 2026-08-19 - Profile Full-Name Display And API Response Fix

### The Change
- Updated profile updates to send the documented `fullName` field while retaining the backend's `full_name` database mapping.
- Unwrapped the backend `{ data: ... }` profile response for both profile loading and saving.
- Updated `UserProfile.fromJson` to prefer `fullName` and support `full_name` for compatibility.
- Fixed the Profile and Lobby pages so the user's full name is displayed instead of the username when a full name exists.
- Added and updated repository, controller, and profile widget coverage for the profile save and display flow.

### The Reasoning
- The backend response uses a stable API envelope and camelCase profile fields, while older mobile fixtures and database-oriented payloads used snake_case.
- Keeping the normalization at the repository and model boundaries prevents response naming details from leaking into the Profile and Lobby widgets.

### Verification
- Seven focused profile tests passed.
- Focused Dart diagnostics reported no issues.

### The Tech Debt
- Snake_case parsing remains as a compatibility path until all deployed profile responses use the canonical camelCase contract.

## 2026-08-19 - Leaderboard And Performance Analytics Contract Alignment

### The Change
- Updated the mobile leaderboard parser to read the backend's `rankedWinRate` and normalize percentage values into the existing UI fraction format.
- Updated Profile performance parsing to consume the current analytics response fields: `accuracy`, `sampleSize`, `subcategoryBreakdown`, and `publicMatches`.
- Mapped backend `publicMatches.sampleSize` to the Profile PvP total-match metric and preserved compatibility with the previous `battle` response shape.
- Added leaderboard and analytics repository coverage for the current backend payloads, including percentage normalization and total match counts.

### The Reasoning
- The backend already returned authoritative values, but older mobile field names caused missing values to default to zero.
- Keeping normalization at the repository/model boundary lets existing widgets continue using their stable fraction-based display convention without recalculating server-owned statistics.
- Supporting the legacy aliases avoids breaking older fixtures or deployed responses while the canonical contract rolls out.

### Verification
- Four focused Flutter repository tests passed for leaderboard and Profile analytics parsing.
- Focused Dart diagnostics reported no issues in the touched files.

### The Tech Debt
- Compatibility aliases for legacy analytics and leaderboard fields can be removed after all deployed API environments use the canonical response shapes.

## 2026-08-19 - Hired Pass Server-Wired Beta Flow

### The Change
- Updated the mobile Hired Pass model and repository to consume server season, entitlement, mission, reward, and claimed-reward fields from `GET /hired-pass`.
- Replaced local reward-track and premium activation behavior with authenticated calls to `POST /hired-pass/beta-activate` and `POST /hired-pass/rewards/:rewardId/claim`.
- Applied server-owned Pass Points, Premium status, claimed reward IDs, Y-Coin balance, and cosmetic item ownership back into the mobile economy projection.
- Added idempotency keys to activation and reward claims and focused repository coverage for both mutation contracts.
- Improved mobile Hired Pass error parsing so nested NestJS messages are visible instead of collapsing to a generic failure.

### The Reasoning
- Hired Pass progression and rewards must remain authoritative in the backend so clients cannot fabricate Pass Points, Premium access, Y-Coin, or cosmetics.
- Keeping the existing economy state as a display projection lets the rest of the app remain stable while the Hired Pass repository owns API translation.
- Beta activation intentionally has no payment mechanism; it grants the current season entitlement for testing and remains idempotent.

### Verification
- Focused Hired Pass Flutter repository tests passed.
- Focused Flutter analysis reported no issues.
- Remote Supabase verification confirmed the active August season contains six missions and eight rewards.

### The Tech Debt
- The deployed Railway API must be redeployed with the new activation route; stale deployments return `404 Cannot POST /hired-pass/beta-activate`.
- Reward and entitlement UI still relies on the current season manifest and can later consume backend-provided presentation metadata.

## 2026-08-19 - Practice Dashboard Clay Topic Cards

### The Change
- Redesigned only the Practice dashboard topic grid with a soft 3D/clay component language while leaving the question and result flow unchanged.
- Replaced repeated category badges and the per-card `Sesi latihan dengan 5 soal.` copy with one section-level summary showing the topic count and five-question session rule.
- Added distinct Flutter-native topic icons, pastel surfaces, darker card bases, labelled availability pills, short learning cues, and a tactile press-down animation.
- Added button semantics to each topic card and retained the existing server-backed topic IDs, availability counts, and session-start behavior.
- Expanded the focused Practice dashboard widget coverage for the consolidated metadata and new topic-card presentation.

### The Reasoning
- The previous cards spent their limited content on information already established by the section, leaving each topic without a strong visual identity.
- A simple front/base construction creates the requested game-like physicality without adding image assets or changing the authoritative Practice contract.
- Shared session rules belong at section level, while each card should communicate only its topic, available-question count, learning focus, and action.

### Verification
- Focused Dart analysis reported no issues in the Practice dashboard and widget test files.
- All four focused Practice widget tests passed.

### The Tech Debt
- Topic icons, colors, and short learning cues are currently selected from stable topic-name patterns in the presentation layer. Backend-provided presentation metadata should replace this mapping if the topic catalog becomes dynamic or localized beyond the current taxonomy.

## 2026-08-19 - Practice Topic Card Category Palette Refinement

### The Change
- Changed Practice topic-card palettes to derive from the parent group/category instead of individual topic names, giving every card within sections such as Kepribadian, TIU/Logika, TWK, AKHLAK, and TKD one consistent color family.
- Kept topic-specific Flutter icons so individual cards remain recognizable without fragmenting the section palette.
- Reduced topic-card height and removed the learning-description line and explicit `Mulai` label, leaving only the icon, labelled availability, topic title, and directional arrow.
- Preserved the existing clay base, press animation, accessibility semantics, and server-backed navigation behavior.

### The Reasoning
- Category-owned color makes the content taxonomy easier to scan and prevents a single section from looking like an unrelated collection of tiles.
- The whole card is already visibly pressable, so an additional action label and explanatory sentence added noise without improving discoverability.

### Verification
- Focused Dart analysis reported no issues.
- All four focused Practice widget tests passed.

### The Tech Debt
- Category palettes still match stable frontend-readable group/category keywords. Backend presentation metadata should become authoritative if category labels or the enabled taxonomy become more dynamic.

## 2026-08-19 - Compact Practice Topic Card Layout

### The Change
- Converted Practice topic cards from a vertically separated layout into compact horizontal tiles with the icon on the left and topic information on the right.
- Reduced the fixed tile height from `144` to `108` logical pixels while retaining the clay base and press-down interaction.
- Removed the available-question pill and directional arrow, leaving the topic title and one short learning description as the card's content.
- Updated accessibility labels to announce the topic and its learning focus instead of exposing question-pool inventory.
- Updated focused widget expectations for the new description-first presentation.

### The Reasoning
- Available-question inventory repeated the section's fixed five-question session rule and exposed a backend content-readiness concern that should not drive topic selection.
- A short description helps users distinguish adjacent topics, while the compact two-column composition removes unused vertical space and remains visibly interactive through its clay treatment.

### Verification
- Focused Dart analysis reported no issues.
- All four focused Practice widget tests passed.

### The Tech Debt
- Short topic descriptions are selected from stable frontend topic-name patterns. They should move to backend/content presentation metadata if the taxonomy expands or requires editorial localization.

## 2026-08-19 - Ordered Practice Card Color Palette

### The Change
- Applied the supplied dark-blue, bright-blue, cyan, lime, orange, and pink palette only to Practice topic cards; restored the app bar, progress indicator, retry action, and Interview banner to their previous colors.
- Assigned card colors by category display order: the first category uses bright blue with a dark-blue clay base, followed by cyan, lime, orange, and pink.
- Added contrast-aware card copy so the bright-blue category uses white titles and cyan supporting text, while lighter categories use dark-blue text.
- Expanded dashboard widget coverage to verify the first and second category surface colors.

### The Reasoning
- The requested palette describes category sequencing within the topic grid, not a page-wide recolor.
- Keeping color ownership on the cards preserves the established hierarchy of the rest of the Practice dashboard while making adjacent categories immediately distinguishable.

### Verification
- Focused Dart analysis reported no issues.
- All four focused Practice widget tests passed, including ordered palette assertions.

### The Tech Debt
- Category color is intentionally tied to backend response/display order. If categories later become user-sortable, the product will need to decide whether colors should travel with stable category IDs or continue representing visual order.

## 2026-08-19 - Softened Practice Category Palette

### The Change
- Reduced the saturation of the ordered Practice card palette while preserving the blue, cyan, lime, orange, and pink sequence from the supplied reference.
- Gave each category a light pastel card face, a dusty darker clay base, a medium-tint border/icon surface, and dark hue-matched title, icon, and supporting copy.
- Kept the palette scoped exclusively to topic cards; all other Practice dashboard colors remain unchanged.
- Updated focused palette assertions for the new soft blue and cyan surface values.

### The Reasoning
- The saturated reference established the desired hue direction, but its neon intensity competed with YUDHA's cream surface and reading-focused interface.
- Using light, medium, and dark values from the same hue family preserves the playful clay construction while keeping labels readable and the overall screen calm.

### Verification
- Focused Dart analysis reported no issues.
- All four focused Practice widget tests passed.

### The Tech Debt
- These pastel ramps are currently local to the Practice dashboard. If the visual direction expands across features, they should move into shared semantic theme tokens instead of being copied between pages.

## 2026-08-19 - Practice Quiz State-Aware Clay CTA

### The Change
- Replaced only the Practice quiz's bottom primary `FilledButton` presentation with a tactile clay button while preserving the existing answer submission, progression, completion, loading, and navigation logic.
- Added distinct semantic action colors: orange/gold for enabled `KONFIRMASI`, bright blue with a dark-blue base for `LANJUT`, and lime with a darker green base for completed `SELESAI`.
- Added a muted, shallow disabled treatment before an answer is selected and retained an in-button loading indicator during submission.
- Added press-depth animation, button semantics, and stable state/surface keys for focused widget coverage.
- Expanded Practice tests with a two-question session to exercise the intermediate `LANJUT` state as well as disabled/enabled Confirm and completed states.

### The Reasoning
- Confirming an answer is a commitment, continuing is ordinary navigation, and completing a session is a reward moment; distinct color families make those meanings legible while labels remain the accessible source of truth.
- Limiting clay treatment to the primary CTA keeps answer correctness, hints, explanations, and reading surfaces visually calm.

### Verification
- Focused Dart analysis reported no issues.
- All five focused Practice widget tests passed, including CTA state-color assertions.

### The Tech Debt
- The CTA palette is local to the Practice quiz. It should become a shared semantic action component only after the same confirm/continue/complete pattern appears in at least two additional flows.

## 2026-08-20 - Mobile Freemium, Entitlement, Economy, and Auth Enforcement

### The Change
- Protected every feature route behind authentication while keeping Splash, Login, profile setup, and email confirmation public. Private deep links now round-trip through Login with a validated internal return destination, and session loss immediately returns the user to Login.
- Added explicit `loading`, `synced`, and `syncUnavailable` economy states. Cached cosmetics can render while reconnecting, but balances and all purchase, equip, arena/loadout, and credit mutations stay disabled until a successful Store snapshot is received.
- Removed local-success economy mutations and fallbacks. Store catalog fields and mutation results now come from the backend, successful changes reconcile through a fresh snapshot, and Hired Pass claims plus finalized public PvP rewards trigger authoritative economy refreshes.
- Made Hired Pass status the sole authority for premium reward access and the explicit `adFree` entitlement. Loading and failed Pass requests disable activation and claims and expose retry UI.
- Added an injectable non-blocking ad placement service for completed five-question Practice exits and finalized Casual/Ranked PvP result exits. Exit paths share a once-per-result gate, Bot results and incomplete/excluded flows do not trigger, and ads are suppressed only by an authoritative `adFree: true` response.
- Added router, economy, Store, Hired Pass, and ad-placement coverage for the new enforcement behavior.

### The Reasoning
- Authentication, ownership, pricing, entitlement, and currency must fail closed because client cache and bundled assets are presentation data, not security or economy authority.
- Keeping stale cosmetics visible avoids unnecessary visual churn while making the unavailable balance and disabled actions explicit enough that cached data cannot be mistaken for current state.
- A shared once-per-result placement gate covers buttons and back gestures consistently without introducing an ad SDK or blocking modal before the post-MVP integration is selected.

### Verification
- `flutter analyze --no-pub` completed with no issues.
- The full `flutter test --no-pub` suite passed all 111 tests.

### The Tech Debt
- The MVP ad service intentionally records non-blocking placements only. A production ad SDK, consent flow, failure policy, and telemetry still need product and platform integration.
- Mobile currently exposes Bot, Casual, and Ranked matchmaking. If a distinct Private mode is added, it must remain explicitly excluded from result-exit placements and receive focused coverage.

## 2026-08-20 - Four-Topic Practice Dashboard

### The Change
- Replaced the backend-driven Practice category sections with one target-aware section titled `LATIHAN SOAL CPNS` or `LATIHAN SOAL BUMN`.
- Limited the dashboard to four stable user-facing cards: Verbal, Numerik, Logika, and either TWK for CPNS or AKHLAK for BUMN.
- Assigned the existing soft blue, cyan, lime, and orange clay palettes by card position so every topic has a distinct, consistent color.
- Removed the topic-name description fallback and gave the four frontend topics deliberate Indonesian supporting copy and matching Flutter-native icons.
- Preserved backend filtering beneath the simplified cards: aptitude topics launch their exact category/subcategory when available, while TWK and AKHLAK launch category-wide five-question sessions. The Practice controller now retains aggregate topic filters for restart behavior.
- Expanded focused widget and controller coverage for CPNS/BUMN copy, stale subcategory suppression, ordered card colors, category-wide launch filters, and aggregate restarts.

### The Reasoning
- Database subcategories such as Analitis, Implikasi, or Silogisme are content classifications, not useful top-level choices for the current Practice dashboard.
- Four predictable choices reduce taxonomy noise while keeping session generation server-authoritative and compatible with both the canonical TIU/TKD structure and the older `kepribadian` BUMN category alias.

### Verification
- Focused Dart analysis completed with no issues.
- All 12 focused Practice widget and controller tests passed.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- The four-card adapter temporarily recognizes `kepribadian` as a BUMN alias until deployed question data is normalized to the PRD's canonical `akhlak` category.
- Backend content sync still needs to deactivate stale canonical-managed questions and the dashboard contract should eventually expose a stable, session-ready topic catalog instead of every distinct database subcategory.

## 2026-08-20 - BUMN Practice Category Label Alignment

### The Change
- Renamed the fourth BUMN Practice card from uppercase `AKHLAK` to title-case `Kepribadian`, matching the category identifier returned by the deployed database and the casing of Verbal, Numerik, and Logika.
- Updated its supporting copy to `Kenali karakter dan sikap kerja` while preserving the category-wide `kepribadian` session filter.
- Updated focused BUMN dashboard expectations for the corrected label and description.

### The Reasoning
- The frontend should not translate an authoritative `kepribadian` category into a different taxonomy label, especially when the other three cards directly reflect backend categories.
- Consistent title casing keeps all four peer cards at the same visual level; uppercase remains appropriate only for genuine abbreviations such as TWK.

### Verification
- Focused Practice widget and controller tests passed.
- Focused Dart analysis reported no issues.

### The Tech Debt
- The repository PRD and canonical content bank still use `akhlak` while the deployed BUMN database uses `kepribadian`; backend and product taxonomy should be reconciled so the frontend no longer needs to recognize both identifiers.

## 2026-08-20 - Practice Recent Activity Cap and Full History

### The Change
- Limited `TERAKHIR DIKERJAKAN` on the Practice dashboard to the three newest activities returned by the dashboard response.
- Added a compact `Lihat semua` text action with a 44-pixel tap target and registered the authenticated `/practice/history` route.
- Added a full Practice history screen backed by `GET /practice/history`, including pull-to-refresh, empty/error states, 20-row pagination, and `Muat lebih banyak` behavior.
- Added a shared Practice activity tile so dashboard and full-history rows keep one presentation implementation.
- Extended the Practice repository, provider, controller, and domain state with offset-based history retrieval while leaving the existing dashboard loading flow unchanged.
- Added focused coverage for the three-row cap, pagination, endpoint query/response parsing, and private-route registration.

### The Reasoning
- The dashboard should provide a quick snapshot rather than grow into an unbounded activity feed, while a dedicated screen can support deliberate history review.
- A small text action preserves the topic cards as the page's primary actions without sacrificing accessibility or making the history destination appear decorative.

### Verification
- Focused Dart analysis completed with no issues.
- All 22 focused router, repository, Practice controller, and widget tests passed.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- Both dashboard `recentSessions` and `/practice/history` currently include unfinished sessions. The backend should distinguish completed history from the single resumable active session so empty abandoned sessions do not dominate either feed.
- History rows reuse the current summary contract, which has timestamps but the mobile activity model does not yet expose them. Adding a human-readable completion date would make repeated category attempts easier to distinguish.

## 2026-08-20 - Lobby Navbar

### The Change
- Redesigned the shared five-tab navigation as an icon-only floating white capsule on the scholar-cream shell background while preserving route order, nested Practice selection, and in-battle hiding.
- Added a gray attached clay layer above the white face and a full-height tapered active indicator that fades from translucent Yudha blue to transparent, ending in a solid blue underline.
- Reused the existing SVG icons with a muted blue-gray inactive color and retained hidden labels through semantics and tooltips for accessibility.

### The Reasoning
- The icon-only rail gives the Lobby more visual space and matches the lightweight game-component reference without changing navigation behavior.
- The restrained gradient and underline communicate selection without making the active tab look like a raised button.

### Verification
- Focused shared-navigation widget tests passed for all five icons, active-state geometry, nested route selection, clay layering, and accessibility semantics.
- Focused Dart analysis completed with no issues.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- Icon recognition should be validated with target users before visible tab labels are considered permanently unnecessary.

## 2026-08-20 - Lobby Mission

### The Change
- Established the lower 60% of the Lobby as a scholar-cream mission stage and vertically centered a floating white mission board with a neutral-gray clay base and shared 26-pixel radius.
- Rebuilt the two daily missions as large connected roadmap checkpoints while preserving titles, completion states, rewards, and Practice/PvP navigation callbacks.
- Kept the peach clay `START BATTLE` action inside the board as the roadmap destination, with responsive padding, checkpoint sizing, connector length, and action spacing for regular and compact screens.

### The Reasoning
- Separating the mission stage from the blue player stage creates a clear task area, while the roadmap gives the fixed two-mission contract more game-like structure than a flat list.
- A content-sized board uses the available space deliberately without stretching rows or inventing backend content.

### Verification
- Focused Lobby widget tests passed at 390x844 and 390x680 viewport sizes, covering board centering, clay layers, checkpoint geometry, navigation callbacks, CTA placement, and overflow safety.
- Focused Dart analysis completed with no issues.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- The roadmap is tuned for the current two-mission contract. A dynamic mission count will require a generated or scrollable path.

## 2026-08-20 - Lobby Profile

### The Change
- Established the upper 40% of the Lobby as a unified royal-blue profile stage continuous with the left-aligned `YUDHA` app bar, with rounded lower corners and an attached 8-pixel deep-blue clay edge.
- Matched the profile face and clay edge to the mission board's 26-pixel radius so the full-width section retains depth without becoming a floating card.
- Reorganized the player information into a shield identity row, subtle 5% white name-and-tier panel, primary rank points, secondary win-rate and streak metrics, and tier progress.
- Removed the profile composition's top inset to raise the content while retaining responsive bottom padding and internal spacing.
- Added the crossed-swords SVG watermark and restrained background geometry to make the open blue area intentional without requiring complex assets.

### The Reasoning
- Treating the top bar and profile as one blue environment avoids the fragmented prototype-card appearance and gives identity, performance, and progression a clearer hierarchy.
- Read-only metrics remain visually passive, while clay depth is reserved for the section boundary and actionable controls.

### Verification
- Focused Lobby widget tests passed at 390x844 and 390x680 viewport sizes, covering the 40/60 stage split, unified colors, profile positioning, shared radii, attached clay geometry, and responsive overflow safety.
- Focused Dart analysis completed with no issues.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- The shield remains a generic Flutter icon until equipped profile cosmetics are connected, and Lobby-specific colors should become shared tokens only when another surface adopts the same treatment.

## 2026-08-20 - Hired Pass UI Redesign

### The Change
- Rebuilt the reward track as aligned milestone, Free Pass, and Premium Pass columns with the lane labels shown once in a shared header.
- Kept the Free lane transparent and added one continuous soft-purple background behind the Premium lane.
- Replaced descriptive reward cards with compact clay controls that center either a Y-marked coin amount or enlarged cosmetic artwork, prioritizing the item for compound rewards.
- Added distinct raised claimable, muted locked, and pressed claimed states with lock/check indicators and accessible state labels.
- Increased coin-only reward marks to 38 pixels and cosmetic artwork to 46 pixels with 10-pixel rounded clipping.
- Kept item rewards visually focused on the cosmetic while preserving all authoritative bundled coin grants during claiming.
- Removed repeated `FREE`, `PREMIUM`, and long status copy from individual rewards.
- Made milestone lookup tolerant of a missing Free or Premium reward so incomplete server rows render an empty cell instead of throwing.
- Added focused widget coverage for lane structure, state geometry, tap availability, semantics, reward sizing, rounded artwork, compound rewards, and missing-reward behavior.

### The Reasoning
- Persistent column headers communicate track ownership once, allowing individual rewards to prioritize their value and interaction state.
- Clay depth now acts as the interaction cue: claimable rewards are visibly raised, claimed rewards look pressed, and locked rewards remain visibly disabled.

### Verification
- The focused Hired Pass widget test passed at a 390x844 viewport.
- Focused Dart analysis completed with no issues.

### The Tech Debt
- The code-native Y-Coin mark remains local to the reward track until a shared official coin asset is introduced.

## 2026-08-20 - Interview Page Redesign

### The Change
- Replaced the inset active-interview card with a full-screen vertical blue-to-teal gradient continuous with the royal-blue app bar.
- Restyled the voice-mode information and current-question areas as restrained translucent surfaces directly on the gradient.
- Increased the animated voice orb from 150 to 180 pixels while preserving listening, transcription, and response-processing states.
- Converted idle and recording answer composers from full-width bottom sheets into floating rounded white controls with safe-area margins and keyboard-aware placement.
- Constrained the compact answer field and hint to one line, tightened the microphone and send controls, and mapped the keyboard action to Send.
- Preserved existing voice capture, transcription, text submission, audio playback, retry, history, completion, evaluation, and exit behavior.
- Kept the completed-results view on its existing scholar-cream background.
- Added focused widget coverage for gradient colors, voice-stage components, orb sizing, composer styling and line behavior, keyboard action, and overflow safety at 390x844 and 390x680.

### The Reasoning
- Letting the gradient own the active room creates the immersive full-screen treatment in the reference, while floating only the interactive composer keeps the primary action visually distinct.
- Translucent question surfaces retain readability without reintroducing another large card over the background.

### Verification
- The focused Interview widget test passed at 390x844 and 390x680 viewport sizes.
- Focused Dart analysis completed with no issues.

### The Tech Debt
- The voice orb remains code-native and intentionally non-reactive to microphone amplitude; connecting live waveform intensity would require a separate audio-level contract.
- Long typed answers scroll horizontally within the single-line field rather than expanding vertically.

## 2026-08-21 - Profile Page Redesign

### The Change
- Rebuilt the profile identity card as a royal-blue clay surface with a layered initial avatar, username, tier and target badges, Y-Coin balance, and authoritative tier progress.
- Added an asset-free PvP overview with a painted win/loss/draw donut, match totals, and separate current/best streak tiles.
- Separated practice analytics from PvP, promoted practice accuracy into a clear summary card, and softened the supporting metric and category panels.
- Extended the profile entity to map rank points, tier, ranked stats, Y-Coins, equipped IDs, and streak data from the backend profile response while retaining lobby-progress fallbacks for older payloads.
- Restyled the profile settings surface with the same restrained white-and-gray clay depth used elsewhere in the app.

### The Reasoning
- Profile identity, ranked performance, practice performance, and preferences now have distinct visual hierarchy instead of appearing as equally weighted prototype cards.
- The redesign uses only Flutter painting, Material icons, and existing catalog metadata, so it does not depend on unavailable character artwork or fabricate a time-series trend the backend does not provide.
- Passive statistics use soft fills and shallow depth, reserving stronger button-like clay treatment for actual actions.
- Character and tower selection remains in the game lobby, avoiding a duplicate loadout summary on the personal profile.

### Verification
- Focused profile entity and widget tests passed, covering the complete backend payload, normalized win rate, redesigned sections, readable analytics, scrolling, and edit behavior.
- Focused Dart analysis completed with no issues.

### The Tech Debt
- The avatar remains initial-based until the backend exposes a dedicated profile-avatar contract or approved artwork is added.
- The profile response and lobby summary overlap in ranked data; the profile page currently prefers `/profile` and falls back to lobby progress for backward compatibility.

## 2026-08-21 - Practice Progress Stage

### The Change
- Connected the Practice app bar to a full-width royal-blue progress stage with rounded lower corners and an attached deep-blue clay edge matching the Lobby's visual language.
- Blended a compact CPNS/BUMN badge directly into the `Progress latihan` title row and kept the header focused on authoritative overall practice progress.
- Kept AI Interview outside the header as the first training action, restyling it as a white-and-gray clay card so it remains prominent without competing with the blue progress area.
- Preserved the four equal question-category cards and recent-practice history beneath the featured interview action.

### The Reasoning
- The shared rounded stage creates continuity between primary tabs while allowing each page to communicate page-specific status: player rank in Lobby and learning progress in Practice.
- Interview is a selectable training mode rather than progress metadata, so separating it from the header makes the information architecture clearer.

### Verification
- Focused Dart analysis completed with no issues.
- All seven focused Practice widget tests passed, including CPNS/BUMN context, progress-stage geometry, Interview presentation, question categories, history, quiz actions, and recommended-session navigation.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- The progress hero currently uses the backend's single aggregate percentage; richer per-category progress would require an expanded dashboard contract.

## 2026-08-21 - Leaderboard Redesign

### The Change
- Connected the Leaderboard app bar to a full-width royal-blue competitive stage with shared 26-pixel lower rounding and an attached deep-blue clay edge.
- Removed the nested profile card and placed player identity, global-rank medallion, rank points, win rate, match count, and tier progress directly on the blue stage.
- Corrected the progress copy from leaderboard-rank XP to tier progression and handled the maximum tier without dividing by a zero-length tier range.
- Replaced the three independent winner cards with one unlabeled white-and-gray clay podium board containing a taller first-place pedestal and code-native gold, silver, and bronze treatments.
- Unified the profile-stage rank medallion with podium semantics: gold for first, silver for second, bronze for third, soft blue for rank four and below, and muted gray only for an unavailable rank.
- Consolidated ranks below the podium into one compact white clay table with dividers, aligned point values, and a soft-cyan current-user state.
- Preserved refresh, pagination, partial-load messaging, and the separated `POSISIMU` fallback when the current user is outside the loaded ranking page.

### The Reasoning
- A continuous blue stage makes the page consistent with Lobby and Practice while keeping its purpose specific to global competitive position.
- A shared podium reads as one result hierarchy, while a continuous table makes lower positions easier to compare and avoids making passive rows resemble buttons.
- The global-rank medallion remains visually passive; clay depth is used for section structure rather than suggesting that rank data is interactive.

### Verification
- Focused Dart analysis completed with no issues.
- All four focused Leaderboard widget tests passed, covering loading, success, empty, and error states plus stage geometry, podium structure, ranking table, current-user fallback, and corrected tier copy.
- The success layout was verified at a 390-pixel phone width, including an explicit narrow-screen overflow check.
- `git diff --check` completed without whitespace errors.

### The Tech Debt
- The podium renders restrained placeholders if the backend returns an incomplete top-three set; a dedicated top-three contract could distinguish missing data from an unoccupied rank.

## 2026-08-22 - Dummy Payment Confirmation Modal & Y-Coin Beta Top Up

### The Change
- Created `payment_confirmation_modal.dart` (`showDummyPaymentConfirmation`), a reusable bottom sheet dialog for confirming purchases with:
  - Product summary card displaying item title, price label, and `BETA ACCESS AVAILABLE` / `PREMIUM PASS` pill badges.
  - Selectable Sandbox payment methods: QRIS Instant Sandbox, Yudha Pay (Beta) (Saldo Sandbox: Rp500.000), Google Play Billing Sandbox, and Virtual Account Bank (BCA, Mandiri, BNI, BRI).
  - Detailed price breakdown showing original package price, handling fee (`GRATIS Beta`), and total payment.
  - Action buttons for cancellation and confirmation with interactive processing feedback.
- Updated `hired_pass_page.dart` so tapping "Aktifkan Premium • Rp29.000 (Beta)" triggers the dummy payment confirmation modal before executing Hired Pass activation.
- Updated `economy_widgets.dart` so tapping any Y-Coin top-up package tile opens the dummy payment confirmation modal, with all packages labeled with "Beta Access Available".
- Updated `game_economy_controller.dart` and `backend_game_economy_repository.dart` to send `coins: package.totalCoins` when executing top-ups so custom packages (+1.200 Y-Coin, +500 Y-Coin, +2.800 Y-Coin, +6.800 Y-Coin) award their full coin total to the player balance.

### The Reasoning
- Adding an explicit dummy payment confirmation step provides a realistic checkout flow and eliminates accidental instant purchases while keeping payment gateway integration out of scope for Beta Access.
- Forwarding `package.totalCoins` ensures user expectations match package selection: choosing +1.200 Y-Coin adds 1.200 coins rather than defaulting to the base credit amount.

### Verification
- All 123 mobile unit and widget tests passed, including store top-up flow, payment confirmation dialog interactions, and economy balance state mutations.

### The Tech Debt
- Payment methods remain static UI choices for Beta sandbox simulation; integration with actual payment gateways (e.g. Midtrans, Xendit, Google Play Billing API) will be required for production release.

## 2026-08-22 - Practice Subcategories

### The Change
- Replaced the synthetic four-card menu with the dashboard's final category-subcategory taxonomy: CPNS uses `TWK`, `TIU`, and `TKP`; BUMN uses `TKD`, `AKHLAK`, and `Wawasan Kebangsaan`.
- Rendered each category's four subcategories in a compact two-column grid with one shared soft clay color and one `4 subkategori • 5 soal per sesi` label per group.
- Preserved canonical session identifiers, including `akhlak`, while formatting snake-case labels for display and retaining the `UUD` and `NKRI` acronyms.
- Kept post-battle `logika` recommendations compatible with the new `Kemampuan Logis` label and made the progress-title row resilient at narrow phone widths.

### The Reasoning
- The database taxonomy created on 2026-08-21 is the current source of truth, so the frontend groups returned topics instead of inventing flattened launch cards.
- Identifier humanization keeps API values stable for requests while producing readable labels without losing institutional acronym casing.

### Verification
- Focused Dart analysis completed with no issues.
- All 10 focused Practice repository and widget tests passed, covering grouping, colors, canonical identifiers, acronym formatting, quiz actions, and recommended-session navigation.
- The taxonomy layouts were exercised at a 390-pixel phone width.

### The Tech Debt
- `docs/PRD.md` still describes the older taxonomy and should be updated once the newly built database contract is formally documented.
- The frontend currently owns the expected category ordering and semantic color mapping; backend-provided ordering metadata would remove that duplication.
- The mobile formatter maintains a small acronym allowlist until the API exposes separate stable identifiers and display labels.

## 2026-08-22 - Practice Null History State

### The Change
- Kept `TERAKHIR DIKERJAKAN` visible when the selected CPNS/BUMN target has no practice history and added a compact white empty-state panel with `Belum ada latihan yang dikerjakan`.
- Hid `Lihat semua` when there are no history entries while preserving the existing three-entry preview and full-history action for populated states.

### The Reasoning
- A target with no sessions should communicate an intentional empty result rather than making the history section disappear and appear broken.

### Verification
- Focused Dart analysis completed with no issues.
- All seven focused Practice widget tests passed, including explicit empty-history coverage.

### The Tech Debt
- The empty state is text-only; no illustration was added because the current design does not require a new asset.

## 2026-08-22 - Game Setup View 1: Arena

### The Change
- Replaced the arena carousel with a centered selected-arena showcase and two compact CPNS/BUMN choice tiles.
- Preserved target-aware locking and added the shared three-step header with the first segment active.

### The Reasoning
- Two target-bound arenas are easier to compare directly than through a carousel, while the large showcase gives the setup flow a clear focal point.

### Verification
- Focused PvP analysis and widget tests passed, including target locks and arena selection.

### The Tech Debt
- Arena artwork still uses the existing catalog assets without directional transition animation.

## 2026-08-22 - Game Setup View 2: Loadout

### The Change
- Kept the selected arena, character, and tower together in a compact diorama and added horizontally scrollable portrait-card collections for characters and towers.
- Made the stage vertically fixed, kept locked cosmetics visible with Store routing, and used the shared header with two segments active.

### The Reasoning
- Direct horizontal browsing exposes the full collection while keeping the bounded setup stage and its clay CTA visible without vertical scrolling.

### Verification
- Focused PvP analysis and widget tests passed at 390 x 700, covering horizontal swiping, locked cards, equipment updates, and overflow safety.

### The Tech Debt
- The two-item tower catalog naturally leaves more horizontal space than the character catalog; no duplicate placeholders are fabricated.

## 2026-08-22 - Game Setup View 3: Mode

### The Change
- Standardized the shared header and padding with all three progress segments active.
- Kept the equipped arena, character, and tower fixed in the showcase while its accent changes between Bot, Casual, and Ranked.
- Replaced arrow navigation with three direct blue, purple, and orange portrait cards, added mode-specific SVG illustrations, and retained the contextual clay start CTA.

### The Reasoning
- Three modes are few enough to compare at once; persistent loadout artwork maintains continuity while color and SVG cues make each choice easy to scan.

### Verification
- Focused Dart analysis completed with no issues, and all five PvP widget tests passed at 390 x 700 across the complete three-view setup and battle regressions.

### The Tech Debt
- The lightweight SVGs can be replaced with final art-direction assets without changing the card layout.

## 2026-08-25 - Daily Mission And Streak Reminder Experience

### The Change
- Initialized FlutterFire and Firebase Messaging for Android and Chromium PWA, including the Android permission/channel configuration, dedicated web messaging worker, VAPID support, and no-cache deployment headers.
- Replaced the unused local notification flag with server-backed master, morning, and rescue controls plus editable local-time pickers.
- Added stable installation and token synchronization on login, refresh, resume, and timezone changes, with account-scoped unregister on logout.
- Added the one-time post-success permission prompt, authenticated deep-link preservation, delivery-open reporting, and quiet foreground Lobby refresh behavior.

### The Reasoning
- Permission is requested after a meaningful success rather than at app launch, while Settings remains an explicit path for users who defer or deny it.
- Installation-level registration supports every recently active authorized device without conflating browser/OS permission with account preferences.
- Notification routes are constrained to Lobby, Practice, and PvP so cold-start payloads cannot navigate to arbitrary application locations.

### Verification
- The complete Flutter suite passed: 125 tests.
- The production PWA build passed and contains `firebase-messaging-sw.js`.
- The Android debug build passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- Flutter analysis reported no new diagnostics; two existing deprecated `Radio` API informational findings remain in the payment confirmation modal.

### The Tech Debt
- Production web deployment still needs `FIREBASE_WEB_VAPID_KEY`, and both Android and installed Chrome/Edge PWA delivery should be verified against staging FCM with next-minute reminder times.
- Native iOS and Safari web push remain intentionally out of scope.
## 2026-08-25 - Profile Editor Redesign

### The Change
- Restyled the edit-profile bottom sheet with a compact identity header, scholar-cream background, white-and-gray clay form sections, and clearer field hierarchy.
- Replaced the default segmented control with direct CPNS/BUMN clay choice cards and replaced the standard save button with the orange clay action treatment.
- Replaced the default unsaved-changes alert with a custom warning dialog while preserving continue-editing and discard behavior.

### The Reasoning
- The editor now matches the redesigned Profile page and shared component language without changing profile validation, persistence, keyboard handling, or navigation.

### Verification
- Focused Dart analysis completed with no issues.
- All four focused Profile widget tests passed, covering redesigned component rendering, explicit saving, and both unsaved-change actions; the editor was verified at a compact 411 x 700 viewport without overflow.

### The Tech Debt
- The profile avatar remains initial-based until an editable avatar contract and approved artwork are available.
- The existing Profile summary layout overflows at 390 logical pixels before the editor opens; that parent-page responsiveness issue is outside this component-only change and should be handled separately.

## 2026-08-25 - Interview Setup Redesign

### The Change
- Reorganized Interview Setup into a blue target-aware preparation hero followed by three numbered white-and-gray clay panels for target, mode, and response configuration.
- Restyled company and role fields, converted mode and answer-style choices into colored clay cards, and added the orange clay start action.
- Reworked unfinished interviews into a compact continue-session panel while preserving the existing three-session cap and resume navigation.

### The Reasoning
- The setup now reads as one guided preparation flow instead of a collection of equally weighted form controls, while keeping all choices directly comparable and consistent with the redesigned app components.

### Verification
- Focused Dart analysis completed with no issues.
- Both focused Interview Setup widget tests passed at 390 x 844, covering responsive rendering, company-driven default roles, mode and response selection, unchanged launch configuration, and unfinished-session resume navigation.

### The Tech Debt
- Company options remain frontend constants and should eventually come from backend-provided interview configuration metadata.

## 2026-08-25 - Interview Result Redesign

### The Change
- Rebuilt the completed Interview view around a continuous royal-blue app bar and result stage with a circular overall-score indicator, target context, and evaluated-answer count.
- Added score-aware, high-contrast readiness badges while preserving the existing score thresholds and labels.
- Restyled dimension scores, strengths, improvements, and the suggested answer rewrite as distinct clay surfaces with semantic teal, orange, and purple treatments.
- Kept one semantic heading icon for each feedback section instead of repeating it beside every feedback item.
- Replaced standard result actions with primary orange and secondary white clay buttons while preserving their existing destinations.

### The Reasoning
- The result now prioritizes the overall outcome before progressively revealing diagnostic detail. The continuous header, readable readiness badge, and reduced icon repetition improve hierarchy and contrast while staying consistent with the app's redesigned visual language.

### Verification
- Focused Dart analysis completed with no issues.
- Focused Interview widget tests passed, covering the completed-result rendering, score-aware status badge, both result actions, and active voice-room regression.

### The Tech Debt
- Result dimensions are limited to the six scores currently returned by the backend; richer trend comparisons require historical result data.

## 2026-08-25 - Interview Session Sheets Redesign

### The Change
- Restyled the Interview history sheet with a visible drag handle, explicit close action, taller responsive surface, and clay session cards.
- Redesigned session details with a persistent back action, blue score summary, distinct transcript cards, coaching-note treatment, and an always-visible transcript scrollbar.
- Kept the history sheet beneath completed-session details so returning from a detail restores the session list.

### The Reasoning
- Session history now follows the same visual language as the redesigned Interview flow, while explicit navigation and scroll affordances make long archived sessions easier to understand and exit.

### Verification
- Focused Dart analysis completed with no issues.
- Three focused Interview widget tests passed, including the history-to-detail flow, scrollbar presence, and return-to-history behavior.

### The Tech Debt
- Session timestamps remain compact relative labels; more detailed date grouping can be added if the history volume grows.

## 2026-08-25 - Interview Confirmation Dialog Redesign

### The Change
- Replaced the default Material confirmation dialogs for leaving, completing, and switching Interview sessions with one reusable clay-styled dialog.
- Added semantic icons, clearer supporting copy, and visually distinct white cancel and colored confirm actions while preserving every existing return value and callback.

### The Reasoning
- A shared component keeps destructive and progression confirmations consistent with the redesigned Interview flow and makes the action hierarchy easier to scan.

### Verification
- Focused Dart analysis completed with no issues.
- Three focused Interview widget tests passed, including confirmation rendering, cancellation, and active-room retention.

### The Tech Debt
- None introduced; the dialog remains private to the Interview feature until another feature needs the same interaction pattern.

## 2026-08-26 - In-Battle Arena Clay Redesign

### The Change
- Applied a shared clay palette to the live PvP stage without changing the existing opponent, arena, player, and card-hand layout.
- Added layered navy stage depth, raised player and opponent HUD surfaces, tactile score, combo, timer, pause, avatar, and HP treatments, plus a darker clay base around the arena.
- Strengthened available, selected, disabled, and empty card presentation while preserving the existing card assets and interactions.
- Joined the player HUD and card-section wrapper into one continuous cream control deck while retaining rounded, raised individual cards.

### The Reasoning
- The live arena now matches the app's clay component language while retaining the established gameplay geometry, asset positions, animations, and information density. Removing competing edges between the player HUD and card section also makes both areas read as one control surface.

### Verification
- Focused Dart analysis completed with no issues.
- All five focused PvP widget tests passed, including the in-battle server-update flow, connected control-deck assertions, and layout checks at 411 x 914 and 390 x 700.

### The Tech Debt
- Battle overlays and the question sheet intentionally retain their existing styling until their dedicated redesign commits.

## 2026-08-26 - Battle Question Popup Redesign

### The Change
- Redesigned the in-battle question popup with a flat category header, timer, prompt, connection notice, and one shared clay answer panel containing divided response rows.
- Preserved available, selected, correct, incorrect, and locked answer states while removing repeated clay shadows from informational surfaces.
- Removed successful-answer confirmation copy and delay so the popup closes immediately after a successful submission; timeout and submission-failure feedback remain available.

### The Reasoning
- One grouped response surface creates a calmer hierarchy, keeps informational content from looking interactive, and returns the player to the arena without an unnecessary success step.

### Verification
- Focused Flutter analysis completed with no issues.
- All five focused PvP widget tests passed, including popup rendering, grouped-answer styling, answer submission, and dismissal.

### The Tech Debt
- Match-result and surrender surfaces remain separate redesign commits.

## 2026-08-26 - Correct and Wrong Answer State Management

### The Change
- Added a dedicated self-answer result ID and correctness value to mobile battle state instead of inferring feedback from answer-history growth.
- Added a mobile socket fallback that recognizes the player's result through the locally submitted card ID when actor-ID comparison is unreliable.
- Reused the hand header helper position for a temporary green `BENAR` or red `SALAH` badge that restores the normal instruction after 1.5 seconds.

### The Reasoning
- First-class result state makes feedback independent of card replacement and unrelated battle effects while keeping server grading authoritative and avoiding additional visual clutter.

### Verification
- Focused Flutter analysis completed with no issues.
- All 12 focused BattleController unit tests and all five focused PvP widget tests passed, including self-result publication, opponent-result isolation, badge transitions, and helper restoration.

### The Tech Debt
- A socket-repository integration harness is still needed to replay raw Socket.IO payloads without a live server; controller and widget behavior are covered independently for now.

## 2026-08-26 - Result Screen Redesign

### The Change
- Redesigned the existing win, loss, and draw screen around a medium outcome-colored clay hero with semantic iconography and match-mode context.
- Flattened the round-score section, added a compact reward banner, retained the orange clay claim action, and aligned `Main lagi` with `Pilih mode` as equal secondary actions.
- Kept coaching visible for answered and unanswered matches, added two-line missed-question previews with inline `Lihat lengkap` / `Ringkas` expansion, and normalized taxonomy labels such as `TKD`, `Wawasan Kebangsaan`, `UUD 1945`, and `NKRI`.
- Preserved reward claiming, replay, mode selection, practice recommendations, confetti, audio, haptics, and safe scrolling on short screens.

### The Reasoning
- A dominant outcome hero provides immediate result identity while flatter supporting information prevents excessive clay depth. Persistent coaching stabilizes both result states, and inline expansion provides enough question context without introducing another popup.

### Verification
- Focused Flutter analysis completed with no issues.
- All five focused PvP widget tests passed, including result variants, long-question expansion, normalized taxonomy copy, reward claiming, aligned actions, and the complete multiplayer result flow.

### The Tech Debt
- Surrender remains a separate result-state commit. Expanded prompts and unusually large accessibility text intentionally use the existing scroll fallback when content exceeds the viewport.

## 2026-08-27 - Battle Overlays and Transient States Redesign

### The Change
- Redesigned the pause panel with clay depth, a contained music control, and the shared orange resume action, then added a dedicated confirmation step before surrendering or ending a battle.
- Reworked initial and between-round countdowns into a centered clay transition board and added dedicated clay banners for reconnecting opponents, arena errors, and meaningful battle status updates.
- Added a compact card-opening progress badge and redesigned the matchmaking/private-room waiting state as a raised clay panel while preserving the existing character and tower assets.
- Kept raw answer-submission transport copy hidden so correct and incorrect feedback continues to use the established hand-header state instead of restoring the removed popup behavior.

### The Reasoning
- Transient UI sits directly above the arena and must share its component language without obscuring gameplay. Persistent connection states, short-lived arena notices, and explicit destructive confirmation give each interruption the appropriate visual weight.

### Verification
- Focused Flutter analysis completed with no issues.
- All five focused PvP widget tests passed, including waiting, pause, surrender cancellation, reconnecting, error, card processing, round transition, question, and result flows.

### The Tech Debt
- The surrender-specific result presentation remains a separate follow-up commit; this change only confirms and executes the existing surrender action.

## 2026-08-27 - Surrender Result Page

### The Change
- Added a dedicated surrender result state and coral clay result page with the round and HP summary, recovery guidance, surrender consequence, replay action, and mode-selection action.
- Preserved authoritative server results with a local fallback, removed normal defeat rewards and coaching from surrender outcomes, and kept the finished state visible until the player leaves the result page.
- Covered the real pause and confirmation-dialog transition so surrender no longer resets directly to the arena menu.

### The Reasoning
- Surrender is a deliberate exit rather than an ordinary loss, so it needs distinct feedback and actions. Resetting only from the result-page navigation preserves that feedback while the bounded local fallback prevents missing server acknowledgements from leaving the player stuck.

### Verification
- The controller and presentation coverage includes local fallback, authoritative surrender results, and the dedicated result page; the widget test now follows the actual pause and surrender-confirmation path.
- `git diff --check` passed after the transition fix. The refreshed Flutter test was blocked by another active Flutter runner during the final check.

### The Tech Debt
- The local fallback cannot infer ranked penalties if the server result misses its acknowledgment window; the repository may still reconcile authoritative progression on the next profile hydration.

## 2026-08-27 - Android Hands-Free Live Interview

### The Change
- Replaced the voice-mode record–transcribe–edit–send composer with an automatic call coordinator: opening/next-question playback, PCM16 capture, pure-Dart VAD, acknowledged chunk streaming, final transcript/evaluation reduction, and automatic next-turn capture.
- Added explicit connecting, interviewer-speaking, listening, candidate-speaking, transcribing, evaluating, reconnecting, muted, degraded, and completed phases with mute, confirmed hang-up, reconnect, and text-fallback controls.
- Added Android `record.startStream` capture at 16 kHz mono PCM16, deterministic 300 ms pre-roll/200 ms speech confirmation/1.2 s silence/500 ms minimum utterance rules, replay with the same answer ID after reconnect, and minimum SDK 23.
- Injected capture, playback, and socket factories so widget tests use fakes and never contact question autoplay URLs.

### The Reasoning
- Voice mode now behaves like a turn-based phone call after the setup/resume gesture while keeping persisted text as the domain source of truth and preserving the paid session when live providers or permissions fail.

### Verification
- Flutter interview unit and widget suite passed: 20 tests.
- Focused Flutter analysis completed with no issues before the final contract documentation pass.

### The Tech Debt
- Physical-device acceptance still needs provider credentials and Android scenarios for microphone denial, backgrounding, network interruption, and five complete spoken turns. iOS/PWA, barge-in, full duplex, and partial captions remain out of scope.

## 2026-08-27 - Press-and-Hold Live Interview Capture

### The Change
- Replaced noise-sensitive automatic VAD completion with explicit press-and-hold capture: the microphone stays off after question playback, begins on pointer-down, and submits on release.
- Replaced mute with a prominent Indonesian hold control, active recording treatment, elapsed timer, 500 ms short-press protection, and a 90-second automatic submission cap.
- Added lifecycle and pointer cancellation that discard rather than submit, while preserving same-answer-ID replay for transport disconnects and the existing reconnect, hang-up, and text fallback controls.
- Removed the VAD implementation/tests and added deterministic coordinator coverage for release, cancellation, maximum duration, duplicate press protection, and reconnect replay.

### The Reasoning
- Explicit release is predictable in noisy rooms and prevents ambient sound from keeping a turn open indefinitely, while question playback and post-transcript evaluation remain automatic.

### Verification
- Focused coordinator tests passed: 6/6.
- Focused active/completed/history interview widget tests passed: 3/3.

### The Tech Debt
- Physical Android validation should confirm long-hold ergonomics and pointer behavior with TalkBack before release.

## 2026-08-30 - Backend-Driven Interview Company Catalog

### The Change
- Replaced the static, profile-target-filtered interview company list with an authenticated catalog loaded through `InterviewRepository` and a Riverpod `FutureProvider`.
- Added a nullable `InterviewCompanyOption.defaultRole`, selected the first backend result by default, and preserved automatic role suggestions when the backend provides one.
- Made every backend company available to CPNS and BUMN users while retaining the profile target only as setup-page context.
- Added dedicated loading, empty, failure, retry, and disabled-launch states; companies without a suggested role now require explicit role input.
- Resolved active-session company names from the loaded catalog with humanized IDs as the fallback.

### The Reasoning
- Interview companies and their display metadata are backend-owned content, so Flutter should not maintain a second catalog that can drift from Supabase.
- An explicit retry state exposes catalog/API failures instead of silently masking them with an incomplete bundled fallback.

### Verification
- All 33 interview-focused Flutter unit and widget tests passed, including CPNS visibility, nullable role validation, catalog loading, empty, failure, and retry states.
- Targeted Dart analysis for `lib/features/interview` passed with no issues.
- Full Flutter analysis reached only two pre-existing deprecation notices in the unrelated economy payment modal.

### The Tech Debt
- The catalog currently exposes every company profile because `interview_company_profiles` has no activation flag or target classification. Add explicit metadata before product requirements need draft hiding or CPNS/BUMN segmentation.
- InJourney, KAI, and PLN intentionally have no default role until curated suggestions are added to backend-owned data.

## 2026-08-31 - Arena Art Rework and Free Visual Arena Selection

### The Change
- Integrated all 39 supplied art assets: four full arena backgrounds, four poses for each of six characters, seven question-card faces, and intact/destroyed states for both towers.
- Replaced the legacy Squire/Pip presentation with Ody/Opy art while preserving their stable backend item IDs, and refreshed the remaining character and tower visuals without changing economy ownership.
- Reworked the PvP arena picker into a four-option grid and separated the selected visual arena from the CPNS/BUMN learning target. The target still owns question content and matchmaking; the arena is now a free visual preference.
- Rendered the selected background inside the live battle board, mapped every supported question category to its new card art, and switched towers to their dedicated destroyed asset at zero HP.
- Added the four free arenas to the canonical store contract and a Supabase migration that activates them, grants them to existing players, updates legacy loadouts, and assigns the new default to future players.

### The Reasoning
- Arena scenery is cosmetic and should not silently change the player's question bank. Keeping the visual choice independent avoids conflating progression content with presentation while preserving the existing two matchmaking pools.
- Stable character and tower IDs avoid invalidating inventories, Hired Pass rewards, cached loadouts, and server records during the visual replacement.
- Dedicated destroyed tower sprites communicate battle state more clearly than applying opacity and grayscale to the intact artwork alone.

### Verification
- All 148 Flutter tests passed, including arena selection independent of profile target, new asset rendering, and destroyed-tower transitions.
- Flutter release web build completed successfully; analysis found no errors and only the two pre-existing Radio deprecation notices in the payment modal.
- Gate 0 catalog validation and all eight infra tests passed after adding `arena` to the canonical item-type contract.
- Static asset audit confirmed all 39 supplied files exist in the bundle and every one is referenced by runtime code; `git diff --check` passed.

### The Tech Debt
- The supplied character pack does not include replacement projectile art, so battle projectiles still use the existing per-character WebP assets.
- Automated browser visual inspection was unavailable because the browser runtime could not initialize its Windows kernel assets. A physical-device pass should still confirm final crop and scale across the four background aspect ratios.

## 2026-08-31 - App Navigation and Learning Menu

### The Change
- Redesigned the clay navbar into Lobby, Leaderboard, Learning, Analytics, and Profile; added the star-centered Learning fan linked to `/solo`, `/pvp`, and `/interview`; added an empty Analytics route; kept Interview Setup inside the shell with a safe Lobby back fallback; and redirected legacy Practice and Interview Setup links to their canonical destinations without dropping query parameters.

### The Reasoning
- Learning acts as a shared navigation action instead of an empty intermediate page, while explicit glow, navbar, and floating-action layers preserve the clay composition without clipping.

### Verification
- All 26 focused router, navbar, Practice, and Interview tests passed; targeted analysis reported no issues; and `git diff --check` completed cleanly.

### The Tech Debt
- Analytics remains an intentional placeholder, and Solo continues to open the existing Practice page until the next commit introduces its setup flow.

## 2026-09-01 - Solo Draft Compatibility Models

### The Change
- Added Flutter models for the proposed Solo mechanic and question-selection vocabulary, strict JSON serialization/validation, requested-versus-effective configuration, compatibility warnings, and a legacy Practice adapter that intentionally leaves V2 mechanic and selection unknown.
- Mirrored the language-neutral non-operational draft contract without connecting it to repositories, providers, routes, or the existing Practice session flow.

### The Reasoning
- The upcoming Solo setup UI can use typed full-stack vocabulary without implying that Auto is a fourth selection type or that legacy untimed Practice already produces Focus, timing, or V2 learning evidence.

### Verification
- All 14 focused Solo-contract and existing Practice Flutter tests passed; targeted Dart analysis reported no issues; and `git diff --check` completed cleanly.

### The Tech Debt
- The models remain intentionally disconnected until the Solo setup UI commit; operational mechanics, selection, recommendation, delivery, rewards, and `/solo` APIs remain gated by the Step 5a decisions.

## 2026-09-01 - Solo Session Setup UI

### The Change
- Replaced `/solo`'s legacy Practice landing with a clay setup flow for Auto, Balanced, Recommended, and Custom; each option uses an existing PvP arena as its visual identity while unavailable recommendation-backed choices remain explicit.
- Refined the setup hierarchy with a blue clay top bar and solid dark-blue lower base, a concise mode label, shorter card copy, and a persistent outlined `UTAMA` treatment that makes Auto visually discoverable without hiding its unavailable status.
- Added `/solo/topics` by adapting the existing Practice taxonomy UI without its AI Interview action or session mutation, then added `/solo/loadout` with a responsive pace sheet, mode-themed arena, large selected-character preview, owned/locked character cards sourced from the PvP economy catalog, and persisted Riverpod setup state.
- Simplified the loadout into `ATUR LATIHAN`, removed its duplicate configuration preview and selected-name label, compacted the arena and character carousel, grounded the transparent character art with a soft shadow, and reserved navbar clearance so the start action remains visible on standard phone heights.
- Enlarged the arena to a near-square preview and increased character-card size; locked character art now uses an alpha-preserving grayscale matrix instead of `BlendMode.saturation`, preventing gray image rectangles around transparent PNGs.
- Made Solo setup state auto-dispose after the whole Solo route stack is exited and reset when Loadout is popped, so returning to `PILIH MODE` starts without a stale selection while setup still survives forward navigation into Topics, Loadout, or Store.
- Kept the final Start action presentational: it reports that the configuration is saved but performs no API call, grading, timing, reward, or evidence mutation.

### The Reasoning
- Separating question selection from pace and character preparation keeps each screen focused, while reusing PvP assets and legacy taxonomy reads avoids duplicate catalogs without misrepresenting category filters as stable V2 skill IDs.

### Verification
- All 25 focused Solo contract/setup, Practice compatibility, router, and navbar tests passed, including a real Learning-menu-to-`/solo` navigation check; targeted Dart analysis reported no issues; responsive tests cover short-screen cards and the scrollable pace sheet; and `git diff --check` completed cleanly.

### The Tech Debt
- Auto and Recommended remain unavailable until authoritative recommendation data exists; legacy Custom topics remain category/subcategory references; and Focus, Standard, Speed, question selection, character submission, and `/solo/sessions` execution remain intentionally deferred to the approved policy and operational commits.

## 2026-09-01 - Solo Setup PRD Alignment

### The Change
- Reworked the setup into the PRD hierarchy of one recommended `SESI UNTUKMU` and an `ATUR SENDIRI` path combining Focus/Standard/Speed with Seimbang/Rekomendasi/Pilih topik.
- Kept the setup fixed within one viewport, enlarged the image-led recommended action, restored clay depth to the mechanic controls, and added concise descriptions to every manual option while retaining arena artwork for material selection.
- Made recommended and manual selections visually exclusive in both directions, styled unavailable recommendation actions in gray, and reduced the character screen to a compact read-only configuration summary before loadout selection.

### The Reasoning
- The PRD treats the recommended session as a complete preset and manual configuration as an alternative path, so presenting both as simultaneously selected would misrepresent the user's active configuration.

### Verification
- All 8 focused Solo setup, state-reset, router, and navbar widget tests passed; targeted Flutter analysis reported no issues; and `git diff --check` completed cleanly.

### The Tech Debt
- Recommended selection remains unavailable until authoritative recommendation data exists, and Custom still carries legacy category/subcategory references until stable skill-ID delivery is implemented.

## 2026-09-01 - Balanced Standard Solo End-to-End Session

### The Change
- Delivered the initial Standard + Seimbang Solo flow end to end with required 20/35/50 question counts, deterministic CPNS TWK:TIU `6:7` and BUMN TKD:AKHLAK `3:1` allocation, authenticated `/solo` APIs, atomic Supabase session persistence, resumable progress, early stopping, authoritative deadlines, tower HP, completion states, and daily-capped Y-Coin rewards without rank mutation.
- Connected setup and character Loadout to a full PvP-style Solo arena where the selected character attacks a 100-HP tower after correct answers and uses its hit reaction after wrong answers or timeouts; the learner has no HP and the app navbar is hidden during the session.
- Added a server-owned three-card hand that allows the learner to choose among dealt questions, retains each opened card's answer, hint, and Standard deadline, replenishes after resolution, and naturally reduces from three to two, one, and empty without exposing locked future prompts.
- Added a bottom-attached question sheet with direct answer submission, persistent hint access, correct-answer feedback, and post-answer explanations; hint use is stored with the operational answer.
- Added a clay active-session decision that lets the learner resume or explicitly end the previous attempt before starting another, plus safely rerunnable hand migration, PostgREST schema-cache refresh, and nested backend-error handling.
- Preserved the legacy five-question Practice quiz on its compatibility route.

### The Reasoning
- Explicit counts and target-specific weights make the first delivery policy reproducible, while the three-card hand adds tryout-like question choice without surrendering server authority over inventory, timing, resolution, rewards, or resume behavior.

### Verification
- The initial slice passed all 166 Flutter tests, all 19 focused backend Solo tests, and all 8 Gate 0 infra tests. The finalized arena/session changes passed focused Dart analysis, all 19 focused Flutter Solo/navigation tests, and all 20 focused Nest Solo tests; `git diff --check` completed cleanly. Local pgTAP execution remains unavailable because neither Supabase CLI nor `psql` is installed.

### The Tech Debt
- CPNS must adopt a new versioned allocation when approved TKP inventory exists. Opened cards currently retain independent per-question deadlines rather than a global tryout timer; Focus, Speed, Recommended/Custom delivery, the canonical hint endpoint and `learning_attempts` ingestion, difficulty progression, mission/Pass integration, and intentional cross-session repetition remain deferred.
## 2026-09-01 - Learning Analytics Dashboard & Lobby Next-Action Card (Phase 3)

### The Change
- Integrated the sixth navigation tab `Learning` into `AppTabShell` and `AppRouter` (`/learning`), complete with active navigation SVG assets.
- Implemented `LearningPage` with the `_NextActionCard` (hero recommendation with direct Practice launch), `_SummaryGrid` (30-day curriculum coverage, unseen independent accuracy, and pace ratio), `_SkillMap` (status-colored mastery cards), `_RetentionPanel` (scheduled & due spaced review cards), `_AssessmentPanel` (validated score summary), `_ActivityPanel` (active days, question count, and minutes), and `_CompetitionPanel` (isolated PvP battle metrics).
- Created `LearningController`, `LearningState`, and `BackendLearningRepository` connecting to `GET /learning/dashboard` and `POST /learning/recommendations/:id/events` (`shown`, `accepted`, `dismissed`) with graceful `LearningUnavailableException` handling.
- Added `_LobbyLearningCard` in Lobby hero area binding to the current recommendation next-action with automatic `shown` reporting and Practice routing.
- Added widget and unit tests in `test/widget/features/learning/presentation/pages/learning_page_test.dart` and `test/unit/features/learning/`.

### The Reasoning
- Exposing a dedicated Learning tab gives learners transparent, explainable insight into their mastery states, pace, coverage, and retention schedules rather than collapsing progress into an uninformative single score.
- Direct execution of recommended actions from both Lobby and Learning tabs bridges analytics directly into practice without extra configuration steps.

### Verification
- All focused Learning and Lobby widget/unit tests passed.
- Dart analysis reported no new issues.
- Responsive layout verified across compact (360x760) and wide (700x900) viewports.

### The Tech Debt
- Post-session diagnostic result screen still uses legacy Practice quiz summary until Gate 5 Solo delivery migration.

## 2026-09-02 - Restore Learning Route After Solo Merge

### The Change
- Restored the private `/learning` route and its `LearningPage` registration after the Solo route migration dropped that half of the earlier merge.
- Updated stale Learning-to-Practice navigation and router tests to use the canonical Solo and explicitly named legacy compatibility routes.
- Included `/learning` in the Learning navigation-tab active state and repaired the malformed Learning dashboard fixture in the Profile widget test.

### The Reasoning
- The Profile summary must open the dedicated Learning dashboard required by the PRD, while new navigation uses canonical Solo names and keeps `/practice` names isolated as compatibility surfaces.

### Verification
- All 18 focused router, navigation-shell, Learning, and Profile tests passed.
- `flutter build web --debug` completed successfully and produced `build/web`; `git diff --check` completed cleanly.
- Full Flutter analysis has no compiler errors, but still reports six unrelated pre-existing lint/deprecation findings in economy, learning/practice repositories, PvP, and a Practice test.

### The Tech Debt
- Learning recommendation launch metadata still uses the legacy `PracticeLaunchRequest` payload while `/solo` currently opens the generic Solo setup; recommendation-prefilled Solo setup remains a future contract alignment task.

## 2026-09-02 - Solo Arena and Learning Navigation UI Alignment

### The Change
- Made the Lobby mission viewport scroll-safe inside the tab shell, including compact web heights that previously produced a small bottom overflow in Edge.
- Added a reversible, reduced-motion-aware radial transition that makes Solo, PvP, and Interview emerge from the central Learning button instead of appearing abruptly.
- Reworked Solo setup around a runnable Rimba Yudha + Standard + Balanced + 20-question preset and moved the existing manual controls into an animated bottom sheet; mechanic and question-count choices now share one clay card component.
- Added neutral battle presentation primitives for the clay palette, arena frame, tower, character stand, deck, card, and question-sheet frame; PvP and Solo now share the applicable frame, palette, tower, deck, question sheet, and audio path.
- Rebuilt the Solo session as a tower-only arena with one player character, three PvP-style cards, question-only Standard countdowns, attack/impact and hit feedback, profile-controlled arena BGM, relevant SFX, and app lifecycle audio handling.
- Added the PvP-style arena-music volume slider to the Solo pause dialog and deferred correct/wrong character reactions until the learner dismisses answer feedback with `LANJUT`.

### The Reasoning
- One shared presentation vocabulary prevents Solo from drifting away from PvP while keeping Solo's server-owned learning state separate from PvP-only HP, round, combo, opponent, and match-clock concepts.

### Verification
- Added widget coverage for the Edge-sized Lobby shell, intermediate and reverse Learning-menu animation, recommended/manual Solo setup, compact bottom-sheet scrolling, the one-tower arena topology, retained question countdown, pause-dialog volume control, and the deferred correct-answer attack effect; controller coverage also verifies the deferred wrong-answer hit reaction.
- All 185 Flutter tests pass, including the focused Lobby/navigation/Solo/PvP regressions. `flutter build web --debug` succeeds; its Wasm dry run reports only the existing `socket_io_common` JS-interop warning. Focused analysis of the updated Solo controller, UI, and tests reports no issue; full `flutter analyze` remains at six unrelated pre-existing lint/deprecation findings. `git diff --check` passes.

### The Tech Debt
- Evidence-based Recommended/Focus/Speed delivery and recommendation IDs remain gated backend work; the old PvP audio import path is retained only as a compatibility export while the implementation now lives under the shared battle module.


