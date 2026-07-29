import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the active range-selection rectangle state in tick-space.
///
/// Storing positions as ticks (rather than screen pixels) means the overlay
/// widget can render with a simple `left = tick / zoomLevel` without any
/// scroll-offset arithmetic or brittle Y-position calculations.
class RangeSelectState {
  final bool isSelecting;

  /// Track ID where the drag started. -1 when no selection is active.
  final int trackId;

  /// Drag start position in ticks (absolute timeline space).
  final double startTick;

  /// Current drag end position in ticks (absolute timeline space).
  final double endTick;

  const RangeSelectState({
    this.isSelecting = false,
    this.trackId = -1,
    this.startTick = 0,
    this.endTick = 0,
  });

  RangeSelectState copyWith({
    bool? isSelecting,
    int? trackId,
    double? startTick,
    double? endTick,
  }) => RangeSelectState(
    isSelecting: isSelecting ?? this.isSelecting,
    trackId: trackId ?? this.trackId,
    startTick: startTick ?? this.startTick,
    endTick: endTick ?? this.endTick,
  );
}

class RangeSelectNotifier extends Notifier<RangeSelectState> {
  @override
  RangeSelectState build() => const RangeSelectState();

  void start(int trackId, double startTick) {
    state = RangeSelectState(
      isSelecting: true,
      trackId: trackId,
      startTick: startTick,
      endTick: startTick,
    );
  }

  void update(double endTick) {
    if (!state.isSelecting) return;
    state = state.copyWith(endTick: endTick);
  }

  void cancel() {
    state = const RangeSelectState();
  }
}

final rangeSelectProvider =
    NotifierProvider<RangeSelectNotifier, RangeSelectState>(
      () => RangeSelectNotifier(),
    );
