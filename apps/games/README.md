# Web Royale 🏰⚔️

A Clash Royale-inspired browser game with a **quiz mechanic** — answer correctly to launch your attack!

## 📁 File Structure

```
webroyale/
├── index.html          ← Main game shell (towers, HUD, modal)
├── css/
│   └── style.css       ← All styling (game, cards, modal, effects)
├── js/
│   ├── config.js       ← Cards, tower positions, game constants
│   ├── questions.js    ← Question bank (4 categories, 30+ questions)
│   ├── ui.js           ← All UI rendering (HP bars, cards, modal, damage text)
│   └── game.js         ← Game loop, projectiles, enemy AI, state
└── assets/             ← ⚠️ PUT YOUR PNG FILES HERE
```

## 🖼️ Required Assets

Place all PNG files inside the `assets/` folder:

| File | Used for |
|------|----------|
| `blue_maintower.png` | Player main tower |
| `blue_maintower_destroyed.png` | Player main tower (destroyed) |
| `blue_minitower.png` | Player side towers |
| `blue_minitower_destroyed.png` | Player side towers (destroyed) |
| `red_maintower.png` | Enemy main tower |
| `red_maintower_destroyed.png` | Enemy main tower (destroyed) |
| `red_minitower.png` | Enemy side towers |
| `red_minitower_destroyed.png` | Enemy side towers (destroyed) |
| `blue_avatar.png` | Player avatar chip |
| `red_avatar.png` | Enemy avatar chip |
| `attack_side_blue.png` | Blue side-attack projectile |
| `attack_side_red.png` | Red side-attack projectile |
| `attack_stright_blue.png` | Blue straight projectile |
| `impact_explosion.png` | Hit explosion VFX |
| `tiu_card.png` | Card image for "Think Strike" |
| `twk_card.png` | Card image for "Shield Blast" |

## 🎮 How to Play

1. Open `index.html` in your browser (use Live Server for best results)
2. **Click a card** → A question pops up with a 10-second timer
3. **Answer correctly** → Your attack launches toward the enemy tower!
4. **Answer wrong / timeout** → No elixir cost, but attack is cancelled
5. The **red enemy AI** attacks randomly every 3–7 seconds
6. Destroy the **enemy main tower** to win 🏆

## 🃏 Cards

| Card | Cost | Damage | Category |
|------|------|--------|----------|
| Fire Cannon | 2💜 | 250 | Math |
| Blue Orb | 3💜 | 400 | Science |
| Think Strike | 4💜 | 600 | Logic |
| Shield Blast | 5💜 | 900 | General Knowledge |

## 🛠️ Customising

- **Add questions**: Edit `js/questions.js` — add entries to any category array
- **Add cards**: Edit `js/config.js` — add to the `CARDS` array and assign a category
- **Adjust difficulty**: In `js/config.js`, change `ENEMY_ATTACK_INTERVAL_MIN/MAX`
- **Change tower HP**: Edit `CONFIG.TOWER_HP` in `js/config.js`
