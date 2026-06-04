# YUDHA Flutter Game Design

Current as of June 2, 2026.

This document explains the current Flutter PvP game flow in `apps/mobile`. It describes what is implemented now, where it lives, and what happens when a player enters a battle.

## Scope

The active Flutter game mode is the PvP arena at route `/pvp`.

The old browser prototype has been removed. `apps/games/data` is kept only as a question data source, while the playable game experience lives in `apps/mobile`.

## Source Map

| Area | File |
|---|---|
| Route registration | `apps/mobile/lib/app/router/app_routes.dart` |
| GoRouter screen mapping | `apps/mobile/lib/app/router/app_router.dart` |
| PvP page orchestration | `apps/mobile/lib/features/pvp/presentation/pages/pvp_page.dart` |
| Question bottom sheet | `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/question_battle_sheet.dart` |
| Arena entry preview | `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/arena_entry_section.dart` |
| Arena mode menu | `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/arena_menu_section.dart` |
| Active battle UI | `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/in_battle_section.dart` |
| Result and status UI | `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/result_status_section.dart` |
| Battle state controller | `apps/mobile/lib/features/pvp/application/battle_controller.dart` |
| Repository providers | `apps/mobile/lib/features/pvp/application/battle_providers.dart` |
| Battle state model | `apps/mobile/lib/features/pvp/domain/entities/battle_state.dart` |
| Battle enums | `apps/mobile/lib/features/pvp/domain/entities/battle_enums.dart` |
| Battle question model | `apps/mobile/lib/features/pvp/domain/entities/battle_question.dart` |
| Turn resolution rules | `apps/mobile/lib/features/pvp/domain/services/battle_state_machine.dart` |
| Mock questions | `apps/mobile/lib/features/pvp/data/repositories/mock_question_bank.dart` |
| Progress rewards | `apps/mobile/lib/features/gamification/application/player_progress_controller.dart` |

## Player Flow

1. Player opens the PvP tab at `/pvp`.
2. `PvpPage` watches `battleControllerProvider` and the player's display name.
3. Initial state is `BattlePhase.preBattle`.
4. Player taps the entry CTA and the controller calls `enterArena()`.
5. State changes to `BattlePhase.arenaMenu`.
6. Player chooses `VS Bot` or `VS Player`.
7. Controller sets `BattleMode.bot` or `BattleMode.online`.
8. `startBattle()` loads a `BattleSessionSeed` from the active repository.
9. State changes to `BattlePhase.inBattle`.
10. The battle screen runs a 3 second countdown.
11. Player picks question cards from a visible hand of up to 4 cards.
12. Each selected card opens a 10 second question sheet.
13. Correct or wrong answers are resolved by `BattleStateMachine`.
14. Battle ends when a player HP reaches 0.
15. Result screen shows outcome, score, remaining HP, and reward action.
16. Player can claim reward, play again, or return to arena menu.

## Battle Phases

| Phase | Meaning |
|---|---|
| `preBattle` | Landing/entry screen before the arena menu. |
| `arenaMenu` | Mode selection screen: `VS Bot`, `VS Player`, or back home. |
| `inBattle` | Active arena with HUD, towers, cards, effects, and bot timing. |
| `finished` | Result screen after win, lose, or draw. |

`PvpPage` is intentionally the phase router. It decides which section widget to show, while the widgets in `pvp_page/` handle presentation details.

## Modes

| Mode | Current behavior |
|---|---|
| `BattleMode.bot` | Uses `BotBattleRepository`, loads mock questions, and schedules automated bot turns every 3.3 to 5.9 seconds after countdown. |
| `BattleMode.online` | Uses `OnlineBattleRepository`, loads mock questions, and shows a local room-code dialog before starting. This is a simulated player match, not realtime networking yet. |

## Question Rules

Questions use `BattleQuestion`:

- `id`: unique question/card id.
- `prompt`: question text.
- `options`: answer options.
- `correctOptionIndex`: correct option position.
- `weight`: difficulty/impact weight.
- `effect`: `damage` or `heal`.
- `category`: usually `numerik`, `twk`, `verbal`, or `logika`.

Impact is calculated by:

```text
impact = 8 + (weight.clamp(1, 4) * 6)
```

So weight 1 gives 14 impact, weight 2 gives 20, weight 3 gives 26, and weight 4 gives 32.

Current category behavior:

| Category | Effect |
|---|---|
| `twk` | Heal card. Correct answer heals the player. Wrong answer heals the opponent. |
| `numerik` | Damage card. Correct answer damages opponent. Wrong answer reflects partial damage to player. |
| `verbal` | Damage card with wizard visual effect. |
| `logika` | Damage card with robot visual effect. |
| Other | Damage card with cannon/default visual effect. |

## Turn Resolution

Player turn:

- Correct damage answer: opponent HP decreases by full impact; player points increase by full impact.
- Wrong damage answer or timeout: player HP decreases by `max(1, impact ~/ 2)`; opponent points increase by that reflected damage.
- Correct heal answer: player HP increases by full impact; player points increase by `max(1, impact ~/ 2)`.
- Wrong heal answer: opponent HP increases by `max(1, impact ~/ 2)`; opponent points increase by that heal amount.

Bot turn:

- Bot picks a damage card when possible, otherwise it falls back to the first available card.
- Damage card: player HP decreases by full impact; opponent points increase by full impact.
- Heal card: opponent HP increases by full impact; opponent points increase by `max(1, impact ~/ 2)`.

HP is clamped between 0 and 100.

## Card Pool

At battle start, the repository returns a question list.

The active battle UI displays a stable hand of up to 4 cards. When a selected card is answered, the state machine removes that question from `availableQuestions`. The UI keeps existing hand cards in place where possible and fills gaps from the remaining pool.

When the pool is exhausted, the state machine recycles the questions with fresh IDs and shuffles them, excluding the question that was just answered.

## Win, Lose, Draw

The game continues while both players have HP above 0.

When one or both HP values reach 0, the state changes to `finished`:

| Condition | Outcome |
|---|---|
| Opponent HP is 0 and player HP is above 0 | Win |
| Player HP is 0 and opponent HP is above 0 | Lose |
| Both HP reach 0 | Draw |

The state machine also has fallback comparisons by HP and points, but normal completion is HP driven.

Rating/EXP delta:

| Outcome | Delta |
|---|---:|
| Win | `+20` |
| Lose | `-12` |
| Draw | `0` |

## Rewards And Progress

On the result screen, `CLAIM REWARD` calls:

1. `playerProgressProvider.notifier.applyBattleResult(...)`
2. `battleController.markRewardClaimed()`

Progress currently updates:

- total points, clamped from 0 to 99999
- wins
- losses
- draws
- current streak
- best streak
- last delta

Claiming reward is guarded by `rewardClaimed`, so one battle result is only applied once.

## Visual Flow

The PvP arena is the main dark/high-energy game surface in the otherwise light-first app.

Current visual layers:

- entry preview uses avatar and arena preview widgets
- menu uses a dark animated transition overlay
- in-battle arena uses tower image assets and `CustomPainter` battlefield/effects
- question cards use TIU/TWK card assets
- result screen switches accent by outcome

Important asset paths are under:

```text
apps/mobile/assets/game/
```

## Current Gaps

- `VS Player` is a local simulation. It does not yet create or join a realtime backend room.
- Room code validation only accepts the locally generated code in the dialog.
- `BattleController.surrenderBattle()` exists, but the current pause dialog resets to the arena menu instead of using surrender.
- Battle questions are loaded from `assets/game/questions.json` when available and fall back to hardcoded samples.
- Persistent profile/progress storage is not wired yet; progress is Riverpod state for the current app session.

## Maintenance Notes

- Keep game rules in `BattleStateMachine`, not in widgets.
- Keep async session setup in repositories and `BattleController`.
- Keep `PvpPage` focused on phase routing and dialog orchestration.
- Add new arena UI pieces inside `apps/mobile/lib/features/pvp/presentation/pages/pvp_page/`.
- Add or update unit tests for rules in `test/unit/features/pvp/domain/services/battle_state_machine_test.dart`.
- Add or update widget tests for player-visible flow in `test/widget/features/pvp/presentation/pages/pvp_page_test.dart`.
