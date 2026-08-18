# Shared backend contracts

`openapi/yudha-api.v1.json` is the language-neutral PRD REST contract. Every operation carries `x-delivery-gate`; a future gate tag documents the target contract and does not claim that the endpoint is implemented today.

Successful mutations and reads use a `{ "data": ... }` envelope. Paginated results put `items`, `limit`, `offset`, and `total` inside `data`. Errors use `{ "error": { "code", "message", "details", "requestId" } }`.

Practice answer and finish mutations require a caller-generated `idempotencyKey`. Retrying the same key with identical input returns the committed response without repeating side effects. Reusing the key for different input returns `IDEMPOTENCY_KEY_REUSED`.

Authoritative versioned inputs are under `content/`; their JSON Schemas are under `schemas/`, and executable cross-file validation is `npm run validate:gate0` from `infra/`. The CPNS/BUMN content is explicitly development-only until external SME approval changes both `approvalStatus` and `smeApproved` through the content review process.
