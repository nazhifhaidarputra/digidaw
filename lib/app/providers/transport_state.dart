import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/transport.dart' as transport_api;

class TransportStateData {
  final UiTransportState state;
  final bool isLooping;
  final bool isPatternPlaying;
  final bool isPatternMode;
  final bool isMetronomeActive;

  TransportStateData({
    required this.state,
    required this.isLooping,
    required this.isPatternPlaying,
    required this.isPatternMode,
    required this.isMetronomeActive,
  });

  TransportStateData copyWith({
    UiTransportState? state,
    bool? isLooping,
    bool? isPatternPlaying,
    bool? isPatternMode,
    bool? isMetronomeActive,
  }) {
    return TransportStateData(
      state: state ?? this.state,
      isLooping: isLooping ?? this.isLooping,
      isPatternPlaying: isPatternPlaying ?? this.isPatternPlaying,
      isPatternMode: isPatternMode ?? this.isPatternMode,
      isMetronomeActive: isMetronomeActive ?? this.isMetronomeActive,
    );
  }
}

/// Top-level Riverpod 3.0 provider for Transport State
final transportProvider =
    AsyncNotifierProvider<TransportNotifier, TransportStateData>(
      TransportNotifier.new,
    );

class TransportNotifier extends AsyncNotifier<TransportStateData> {
  late final StreamSubscription<audio_api.UiTransportFeedback> _positionSub;

  @override
  Future<TransportStateData> build() async {
    // 1. Setup Stream Listener
    final positionStream = audio_api.createPositionStream().asBroadcastStream();

    _positionSub = positionStream.listen((pos) {
      if (!state.hasValue) return;
      final current = state.requireValue;
      bool changed = false;

      var newPatternPlaying = current.isPatternPlaying;
      var newLooping = current.isLooping;
      var newPatternMode = current.isPatternMode;
      var newTransportState = current.state;

      if (pos.isPatternPlaying != newPatternPlaying) {
        newPatternPlaying = pos.isPatternPlaying;
        changed = true;
      }

      if (pos.isLooping != newLooping) {
        newLooping = pos.isLooping;
        changed = true;
      }

      if (pos.isPatternMode != newPatternMode) {
        newPatternMode = pos.isPatternMode;
        changed = true;
      }

      // Update BPM from audio thread (e.g. tempo automation)
      if ((pos.tempo - newTransportState.bpm).abs() > 0.01) {
        // Utilizing your existing TransportStateCopyWith extension
        newTransportState = newTransportState.copyWith(bpm: pos.tempo);
        changed = true;
      }

      if (changed) {
        state = AsyncData(
          current.copyWith(
            isPatternPlaying: newPatternPlaying,
            isLooping: newLooping,
            isPatternMode: newPatternMode,
            state: newTransportState,
          ),
        );
      }
    });

    // 2. Handle Cleanup
    ref.onDispose(() {
      _positionSub.cancel();
    });

    // 3. Initial Sync from Backend
    final initialTransportState = await getTransportState();

    // 4. Return Initial State
    return TransportStateData(
      state: initialTransportState,
      isLooping: false,
      isPatternPlaying: false,
      isPatternMode: false, // Inferred from your constructor logic
      isMetronomeActive: false,
    );
  }

  // ==========================================
  // Actions
  // ==========================================

  Future<void> syncTransportState() async {
    try {
      final newState = await getTransportState();
      if (state.hasValue) {
        state = AsyncData(state.requireValue.copyWith(state: newState));
      }
    } catch (e) {
      AppLogger.error("Transport sync failed: $e");
    }
  }

  void toggleMetronomeActive() {
    if (!state.hasValue) return;
    final current = state.requireValue;

    final newActiveState = !current.isMetronomeActive;

    // Optimistic UI update
    state = AsyncData(current.copyWith(isMetronomeActive: newActiveState));

    // Backend call
    audio_api.setMetronomeActive(active: newActiveState);
  }

  Future<Result<void>> stop() async {
    try {
      await transport_api.stopSongPlayback();
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Failed to stop play: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> toggleLoop() async {
    if (!state.hasValue) return Result.error(Exception("State not ready"));
    try {
      final newLooping = !state.requireValue.isLooping;
      await transport_api.setLooping(val: newLooping);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Failed to toggle loop: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> setBpm(double value) async {
    if (!state.hasValue) return Result.error(Exception("State not ready"));
    try {
      final current = state.requireValue;

      // Optimistic update
      final updatedTransport = current.state.copyWith(bpm: value);
      state = AsyncData(current.copyWith(state: updatedTransport));

      await transport_api.setBpm(val: value);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Failed to set bpm: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> seekTo(int samples) async {
    try {
      await transport_api.setPlayhead(val: samples);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Error seeking: $e");
      return Result.error(Exception("$e"));
    }
  }
}
