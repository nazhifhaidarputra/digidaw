# Phase 7: Scanner Hardening

Status: Implemented and unit tested

Completed:

- Initialized an STA COM apartment in the Windows scanner process.
- Preserved direct `.vst3` module loading and bundle resolution under `Contents/<architecture>-win`.
- Added Windows tests for direct modules, valid architecture bundles, and wrong-architecture rejection.
- Kept module entry-point and class-ID behavior unchanged.

Verification:

- The targeted Windows module-path test passed.
- The scanner binary target compiled as part of VST3 checks/tests.

Known baseline issue:

- The pre-existing host API scanner deduplication test still fails independently of these Windows path changes; see Phase 1.

Remaining acceptance work:

- Scan installed Windows VST3 bundles, including an architecture mismatch, in the packaged application.
