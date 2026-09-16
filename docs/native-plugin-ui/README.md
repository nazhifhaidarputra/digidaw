# Native Plug-in UI Migration Tracker

This directory tracks the Rust-owned native plug-in UI migration. The design source is
`architecture-plan.md`; phase files are the resumable implementation record.

## Current status

- Active phase: 02 — editor binding policy
- Overall status: in progress
- Target branch: `feat/vst3`
- Commit author: `the_great_anoa <nazhifhaidarputra@gmail.com>`
- Push policy: never push from this implementation task

## Phase index

1. [Shared contracts](phase-01-shared-contracts.md) — complete
2. [Editor binding policy](phase-02-editor-binding.md)
3. [Platform stubs](phase-03-platform-stubs.md)
4. [GLib owner runtime](phase-04-glib-runtime.md)
5. [Linux X11/XWayland](phase-05-linux-x11.md)
6. [Linux Wayland](phase-06-linux-wayland.md)
7. [VST3 migration](phase-07-vst3-migration.md)
8. [Self-bootstrap](phase-08-self-bootstrap.md)
9. [Runner cleanup](phase-09-runner-cleanup.md)
10. [Cooperative VST3 work](phase-10-cooperative-vst3.md)
11. [Flutter/Vital acceptance](phase-11-flutter-vital.md)

## Tracker convention

Each phase records its status, completed work, decisions, validation, blockers, and exact next
action. Update the active tracker before ending a session and mark a phase complete only after its
focused validation passes.
