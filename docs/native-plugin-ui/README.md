# Native Plug-in UI Migration Tracker

This directory tracks the Rust-owned native plug-in UI migration. The design source is
`architecture-plan.md`; phase files are the resumable implementation record.

## Current status

- Active phase: [12 — Hosted plug-in audio correctness](phase-12-audio-correctness.md)
- Overall status: follow-up in progress
- Target branch: `feat/vst3`
- Commit author: `the_great_anoa <nazhifhaidarputra@gmail.com>`
- Push policy: never push from this implementation task

## Phase index

1. [Shared contracts](phase-01-shared-contracts.md) — complete
2. [Editor binding policy](phase-02-editor-binding.md) — complete
3. [Platform stubs](phase-03-platform-stubs.md) — complete
4. [GLib owner runtime](phase-04-glib-runtime.md) — complete
5. [Linux X11/XWayland](phase-05-linux-x11.md) — complete
6. [Linux Wayland](phase-06-linux-wayland.md) — complete
7. [VST3 migration](phase-07-vst3-migration.md) — complete
8. [Self-bootstrap](phase-08-self-bootstrap.md) — complete
9. [Runner cleanup](phase-09-runner-cleanup.md) — complete
10. [Cooperative VST3 work](phase-10-cooperative-vst3.md) — complete
11. [Flutter/Vital acceptance](phase-11-flutter-vital.md) — complete
12. [Hosted plug-in audio correctness](phase-12-audio-correctness.md) — in progress

## Tracker convention

Each phase records its status, completed work, decisions, validation, blockers, and exact next
action. Update the active tracker before ending a session and mark a phase complete only after its
focused validation passes.
