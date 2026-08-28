import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
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
    int? sampleRate,
  }) = _TransportStateData;
}

final transportPositionStreamProvider =
    StreamProvider<audio_api.UiTransportFeedback>((ref) async* {
      // Ensure the project provider has finished booting and creating the context
      final ctx = ref.watch(projectProvider.notifier).dawContext;

      // Yield the stream directly from FRB
      yield* audio_api.createPositionStream(ctx: ctx);
    });

/// Top-level Riverpod 3.0 provider for Transport State
final transportProvider =
    AsyncNotifierProvider<TransportNotifier, TransportStateData>(
      TransportNotifier.new,
    );

class TransportNotifier extends AsyncNotifier<TransportStateData> {
  // Helper to grab the opaque FFI context pointer instantly
  DawContext get _ctx {
    // Optional: Add a debug assert to catch architectural mistakes early
    assert(
      ref.read(projectProvider).hasValue,
      "Attempted to access DawContext before ProjectProvider finished loading!",
    );
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
      var newSampleRate = current.sampleRate;

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

      if (pos.sampleRate != newSampleRate) {
        newSampleRate = pos.sampleRate;
        changed = true;
      }

      // Update BPM from audio thread (e.g. tempo automation)
      if (newTransportState != null &&
          (pos.tempo - newTransportState.bpm).abs() > 0.01) {
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
            sampleRate: newSampleRate,
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
      // sampleRate will be hydrated by the stream immediately
    );
  }

  // ==========================================
  // Actions
  // ==========================================

  Future<void> syncTransportState() async {
    final result = await ref.guardApi(() async {
      final newState = await getTransportState(ctx: _ctx);
      if (state.hasValue) {
        state = AsyncData(state.requireValue.copyWith(state: newState));
      }
    });

    if (result.hasError) {
      AppLogger.error("Transport sync failed: ${result.error}");
    }
  }

  void toggleMetronomeActive() {
    if (!state.hasValue) return;
    final current = state.requireValue;

    final newActiveState = !current.isMetronomeActive;

    // Optimistic UI update
    state = AsyncData(current.copyWith(isMetronomeActive: newActiveState));

    // Backend call
    unawaited(
      ref.guardApi(() async {
        audio_api.setMetronomeActive(ctx: _ctx, active: newActiveState);
      }),
    );
  }

  Future<Result<void>> stop() async {
    final result = await AsyncValue.guard(
      () => transport_api.stopSongPlayback(ctx: _ctx),
    );

    if (result.hasError) {
      AppLogger.error("Failed to stop play: ${result.error}");
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> toggleLoop() async {
    if (!state.hasValue) {
      return ref.notifyErrorResult(Exception("State not ready"));
    }

    final newLooping = !state.requireValue.isLooping;
    final result = await AsyncValue.guard(
      () => transport_api.setLooping(ctx: _ctx, val: newLooping),
    );

    if (result.hasError) {
      AppLogger.error("Failed to toggle loop: ${result.error}");
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> setBpm(double value) async {
    if (!state.hasValue || state.requireValue.state == null) {
      return ref.notifyErrorResult(Exception("State not ready"));
    }

    final current = state.requireValue;

    // Optimistic update
    final updatedTransport = current.state!.copyWith(bpm: value);
    state = AsyncData(current.copyWith(state: updatedTransport));

    final result = await AsyncValue.guard(
      () => transport_api.setBpm(ctx: _ctx, val: value),
    );

    if (result.hasError) {
      AppLogger.error("Failed to set bpm: ${result.error}");
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  int? _pendingSeekSamples;
  bool _isSeeking = false;

  Future<Result<void>> seekTo(int samples) async {
    _pendingSeekSamples = samples;
    if (_isSeeking) {
      return Result.ok(null);
    }

    _isSeeking = true;
    Result<void>? lastError;

    while (_pendingSeekSamples != null) {
      final target = _pendingSeekSamples!;
      _pendingSeekSamples = null;

      final result = await AsyncValue.guard(
        () => transport_api.setPlayhead(ctx: _ctx, val: target),
      );
      if (result.hasError) {
        AppLogger.error("Error seeking: ${result.error}");
        lastError = ref.notifyErrorResult(Exception(result.error.toString()));
      }
    }

    _isSeeking = false;
    return lastError ?? Result.ok(null);
  }
}
