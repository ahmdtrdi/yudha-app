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
