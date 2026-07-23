# YUDHA Arena — Game Design

Status: redesign source of truth
Updated: July 21, 2026

## 1. Product Promise

YUDHA Arena turns a short practice session into a friendly one-on-one battle. The player always understands three things at a glance: whose turn pressure is rising, what each of the four cards will do, and what changed after an answer.

The experience should feel handcrafted, playful, and modern—not like a collection of unrelated game templates. It uses a small, repeatable visual language: chunky clay objects, bright solid colors, soft depth, clear typography, and restrained motion.

## 2. Design Pillars

1. **One glance, one action.** Each screen has one dominant decision. Supporting information stays quiet.
2. **The answer drives the action.** Cards lead to questions; answers immediately become attacks, heals, HP changes, and score feedback.
3. **Cute competition.** The arena is energetic without looking aggressive or visually noisy.
4. **Chunky and tactile.** Objects look like simple 3D toys made from clay-plastic shapes, with soft studio light and minimal texture.
5. **Consistent, not generated-looking.** Assets share the same camera angle, proportions, palette, edge softness, and light direction. UI avoids excessive gradients, glows, glass panels, and decorative labels.

## 3. Player Flow

```text
Arena entry
  → Choose owned character and arena loadout
  → Choose mode
  → Match intro and 3-second countdown
  → Choose 1 of 4 cards
  → Answer the card's question
  → Resolve answer and launch attack/heal
  → Refill the hand and repeat
  → Match result
  → Claim reward, replay, or return to mode selection
```

The existing phase model remains the implementation contract:

| Phase | Player purpose |
|---|---|
| `preBattle` | Understand the game and enter with confidence. |
| `arenaMenu` | Pick Bot or Player mode. |
| `inBattle` | Choose, answer, and watch the result resolve. |
| `finished` | Understand the outcome and choose the next action. |

## 4. Core Match Rules

### Four-card hand

- Exactly four card slots remain visible whenever enough questions are available. Online sessions may hold more cards server-side; four is the deliberate mobile presentation limit.
- A card communicates category, effect, and power before it is tapped.
- Selecting a card lifts it briefly, then opens its question.
- Opening a question never pauses the battle. Opponent attacks and incoming HP changes continue in real time behind the sheet.
- The selected question is reserved while it is open. Bot actions use their own logical action source and never consume, replace, or reshuffle the player's visible cards.
- A player card leaves the hand only after that player answers it. Correct and wrong answers both consume the used card, then refill only its gap from the remaining pool.
- A disabled or resolving card cannot be tapped twice.

### Answer resolution

Damage is determined by the active combo:

```text
x1 = 5 damage
x2 = 10 damage
x3 = 15 damage
```

| Bot card result | Battle result |
|---|---|
| Correct damage answer | Combo damage to opponent; the same amount becomes player points. |
| Wrong damage answer | `x1` (5) damage reflected to player. |
| Correct heal answer | Full heal to player; half-impact points. |
| Wrong heal answer | Half heal to opponent. |
| Bot damage turn | `x1` (5) damage to player. |
| Bot heal turn | Full heal to opponent. |

Healing still uses `8 + (weight clamped from 1 to 4 × 6)`, and HP
remains clamped from 0 to 100.

### Round structure

- Every round starts both players at 100 HP and lasts 180 seconds.
- A round ends immediately when either HP reaches 0, or when its clock reaches
  0. At timeout, the player with more HP wins; equal HP is a tied round.
- A match has at most three rounds. The first player to two round wins takes
  the match; if three rounds finish without a leader, the match is a draw.
- After a non-final round, the arena announces the winner, counts down from
  three, restores both players to 100 HP, and starts the next round.
- Rating deltas stay `+20` for a match win, `-12` for a match loss, and `0`
  for a draw.

### Visual combo chain

- Every battle starts at `COMBO x1`; the first successful attack uses `proj1`.
- A correct answer advances the next projectile to `x2`, then `x3`, and refreshes a seven-second countdown.
- A wrong answer or an incoming hit lowers the combo by one level. Countdown expiry resets it to `x1`.
- `x1`, `x2`, and `x3` select the equipped character's `proj1`, `proj2`, and
  `proj3` art and deal 5, 10, and 15 damage respectively. Combo never
  multiplies healing or rating.

Online sessions are server-authoritative and asynchronous: both players may
answer independently, public cards do not expose their correct option, and the
server owns combo damage, round clocks, round wins, and final results. The
client mirrors the server clock between updates, waits for the server result
before correctness feedback, and animates incoming HP deltas even when attack
metadata is unavailable.

### Category identity

| Category | Role | Object language | Accent |
|---|---|---|---|
| Numerik / TIU | Damage | Chunky calculator-bolt | Cobalt blue |
| Verbal | Damage | Speech-bubble spell book | Violet |
| Logika | Damage | Friendly robot puzzle core | Orange |
| TWK | Heal | Leaf-and-star guardian shield | Mint green |

Category art is illustrative only. Text labels and gameplay values are rendered by Flutter so they stay sharp, localizable, and accessible.

## 5. Visual Direction

### Asset style

All generated game objects follow this shared art brief:

> Simple cartoon 3D chibi game asset, chunky basic shapes, smooth clay-plastic material, bright solid colors, soft studio lighting from upper left, low detail, minimal texture, cute proportions, clean silhouette, centered object, transparent background, polished mobile arena-game energy, no text, no logo, no frame, no scenery.

Do not imitate existing characters, towers, or emblems from another game. The desired reference is the clarity and playful energy of a modern mobile arena battler, expressed through YUDHA's own shapes and colors.

### Palette

| Token | Color | Use |
|---|---:|---|
| Ink navy | `#17233F` | Primary text and deepest arena contrast. |
| Deep navy | `#0D2A52` | Header surfaces and modal backdrop. |
| Player blue | `#2878F0` | Player side, primary action, numerik. |
| Rival coral | `#F05E5E` | Opponent side and danger feedback. |
| Arena grass | `#7ECF72` | Main play field. |
| River sky | `#71C7F2` | Arena divider and calm secondary accent. |
| Heal mint | `#47CFA0` | Heal and positive feedback. |
| Logic orange | `#FF9F43` | Logika and energetic highlights. |
| Verbal violet | `#8B6FE8` | Verbal category. |
| Reward gold | `#FFC857` | Rewards, power, and victory. |
| Warm canvas | `#FFF8EC` | Before/after-match background. |
| Surface | `#FFFFFF` | Cards and readable content. |

Colors are predominantly solid. Gradients are reserved for subtle lighting within the arena sky/field and must not carry information.

### Shape, type, and depth

- Use an 8-point spacing rhythm.
- Main panels use 20–24 px corner radii; controls use 14–18 px.
- Shadows are short, soft, and slightly colored. Avoid neon glows.
- Use `Fredoka` for short game headings and scores; use `DM Sans` for instructions, questions, and button labels.
- Use sentence case for player-facing copy. Avoid shouting except the short result word if required by an existing test.
- Borders are purposeful: category color, selection, or focus only.

## 6. Screen Specifications

### A. Arena entry — before the match

Purpose: make the loop understandable in under five seconds.

- Warm, uncluttered canvas with a compact top bar and back action.
- A single hero diorama shows the two chibi contenders facing a miniature arena marker.
- The entry screen gives character selection the dominant space: idle art appears in the character list, while a large selected preview uses the ready pose and a clear `READY` state. Locked choices route to Store/Hired Pass.
- Character rarity is presented as Basic, Rare, or Legend. The selector exposes Basic Squire/Pip, Rare Ignis/Brock, and Legend Drakor/Luna because all six characters have complete idle, ready, attack, hit, and projectile 1–3 sets.
- Arena selection remains compact below the character selector, and the combined loadout is previewed before mode selection.
- Headline: a short invitation to battle; one supporting sentence only.
- A compact three-step strip communicates: `Pilih kartu → Jawab → Serang`.
- One dominant `Masuk arena` button sits near the thumb zone.
- No long tutorial cards, ornamental chips, or repeated explanations.

### B. Mode selection

Purpose: choose an opponent without ambiguity.

- Retain the same visual shell as entry for continuity.
- Two large, tactile mode tiles:
  - **Lawan Bot** — clearly available and recommended for quick play.
  - **Lawan Player** — clearly described as random online matchmaking.
- Each tile contains one generated character/object, a one-line description, and a small status pill.
- Selected/tapped state compresses slightly before transition.
- Back is secondary and visually quiet.

### C. Active battle

Purpose: make the four-card decision and its consequence the visual center.

The portrait screen is divided into three stable zones:

1. **Opponent HUD** — avatar, name, concise HP bar, and score.
2. **Arena** — simple clay-like field, one river, one bridge, one hero podium, and two mini towers per side. Decorative detail stays low.
3. **Player deck** — player HUD followed by four readable cards inside a calm bottom tray.

Arena principles:

- The battlefield uses responsive Flutter drawing for grass, river, bridge, lanes, and soft shadows.
- Generated PNG assets provide the contenders, mini towers, and card emblems. Each contender stands at the main focal point on a Flutter-drawn, clay-like general podium instead of a main tower.
- Hero podiums and mini towers are deliberately large, readable targets. Paired shrubs, clay boundary stones, lane pads, and stepping stones keep the field lively without returning to noisy tile decoration.
- Red and blue side ownership is obvious without tinting the entire screen.
- Countdown uses one large number with a short scale/pop animation.
- Characters enter the arena in `idle`, switch to `ready` while the 10-second question is open, use `attack` after a correct answer, and use `hit` when taking damage.
- Hit interrupts `ready`. If a character is already attacking, the attack finishes before its queued hit pose begins.
- Damage starts with the character's attack pose, then launches the equipped character's combo projectile (`proj1`–`proj3`), followed by impact and a floating value.
- Each podium has a contact shadow directly below the character's feet so the sprite reads as standing on the surface instead of floating above it.
- Heal uses a mint pulse and one floating positive value.
- Particles are sparse and disappear quickly.
- Correct/wrong result banners are not shown over the arena; the cast, impact, HP movement, and floating value carry normal combat feedback. A single top banner remains reserved for actionable errors only.

Card anatomy:

```text
category label        power pips
        3D emblem
effect label          impact value
```

- Cards have individual category colors but the same layout.
- Damage/heal and approximate power are visible before selection.
- A selected card rises 8 px and gains a crisp colored outline.
- Used cards fade/slide before the replacement enters.

### D. Question overlay

Purpose: answer quickly without losing match context.

- Use a centered/bottom-adaptive sheet over a dimmed but still recognizable arena.
- Top row: category, effect, power, and—only for Bot sessions—a compact circular timer.
- Prompt uses the largest readable block after the title.
- Four answer options use letters `A–D`, generous touch targets, and a consistent neutral state.
- In Bot mode, reveal correct/wrong color briefly before battle resolution. In Player mode, keep the choice neutral until the server responds.
- Timeout copy is direct and non-judgmental.
- Once the online server accepts an opened card, the sheet cannot be dismissed and has no client-only timeout; it must resolve through a valid answer or an explicit server rule.

### E. Match result — after the match

Purpose: explain the outcome, reward the session, and offer a clear next action.

- Warm canvas reuses the entry shell and characters.
- One outcome object/badge and one outcome color: gold/blue for win, coral for loss, violet/blue for draw.
- Show the result word, a human one-line message, and a clean score comparison.
- One compact reward card contains rating delta and claim state.
- Primary action: `Klaim hadiah` until claimed, then `Main lagi`.
- Secondary actions: `Pilih mode` and `Kembali`.
- Avoid confetti floods, multiple stat grids, glowing panels, and generic motivational filler.

## 7. Motion Language

| Moment | Motion | Duration |
|---|---|---:|
| Button press | Scale to 0.97, then release | 120 ms |
| Screen content enter | Fade + 12 px rise | 220–280 ms |
| Card select | 8 px lift + slight tilt correction | 160 ms |
| Question sheet | Fade + rise | 220 ms |
| Character cast | Anticipation + short lunge toward target | 180–480 ms |
| Projectile | Curved travel after cast anticipation | 620–700 ms |
| Impact | Target bump + value rise | 260–420 ms |
| Heal | Soft scale pulse | 500 ms |
| Result badge | Small overshoot pop | 380 ms |

Motion must communicate state, not decorate idle time. Repeating ambient motion is limited to a very slow character float or flag sway. Respect reduced-motion settings by replacing travel and overshoot with short fades.

## 8. Arena Audio

- Active PvP uses a low-volume, seamless arena loop plus short cues for countdown, card selection, cast, projectile, impact, and heal.
- Audio follows the persisted Profile `soundEnabled` preference, pauses with the pause dialog or app lifecycle, and disposes when the player leaves the battle.
- Arena audio is bundled locally as lightweight mono WAV assets; playback never depends on a network request and audio failure never blocks battle input or state resolution.
- Music stays below combat cues so questions, motion, HP, and card decisions remain the focus.

## 9. Generated Asset Set

Generated source art is exported at high resolution, chroma-keyed to transparent PNG, then displayed smaller in Flutter.

| File | Subject | Composition |
|---|---|---|
| `basic_squire_{idle,ready,attack,hit}.png` | Basic Squire pose set | Full-body state art used by selector and arena. |
| `basic_squire_proj{1,2,3}.png` | Basic Squire projectile set | Combo levels 1–3. |
| `basic_pip_{idle,ready,attack,hit}.png` | Basic Pip pose set | Full-body state art used by selector and arena. |
| `basic_pip_proj{1,2,3}.png` | Basic Pip projectile set | Combo levels 1–3. |
| `rare_ignis_{idle,ready,attack,hit}.png` | Rare Ignis pose set | Full-body state art used by selector and arena. |
| `rare_ignis_proj{1,2,3}.png` | Rare Ignis projectile set | Combo levels 1–3. |
| `rare_brock_{idle,ready,attack,hit}.png` | Rare Brock pose set | Full-body state art used by selector and arena. |
| `rare_brock_proj{1,2,3}.png` | Rare Brock projectile set | Combo levels 1–3. |
| `legend_drakor_{idle,ready,attack,hit}.png` | Legend Drakor pose set | Full-body state art used by selector and arena. |
| `legend_drakor_proj{1,2,3}.png` | Legend Drakor projectile set | Combo levels 1–3. |
| `legend_luna_{idle,ready,attack,hit}.png` | Legend Luna pose set | Full-body state art used by selector and arena. |
| `legend_luna_proj{1,2,3}.png` | Legend Luna projectile set | Combo levels 1–3. |
| `arena_tower_blue.png` | Blue main crown tower | Front 3/4 view, chunky and symmetrical. |
| `arena_tower_coral.png` | Coral main crown tower | Same camera and proportions as blue. |
| `arena_turret_blue.png` | Blue mini tower | Compact, same camera as main tower. |
| `arena_turret_coral.png` | Coral mini tower | Compact, same camera as main tower. |
| `card_numerik.png` | Calculator-bolt emblem | Icon-scale, broad silhouette. |
| `card_verbal.png` | Spell-book speech emblem | Icon-scale, broad silhouette. |
| `card_logika.png` | Robot puzzle-core emblem | Icon-scale, broad silhouette. |
| `card_twk.png` | Leaf-and-star shield emblem | Icon-scale, broad silhouette. |

Main-tower art remains available for catalog/legacy use, but the active arena uses the hero podium as its primary focal point. Mini towers use one undamaged asset each; destroyed state is created consistently in Flutter using desaturation, scale, and tilt rather than separate mismatched images.

## 10. Accessibility and Responsive Rules

- Interactive targets are at least 44 × 44 logical pixels.
- Important text and HP information meet readable contrast against their surfaces.
- Color is never the only signal: labels, icons, numbers, and shapes reinforce it.
- Cards remain usable at the supported narrow-phone width without horizontal scrolling.
- Long names and localized copy use truncation or flexible layout, never overlap.
- The question sheet can scroll on short screens and remains visible above the keyboard/system insets.
- Safe areas are respected on every phase.

## 11. Technical Boundaries

- Preserve `BattleController`, `BattleStateMachine`, repository contracts, reward behavior, route `/pvp`, and current test-visible flow.
- `PvpPage` remains the phase router.
- Keep visual widgets in `features/pvp/presentation/pages/pvp_page/`.
- Keep rules out of widgets; animation may react to state but may not decide battle outcomes.
- `VS Player` keeps the existing Socket.IO random-matchmaking and server-authoritative contracts; the visual redesign does not replace them with a local simulation or room code.
- Visual assets live under `apps/mobile/assets/game/`; arena audio lives under `apps/mobile/assets/audio/`. Neither depends on runtime downloads.

## 12. Acceptance Criteria

- Entry, mode selection, battle, question, and result screens all use one cohesive visual system.
- The player can explain the loop from the entry screen without opening extra help.
- Four distinct cards are readable and tappable on a medium Android phone.
- Choosing a card opens its question; resolving the answer produces a visible attack/heal and HP update.
- Character art follows idle, ready, attack, and hit state priority, and the podium contact shadow keeps both feet visually grounded.
- Consecutive correct answers expose combo projectiles 1–3; wrong answers, incoming hits, and timeout lower or reset the combo as specified.
- Win, loss, and draw states are visually distinct and expose the correct next actions.
- Existing PvP unit and widget tests pass; added widget tests cover key before/battle/after labels and all four card slots.
- `flutter analyze` introduces no new warnings in the redesigned files.
- The final screen is visually checked on `emulator-5554` at the entry, mode, battle, question, and result phases.
