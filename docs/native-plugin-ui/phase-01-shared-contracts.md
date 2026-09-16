# Phase 01 — Shared contracts

- Status: complete
- Commit: `feat(host): define native UI contracts`

## Checklist

- [x] Add shared types, errors, handles, events, and platform traits.
- [x] Add checked window ID allocation and surface selection.
- [x] Add target-specific dependency declarations.
- [x] Add focused unit tests.
- [x] Run formatting and `karbeat-host` tests.

## Decisions

- Window sizes are logical client-area units and are validated at the operation boundary.
- Raw handles are valid only while their owning native window remains alive.

## Validation

- `rustfmt --edition 2024` on changed Rust sources: passed.
- `cargo test -p karbeat-host`: 23 unit tests and 3 doc tests passed.
- Workspace-wide `cargo fmt --check` is currently blocked by unrelated baseline formatting drift.

## Next action

Implement the shared editor binding lifecycle and event policy.
