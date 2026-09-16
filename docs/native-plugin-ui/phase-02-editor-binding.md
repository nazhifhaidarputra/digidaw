# Phase 02 — Editor binding policy

- Status: complete
- Commit: `feat(host): centralize native editor binding policy`

## Completed

- Encapsulated created, attached, visible, closing, and closed transitions.
- Added stale-event rejection, programmatic resize suppression, metrics updates, and idempotent
  close requests.
- Kept the native window alive until the caller records editor detachment and finishes closing.

## Validation

- `cargo test -p karbeat-host`: 28 unit tests and 3 doc tests passed.

## Next action

Add the compile-visible static platform aliases and unavailable stubs.
