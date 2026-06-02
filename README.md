# YUDHA App

<p align="center">
  <img src="apps/mobile/assets/branding/logo-color-landscape.png" alt="YUDHA Logo" width="320" />
</p>

<p align="center">
  <b>Your Ultimate Digital Hiring Arena</b><br/>
  Gamified learning for CPNS and BUMN preparation.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Mobile-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/NestJS-Backend-E0234E?logo=nestjs&logoColor=white" alt="NestJS" />
  <img src="https://img.shields.io/badge/Socket.IO-Realtime-010101?logo=socketdotio&logoColor=white" alt="Socket.IO" />
  <img src="https://img.shields.io/badge/Status-Active%20Prototype-0A7D58" alt="Status" />
</p>

## Overview

YUDHA turns exam prep into a mobile-first arena experience:

- **PvP battle flow** with quiz-driven attacks.
- **Practice modules** for CPNS/BUMN tracks.
- **Interview prep simulation** for communication readiness.
- **Leaderboard + progression** to maintain momentum.

## App Sections

| Icon | Section | Purpose |
|---|---|---|
| <img src="apps/mobile/assets/icons/navigation/nav_lobby_active.svg" alt="Lobby" width="24" /> | Lobby | Home command center, daily quests, and quick actions |
| <img src="apps/mobile/assets/icons/navigation/nav_pvp_active.svg" alt="PvP" width="24" /> | PvP | Realtime battle mode and match loop |
| <img src="apps/mobile/assets/icons/navigation/nav_rank_active.svg" alt="Rank" width="24" /> | Rank | Competitive leaderboard and player standing |
| <img src="apps/mobile/assets/icons/navigation/nav_practice_active.svg" alt="Practice" width="24" /> | Practice | Topic-based question training and interview entry |
| <img src="apps/mobile/assets/icons/navigation/nav_profile_active.svg" alt="Profile" width="24" /> | Profile | Target setup and personalization |

## Repository Structure

```text
yudha-app/
|- apps/
|  |- mobile/         # Flutter app (Android/iOS)
|  |- backend-api/    # NestJS API (auth/profile/content/leaderboard)
|  |- backend-game/   # NestJS realtime service (PvP/match state)
|  |- games/          # Browser PvP prototype (web mini-game)
|- prototype/         # High-fidelity HTML prototype flows
|- contracts/         # Shared API/socket contracts
|- infra/             # Deployment and infra setup
|- docs/              # Product + technical docs
```

## Tech Stack

- **Mobile:** Flutter, Riverpod, GoRouter, Flutter SVG, Google Fonts
- **Backend:** NestJS, TypeScript, Socket.IO
- **Data/Auth:** Supabase
- **Realtime Infra:** Redis (for game backend workflows)

## Getting Started

### Prerequisites

- Node.js `>= 20`
- npm
- Flutter SDK (project currently targets Dart SDK `^3.11.1`)
- Optional for game backend: Redis (local or cloud)

### 1) Backend API

```bash
cd apps/backend-api
cp .env.example .env
# PowerShell: Copy-Item .env.example .env
npm install
npm run start:dev
```

Default env uses `PORT=3000`.

### 2) Backend Game (Realtime)

```bash
cd apps/backend-game
cp .env.example .env
# PowerShell: Copy-Item .env.example .env
npm install
npm run start:dev
```

Set `PORT=3001` in `.env` if API is already on `3000`.

### 3) Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run
```

### 4) Prototype Flow (HTML)

Open directly in browser:

- `prototype/index.html`
- `prototype/interview.html`

## Useful Commands

### Backend (both NestJS services)

```bash
npm run build
npm run test
npm run lint
```

### Mobile

```bash
flutter analyze
flutter test
```

## Assets

Branding and navigation assets are in:

- `apps/mobile/assets/branding/`
- `apps/mobile/assets/icons/navigation/`
- `apps/mobile/assets/game/`

## License

This repository is currently **private/internal** and does not yet define a public OSS license.
