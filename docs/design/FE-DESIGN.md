# YUDHA Design Guide v1.1

> Elite digital gladiator preparing for career victory: trustworthy, modern, and competitive.

---

## 1) Brand Direction (Locked)

- Brand balance: **60% professional, 40% game**
- App theme strategy: **Light-first**
- Primary brand color: **Warrior Navy**
- Logo wordmark font: **Logam** (logo only)

### Why this direction

- The logo mark and wordmark are already strong and modern, so the product should feel credible first, gamified second.
- A light-first UI improves readability and trust for study-heavy flows.
- Dark arena treatment can be used selectively in PvP moments for excitement.

---

## 2) Color System

| Token | Hex | Role |
|---|---|---|
| `warriorNavy` | `#013192` | Primary brand, nav, key surfaces |
| `scholarCream` | `#FFF6E9` | Warm light background and readable light surfaces |
| `levelUpTeal` | `#00889E` | Secondary accent, active/progress states |
| `fireGold` | `#FFAB5B` | Special emphasis (reward, achievement, key highlight) |
| `surfaceLight` | `#F8F5EE` | App default page background (light-first) |
| `surfaceDark` | `#0B1633` | PvP arena and high-intensity dark sections only |

### Usage rules

- **Primary button**: Navy background, cream/light text.
- **Secondary button**: Transparent/light surface with teal border and teal text.
- **Gold accent**: Use sparingly for high-value moments only (win/result/reward), not as default CTA everywhere.
- **Default app background**: `surfaceLight`, not pure white.

---

## 3) Typography System

| Layer | Font | Weights | Usage |
|---|---|---|---|
| Logo only | Logam | default | Wordmark only (`YUDHA`) |
| Display / headings | Orbitron | 600, 700, 900 | Hero, section titles, game headers |
| Body / UI | DM Sans | 400, 500, 600 | Paragraphs, labels, inputs, buttons |
| Data / stats | JetBrains Mono | 400, 600 | Scores, badges, compact metrics |

### Non-negotiables

- Do not use Logam outside the logo.
- Do not use Orbitron for body text.
- Use font fallbacks in app runtime for reliability.

---

## 4) Spacing and Radius

### Spacing rule

- Base system: **8pt grid**
- Allowed half-step: **4px** for micro alignment only (icon-gap, tiny badges)

Token set:

- `space-xxs`: 4
- `space-xs`: 8
- `space-sm`: 16
- `space-md`: 24
- `space-lg`: 32
- `space-xl`: 48
- `space-2xl`: 64
- `space-3xl`: 96

### Radius rule

- `radius-sm`: 8
- `radius-md`: 12
- `radius-lg`: 16
- `radius-xl`: 20
- `radius-pill`: 100

---

## 5) Theming Strategy (Light-First)

### Default app surfaces

- Background: light (`surfaceLight` / cream variants)
- Cards: white/cream with soft shadow
- Text: navy-led dark text tones

### Dark usage scope

- PvP arena
- result overlays
- special challenge moments

Rule: dark mode is a **feature mood**, not the default global shell.

---

## 6) UI Behavior Principles

- Professional first, game second.
- Competitive language is welcome, but never childish.
- Keep interactions clear before decorative effects.
- Strong game visuals should concentrate in PvP and victory flows.

Voice examples:

- Do: "Prepare for battle", "Unlock next level", "Victory secured"
- Avoid: "fun little quiz", "quick and easy", "just play"

---

## 7) Flutter Token Mapping (Implementation Reference)

Use these tokens in `ThemeData` / `ThemeExtension`:

- `AppColors`: navy, cream, teal, gold, surfaceLight, surfaceDark
- `AppSpacing`: 4, 8, 16, 24, 32, 48, 64, 96
- `AppRadii`: 8, 12, 16, 20, 100
- `AppTypography`: display/body/mono style groups

Implementation guidance:

- Keep one central token source in `lib/core/theme`.
- Do not hardcode raw hex values in feature widgets unless temporary.
- PvP screen may override with arena-specific dark palette while preserving global tokens.

---

## 8) Final Consistency Rules

- Balance remains **60/40** (professional/game).
- Primary remains **Navy**.
- App default remains **Light-first**.
- Logo wordmark remains **Logam-only**.

---

YUDHA Design System v1.1
