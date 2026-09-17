# Phase 12 — Hosted Plug-in Audio Correctness

## Status

In progress.

## Scope

Follow-up defects found during live Vital testing after the native editor migration:

- preserve instrument release envelopes after NoteOff;
- remove plug-in-output clicks caused by buffer-boundary resets;
- reconfigure live hosted plug-ins when the DSP sample rate changes;
- keep long native preparation work from blocking synchronous Flutter telemetry.

## Checklist

- [x] Trace MIDI event lifetime and rule out repeated NoteOn delivery.
- [x] Identify zero-tail generator reset as the ADSR/click source.
- [ ] Add a regression test proving an instrument remains processable after NoteOff.
- [ ] Replace live hosted endpoints at a new sample rate on the control/UI owners.
- [ ] Add atomic replacement and rollback-focused Rust tests.
- [ ] Gate Flutter telemetry while DSP configuration performs native work.
- [ ] Run focused Rust and Flutter tests.
- [ ] Run workspace validation and live Vital acceptance where available.
- [ ] Commit the completed follow-up without pushing.

## Decisions

- Generator instances remain active while installed. `tail_samples()` is useful for export length,
  but zero is not a safe signal that a synthesizer's release envelope has become silent.
- VST3 setup and teardown stay off the audio thread. A sample-rate change prepares replacement
  endpoints first, swaps them atomically in the engine, and retires the old instances afterward.

## Validation

Pending.

## Blockers

None.

## Exact next action

Add the generator release regression test, then implement the hosted endpoint replacement transfer.
