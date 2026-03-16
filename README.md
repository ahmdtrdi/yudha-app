# YUDHA App (Your Ultimate Digital Hiring Arena)


YUDHA App is a gamified learning platform focused on CPNS, BUMN, and kedinasan preparation. The product combines competitive quiz battles, structured practice, and performance tracking to turn exam preparation into an engaging mobile-first experience.

## Project Structure

```text
yudha-app/
|- apps/
|  |- mobile/         # Flutter mobile client (Android/iOS)
|  |- backend-api/    # NestJS app backend (auth, profile, leaderboard, content, rag-api, agentic ai)
|  |- backend-game/   # NestJS realtime game backend (matchmaking, PvP battle state)
|- contracts/         # Shared API and socket event contracts
|- infra/             # Deployment and infrastructure configuration
|- docs/              # Product and technical documentation
```

### Structure Notes

- `apps/mobile` contains the user-facing mobile application.
- `apps/backend-api` handles business features and persistent app data access.
- `apps/backend-game` handles realtime gameplay flow and in-match synchronization.
- `contracts` keeps backend and frontend communication definitions aligned.
- `infra` centralizes deployment-related setup.
- `docs` stores architecture, feature, and operational notes.
