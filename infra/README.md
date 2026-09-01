# Backend provisioning

Gate 0–1 authoritative inputs live under `contracts/`. The generated CPNS and BUMN banks are development content and must not be marked SME-approved without external review.

From `infra/`, start local Supabase and provision a clean database:

```sh
npm ci
npm exec -- supabase start
npm run provision:local
```

`provision:local` resets and migrates the database, synchronizes the Store and August 2026 Hired Pass manifests, and imports both question banks. It reconciles legacy rows by source key and then normalized content fingerprint.

Use the verification form in CI or before handoff. It immediately repeats the unchanged synchronization, which must report all 350 questions as skipped:

```sh
npm run provision:verify
npm exec -- supabase test db
```

For an already migrated environment, set `SUPABASE_URL` and either `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY`, then run `npm run sync:content`.

## Learning V2 workflows

After both Learning SQL checkpoints pass, the idempotent Phase 2 workflows are
available through one CLI:

```sh
npm run learning:v2 -- sync
npm run learning:v2 -- backfill practice --run-key practice-20260901
npm run learning:v2 -- backfill practice --apply --run-key practice-20260901
npm run learning:v2 -- backfill pvp --apply --run-key pvp-20260901
npm run learning:v2 -- rebuild --user-id <uuid> --target cpns
```

Fixture commands additionally require the same disposable user UUID twice. This
is a deliberate safety boundary and must never point at a real learner:

```sh
npm run learning:v2 -- fixture seed --user-id <uuid> --confirm-disposable <uuid> --run-key mixed-1 --scenario mixed
npm run learning:v2 -- fixture invalidate --user-id <uuid> --confirm-disposable <uuid> --run-key mixed-1 --reason "cloud smoke complete"
```

Dry-run backfill is read-only. Legacy unknown revision, exposure, hint, timing,
or skill data remains null and is excluded from unsupported proficiency
metrics. Fixture invalidation appends invalidation rows and queues a rebuild; it
does not delete canonical attempts.
