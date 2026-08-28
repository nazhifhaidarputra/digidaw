import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'floating_midi_keyboard_state.freezed.dart';

// ============================================================
// State data class
// ============================================================

/// Immutable state for the floating MIDI keyboard panel.
///
/// Mirrors the [FloatingMidiKeyboardFieldState] (mutable DTO used inside
/// [GlobalAppState]) as an immutable Riverpod-compatible value object.
@freezed
abstract class FloatingMidiKeyboardState with _$FloatingMidiKeyboardState {
  const factory FloatingMidiKeyboardState({
    /// Whether the keyboard panel is currently visible.
    @Default(false) bool showed,

    /// MIDI note number of the lowest visible key.
    /// Clamped to [21, 120] by [FloatingMidiKeyboardNotifier.setBaseKey].
    @Default(48) int baseKey,

    /// Number of keys shown on the keyboard.
    /// Clamped to [12, 24] by [FloatingMidiKeyboardNotifier.setKeyRange].
    @Default(15) int keyRange,

    /// The generator whose sound is triggered by key presses.
    /// `null` means no generator is selected yet.
    int? selectedGeneratorId,
  }) = _FloatingMidiKeyboardState;
}

// ============================================================
// Notifier
// ============================================================

/// Riverpod [Notifier] that owns [FloatingMidiKeyboardState].
class FloatingMidiKeyboardNotifier extends Notifier<FloatingMidiKeyboardState> {
  @override
  FloatingMidiKeyboardState build() => const FloatingMidiKeyboardState();

  // ------------------------------------------------------------------
  // Visibility
  // ------------------------------------------------------------------

  /// Toggle the floating keyboard panel open / closed.
  void toggle() {
    state = state.copyWith(showed: !state.showed);
  }

  /// Explicitly show or hide the floating keyboard panel.
  void setVisible(bool visible) {
    if (state.showed != visible) {
      state = state.copyWith(showed: visible);
    }
  }

  // ------------------------------------------------------------------
  // Configuration
  // ------------------------------------------------------------------

  /// Set the lowest visible key (MIDI note number).  Clamped to [21, 120].
  void setBaseKey(int key) {
    final clamped = key.clamp(21, 120);
    if (state.baseKey != clamped) {
      state = state.copyWith(baseKey: clamped);
    }
  }

  /// Set the number of visible keys.  Clamped to [12, 24].
  void setKeyRange(int range) {
    final clamped = range.clamp(12, 24);
    if (state.keyRange != clamped) {
      state = state.copyWith(keyRange: clamped);
    }
  }

  /// Set the generator whose sound is triggered by key presses.
  /// Pass `null` to clear the selection.
  void setGenerator(int? generatorId) {
    state = state.copyWith(selectedGeneratorId: generatorId);
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for the floating MIDI keyboard state.
///
/// Read: `ref.watch(floatingMidiKeyboardStateProvider)`
/// Mutate: `ref.read(floatingMidiKeyboardStateProvider.notifier).toggle()`
final floatingMidiKeyboardStateProvider =
    NotifierProvider<FloatingMidiKeyboardNotifier, FloatingMidiKeyboardState>(
      FloatingMidiKeyboardNotifier.new,
    );
