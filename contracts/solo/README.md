# Solo draft compatibility contract

This directory mirrors the proposed Solo vocabulary from
`docs/LEARNING-SYSTEM-V2-DRAFT.md` for backend and mobile development.

It is deliberately non-operational:

- it does not add or authorize `/solo` API mutations;
- it does not replace the PRD-aligned OpenAPI contract;
- it does not select questions, resolve mechanics, or define delivery policy;
- it does not reinterpret legacy Practice evidence as V2 evidence.

`solo-session-configuration.v2-draft.schema.json` defines the request shape
that can be shared while the policy decisions blocking the V2 builder remain
open. Backend and mobile implementations must reject invalid values, preserve
requested and effective configuration separately, and leave effective values
unknown for legacy Practice compatibility records.
