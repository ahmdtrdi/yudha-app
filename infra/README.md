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
