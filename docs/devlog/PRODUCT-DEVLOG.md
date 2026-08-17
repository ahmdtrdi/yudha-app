# Product Dev Log

## 2026-08-17 — Consolidate the MVP product contract

### Change

- Rewrote `docs/PRD.md` in English as the single source of truth for YUDHA MVP product behavior, business rules, service boundaries, public contracts, delivery gates, and release acceptance.
- Resolved the documented gaps for Practice, battle effects and progression, WIB daily missions and streak, target-owned arenas, Private rooms, beta Y-Coin behavior, Hired Pass seasons, ad stubs, deterministic recommendations, and paid AI Interview sessions.
- Defined provider-neutral text SSE, recorded-voice, and live-voice contracts; stable REST/socket errors; mutation idempotency; authoritative ledgers; versioned Store catalogs; and versioned Hired Pass season manifests.
- Marked archived gap documents and `docs/PRD-AI-INTERVIEW.md` as subordinate to the canonical MVP contract when conflicts exist.

### Product reasoning

- Product mechanics are fixed in the PRD so clients and services cannot independently invent progression, monetization, battle, or Interview behavior.
- Content that must vary by release is bounded to checked-in, validated catalogs and season manifests without weakening the mechanics in the PRD.
- The beta economy remains paymentless: the repeatable `100 Y-Coin` `GRATIS` credit and once-per-season beta Hired Pass activation are server-authoritative, while real payment and production ads remain post-MVP.
- Daily rank missions, Ranked deltas, Y-Coin, and seasonal Pass Points are separate balances with explicit ordering, expiry, and idempotency rules.

### Remaining implementation debt

- Audit Mobile, App Backend, Game Backend, database migrations, AI adapters, deployment configuration, catalogs, season manifests, and automated tests against the rewritten contract.
- Remove production local-authority fallbacks and reconcile any existing endpoint, event, schema, or enum that differs from the PRD.
- Build and preserve acceptance evidence for WIB boundaries, concurrent ledger mutations, two-instance Redis behavior, all Interview transports, two-device journeys, accessibility, recovery, and the pilot load targets.

No product feature code was changed in this documentation-only consolidation.
