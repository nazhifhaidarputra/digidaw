import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================
// State data class
// ============================================================

/// Immutable state for the floating MIDI keyboard panel.
///
/// Mirrors the [FloatingMidiKeyboardFieldState] (mutable DTO used inside
/// [GlobalAppState]) as an immutable Riverpod-compatible value object.
class FloatingMidiKeyboardState {
  /// Whether the keyboard panel is currently visible.
  final bool showed;

  /// MIDI note number of the lowest visible key.
  /// Clamped to [21, 120].
  final int baseKey;

  /// Number of keys shown on the keyboard.
  /// Clamped to [12, 24].
  final int keyRange;

  /// The generator (instrument) whose sound is triggered by key presses.
  /// `null` means no generator is selected yet.
  final int? selectedGeneratorId;

  const FloatingMidiKeyboardState({
    this.showed = false,
    this.baseKey = 48,
    this.keyRange = 15,
    this.selectedGeneratorId,
  });

  FloatingMidiKeyboardState copyWith({
    bool? showed,
    int? baseKey,
    int? keyRange,
    Object? selectedGeneratorId = _sentinel,
  }) {
    return FloatingMidiKeyboardState(
      showed: showed ?? this.showed,
      baseKey: (baseKey ?? this.baseKey).clamp(21, 120),
      keyRange: (keyRange ?? this.keyRange).clamp(12, 24),
      selectedGeneratorId: identical(selectedGeneratorId, _sentinel)
          ? this.selectedGeneratorId
          : selectedGeneratorId as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FloatingMidiKeyboardState &&
        other.showed == showed &&
        other.baseKey == baseKey &&
        other.keyRange == keyRange &&
        other.selectedGeneratorId == selectedGeneratorId;
  }

  @override
  int get hashCode =>
      Object.hash(showed, baseKey, keyRange, selectedGeneratorId);
}

const Object _sentinel = Object();

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] that owns [FloatingMidiKeyboardState].
///
/// All actions here mirror the MIDI keyboard methods of [GlobalAppState]
/// and are intended as a drop-in replacement during the slow migration.
class FloatingMidiKeyboardNotifier
    extends Notifier<FloatingMidiKeyboardState> {
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
