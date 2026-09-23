# Phase 1: Linux Regression Baseline

Status: Environment pending

The implementation host is Windows and has no Linux Rust target or Linux GLib development environment, so the Linux host API, Vital, editor, scanner, and processor-retirement suites could not be captured locally before the refactor.

The available pre-change Windows baseline was recorded:

- `cargo test -p karbeat-host-api`: 16 passed and 1 failed.
- The existing failure was `scanner::tests::multiple_classes_deduplicate_by_identity_and_keep_a_valid_selected_location` (`left: 0`, `right: 2`).
- No implementation change was made to that scanner deduplication behavior.

Remaining acceptance work:

- Run the plan's Linux host API, VST3, Vital, editor, scanner, and processor-retirement tests in a Linux environment.
- Compare results with the known branch baseline before merging.
