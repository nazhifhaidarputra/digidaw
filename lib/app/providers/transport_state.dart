import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/transport.dart' as transport_api;

part 'transport_state.freezed.dart';

@freezed
abstract class TransportStateData with _$TransportStateData {
  const factory TransportStateData({
    UiTransportState? state,
    @Default(false) bool isLooping,
    @Default(false) bool isPatternPlaying,
    @Default(false) bool isPatternMode,
    @Default(false) bool isMetronomeActive,
  }) = _TransportStateData;
}

final transportPositionStreamProvider = StreamProvider<audio_api.UiTransportFeedback>((ref) async* {
  // Ensure the project provider has finished booting and creating the context
  await ref.watch(projectProvider.future);
  final ctx = ref.read(projectProvider.notifier).dawContext;

  // Yield the stream directly from FRB
  yield* audio_api.createPositionStream(ctx: ctx);
});

/// Top-level Riverpod 3.0 provider for Transport State
final transportProvider = AsyncNotifierProvider<TransportNotifier, TransportStateData>(TransportNotifier.new);

class TransportNotifier extends AsyncNotifier<TransportStateData> {
  // Helper to grab the opaque FFI context pointer instantly
    DawContext get _ctx {
    // Optional: Add a debug assert to catch architectural mistakes early
    assert(ref.read(projectProvider).hasValue, "Attempted to access DawContext before ProjectProvider finished loading!");
    return ref.read(projectProvider.notifier).dawContext;
  }

  @override
  Future<TransportStateData> build() async {
    ref.listen(transportPositionStreamProvider, (previous, next) {
      if (!state.hasValue || !next.hasValue || next.value == null) return;

      final pos = next.value!;
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
      if (newTransportState != null && (pos.tempo - newTransportState.bpm).abs() > 0.01) {
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

    // 3. Initial Sync from Backend (Requires context)
    final initialTransportState = await getTransportState(ctx: _ctx);

    // 4. Return Initial State
    return TransportStateData(
      state: initialTransportState,
      isLooping: false,
      isPatternPlaying: false,
      isPatternMode: false,
      isMetronomeActive: false,
    );
  }

  // ==========================================
  // Actions
  // ==========================================

  Future<void> syncTransportState() async {
    try {
      final newState = await getTransportState(ctx: _ctx);
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
    audio_api.setMetronomeActive(ctx: _ctx, active: newActiveState);
  }

  Future<Result<void>> stop() async {
    try {
      await transport_api.stopSongPlayback(ctx: _ctx);
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
      await transport_api.setLooping(ctx: _ctx, val: newLooping);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Failed to toggle loop: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> setBpm(double value) async {
    if (!state.hasValue || state.requireValue.state == null) {
      return Result.error(Exception("State not ready"));
    }
    try {
      final current = state.requireValue;

      // Optimistic update
      final updatedTransport = current.state!.copyWith(bpm: value);
      state = AsyncData(current.copyWith(state: updatedTransport));

      await transport_api.setBpm(ctx: _ctx, val: value);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Failed to set bpm: $e");
      return Result.error(Exception("$e"));
    }
  }

  Future<Result<void>> seekTo(int samples) async {
    try {
      await transport_api.setPlayhead(ctx: _ctx, val: samples);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Error seeking: $e");
      return Result.error(Exception("$e"));
    }
  }
}
