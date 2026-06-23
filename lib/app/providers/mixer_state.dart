import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/daw_stream_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/project.dart';

part 'mixer_state.freezed.dart';

// ============================================================
// State data class
// ============================================================

/// Immutable state for the mixer.
///
/// Wraps [mixer_api.UiMixerState] together with the set of params that are
/// currently "touched" (actively being dragged by the user), so that
/// real-time snapshots from the audio thread do not overwrite in-flight edits.
///
@freezed
abstract class MixerEditorState with _$MixerEditorState {
  const factory MixerEditorState({
    mixer_api.UiMixerState? mixerState,
    @Default(ISetConst(<(int, String)>{})) ISet<(int, String)> touchedParams,
  }) = _MixerEditorState;
}

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] that owns [MixerEditorState].
///
/// Manages the full lifecycle of the mixer: syncing channel data from Rust,
/// subscribing to the real-time snapshot stream, applying optimistic param
/// updates, and dispatching backend effect/bus mutations.
///
/// All actions here mirror the mixer methods of [GlobalAppState] and are
/// intended as a drop-in replacement during the slow migration.
class MixerNotifier extends Notifier<MixerEditorState> {
  ProjectNotifier get _projectNotifier => ref.read(projectProvider.notifier);
  DawContext get _ctx {
    // Optional: Add a debug assert to catch architectural mistakes early
    assert(ref.read(projectProvider).hasValue, "Attempted to access DawContext before ProjectProvider finished loading!");
    return ref.read(projectProvider.notifier).dawContext;
  }

  mixer_api.UiMixerState? get _mixerState => ref.read(projectProvider).value?.mixer;

  @override
  MixerEditorState build() {
    ref.listen(masterAudioFeedbackProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final feedback = next.value!;
        if (feedback case UiAudioFeedback_MixerChannelSnapshot snap) {
          _applySnapshot(snap);
        }
      }
    });

    return const MixerEditorState();
  }

  // ------------------------------------------------------------------
  // Synchronisation
  // ------------------------------------------------------------------

  /// Fetch the full mixer state from Rust and kick off per-channel queries.
  Future<void> syncMixerState() async {
    await AsyncValue.guard(() async {
      final newState = await mixer_api.getMixerState(ctx: _ctx);
      _projectNotifier.updateMixer(newState);
      queryAllMixerChannels();
    });
  }

  /// Sync only the bus channels.
  Future<void> syncBuses() async {
    await AsyncValue.guard(() async {
      final newBuses = await mixer_api.getBuses(ctx: _ctx);
      _projectNotifier.upsertMixerChannels(MixerTarget.buses(newBuses));

      for (final busId in newBuses.keys) {
        mixer_api.queryMixerChannel(ctx: _ctx, target: mixer_api.UiMixerChannelTarget.bus(busId));
      }
    });
  }

  /// Sync a single track channel by [trackId].
  Future<void> syncMixerChannel(int trackId) async {
    await AsyncValue.guard(() async {
      final updated = await mixer_api.getMixerChannel(ctx: _ctx, trackId: trackId);
      _projectNotifier.upsertTrackMixerChannel(trackId, updated);
      mixer_api.queryMixerChannel(ctx: _ctx, target: mixer_api.UiMixerChannelTarget.track(trackId));
    });
  }

  /// Sync the master bus.
  Future<void> syncMasterBus() async {
    await AsyncValue.guard(() async {
      final updated = await mixer_api.getMasterBus(ctx: _ctx);
      _projectNotifier.upsertMixerChannels(MixerTarget.master(updated));
      mixer_api.queryMixerChannel(ctx: _ctx, target: const mixer_api.UiMixerChannelTarget.master());
    });
  }

  /// Sync the routing matrix.
  Future<void> syncRoutingConnection() async {
    await AsyncValue.guard(() async {
      final newRouting = await mixer_api.getRoutingMatrix(ctx: _ctx);
      if (_mixerState != null) {
        _projectNotifier.updateMixer(_mixerState!.copyWith(routing: newRouting));
      }
    });
  }

  // ------------------------------------------------------------------
  // Real-time snapshot stream
  // ------------------------------------------------------------------

  /// Apply a real-time DSP snapshot pushed from the audio thread.
  /// Params listed in [MixerEditorState.touchedParams] are ignored to prevent
  /// in-flight slider values from being overwritten.
  void _applySnapshot(UiAudioFeedback_MixerChannelSnapshot snapshot) {
    final mixer = _mixerState;
    if (mixer == null) return;

    final touched = state.touchedParams;

    if (snapshot.isMaster) {
      const int masterSentinel = 4294967294; // u32::MAX - 1
      final ch = mixer.masterBus;
      final updated = mixer_api.UiMixerChannel(
        volume: touched.contains((masterSentinel, 'volume')) ? ch.volume : snapshot.volume,
        pan: touched.contains((masterSentinel, 'pan')) ? ch.pan : snapshot.pan,
        mute: touched.contains((masterSentinel, 'mute')) ? ch.mute : snapshot.mute,
        solo: touched.contains((masterSentinel, 'solo')) ? ch.solo : snapshot.solo,
        invertedPhase: snapshot.invertedPhase,
        effects: ch.effects,
      );
      _projectNotifier.upsertMixerChannels(MixerTarget.master(updated));
    } else if (snapshot.targetBusId != null) {
      final busId = snapshot.targetBusId!;
      final bus = mixer.buses[busId];
      if (bus == null) return;
      final ch = bus.channel;
      final updated = mixer_api.UiMixerChannel(
        volume: touched.contains((busId, 'volume')) ? ch.volume : snapshot.volume,
        pan: touched.contains((busId, 'pan')) ? ch.pan : snapshot.pan,
        mute: touched.contains((busId, 'mute')) ? ch.mute : snapshot.mute,
        solo: touched.contains((busId, 'solo')) ? ch.solo : snapshot.solo,
        invertedPhase: snapshot.invertedPhase,
        effects: ch.effects,
      );

      final updatedBus = bus.copyWith(channel: updated);
      _projectNotifier.upsertBusMixerChannel(busId, updatedBus);
    } else {
      final trackId = snapshot.targetTrackId;
      if (trackId == null) return;
      final ch = mixer.channels[trackId];
      if (ch == null) return;
      final updated = mixer_api.UiMixerChannel(
        volume: touched.contains((trackId, 'volume')) ? ch.volume : snapshot.volume,
        pan: touched.contains((trackId, 'pan')) ? ch.pan : snapshot.pan,
        mute: touched.contains((trackId, 'mute')) ? ch.mute : snapshot.mute,
        solo: touched.contains((trackId, 'solo')) ? ch.solo : snapshot.solo,
        invertedPhase: snapshot.invertedPhase,
        effects: ch.effects,
      );
      _projectNotifier.upsertTrackMixerChannel(trackId, updated);
    }
  }

  // ------------------------------------------------------------------
  // Touch tracking
  // ------------------------------------------------------------------

  /// Mark a param as actively being dragged — suppresses snapshot overrides.
  void markParamTouched(int channelId, String paramName) {
    state = state.copyWith(touchedParams: state.touchedParams.add((channelId, paramName)));
  }

  /// Mark a param as released — resumes accepting snapshot updates.
  void markParamReleased(int channelId, String paramName) {
    state = state.copyWith(touchedParams: state.touchedParams.remove((channelId, paramName)));
  }

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// Ask the audio thread for real-time DSP snapshots for every channel.
  void queryAllMixerChannels() {
    final mixer = _mixerState;
    if (mixer == null) return;
    mixer_api.queryMixerChannel(ctx: _ctx, target: const mixer_api.UiMixerChannelTarget.master());
    for (final busId in mixer.buses.keys) {
      mixer_api.queryMixerChannel(ctx: _ctx, target: mixer_api.UiMixerChannelTarget.bus(busId));
    }
    for (final trackId in mixer.channels.keys) {
      mixer_api.queryMixerChannel(ctx: _ctx, target: mixer_api.UiMixerChannelTarget.track(trackId));
    }
  }

  // ------------------------------------------------------------------
  // Fire-and-forget param updates (optimistic)
  // ------------------------------------------------------------------

  /// Apply a param change to a track channel immediately and push it to Rust.
  void setMixerChannelParam({required int trackId, required mixer_api.UiMixerChannelParams param}) {
    _applyParamToLocalChannel(trackId, param, isMaster: false);
    mixer_api.setMixerChannelParam(ctx: _ctx, target: mixer_api.UiMixerChannelTarget.track(trackId), param: param);
  }

  /// Apply a param change to the master bus immediately and push it to Rust.
  void setMasterBusParam({required mixer_api.UiMixerChannelParams param}) {
    _applyParamToLocalChannel(0, param, isMaster: true);
    mixer_api.setMixerChannelParam(ctx: _ctx, target: const mixer_api.UiMixerChannelTarget.master(), param: param);
  }

  /// Apply a param change to a bus channel immediately and push it to Rust.
  void setBusChannelParam({required int busId, required mixer_api.UiMixerChannelParams param}) {
    _applyParamToBusChannel(busId, param);
    mixer_api.setMixerChannelParam(ctx: _ctx, target: mixer_api.UiMixerChannelTarget.bus(busId), param: param);
  }

  // ------------------------------------------------------------------
  // Effect management
  // ------------------------------------------------------------------

  /// Add an effect to a track channel or the master bus.
  ///
  /// Pass `channelId == -1` to target the master bus.
  Future<Result<void>> addEffectToMixerChannel(int channelId, int registryId) async {
    final result = await AsyncValue.guard(() async {
      if (channelId == -1) {
        await mixer_api.addEffectToMasterBus(ctx: _ctx, registryId: registryId);
        await syncMasterBus();
      } else {
        await mixer_api.addEffectToMixerChannelById(ctx: _ctx, trackId: channelId, registryId: registryId);
        await syncMixerChannel(channelId);
      }
    });

    if (result.hasError) {
      AppLogger.error('MixerNotifier: failed to add effect to channel: ${result.error}');
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Add an effect to a bus channel.
  Future<Result<void>> addEffectToBusChannel(int busId, int registryId) async {
    final result = await AsyncValue.guard(() async {
      await mixer_api.addEffectToBus(ctx: _ctx, busId: busId, registryId: registryId);
      await syncBuses();
    });

    if (result.hasError) {
      AppLogger.error('MixerNotifier: failed to add effect to bus $busId: ${result.error}');
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Add an effect to the master bus.
  Future<Result<void>> addEffectToMasterBus(int registryId) async {
    final result = await AsyncValue.guard(() async {
      await mixer_api.addEffectToMasterBus(ctx: _ctx, registryId: registryId);
      await syncMasterBus();
    });

    if (result.hasError) {
      AppLogger.error('MixerNotifier: failed to add effect to master bus: ${result.error}');
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Bus management
  // ------------------------------------------------------------------

  /// Create a new bus channel with the given [name].
  Future<Result<void>> createNewBusChannel({String name = 'Untitled'}) async {
    final result = await AsyncValue.guard(() async {
      await mixer_api.createBus(ctx: _ctx, name: name);
      await syncBuses();
    });

    if (result.hasError) {
      AppLogger.error('MixerNotifier: failed to create bus channel: ${result.error}');
      await syncBuses();
      return Result.error(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Private optimistic helpers
  // ------------------------------------------------------------------

  void _applyParamToLocalChannel(int trackId, mixer_api.UiMixerChannelParams param, {required bool isMaster}) {
    final mixer = _mixerState;
    if (mixer == null) return;

    final channel = isMaster ? mixer.masterBus : mixer.channels[trackId];
    if (channel == null) return;

    double volume = channel.volume;
    double pan = channel.pan;
    bool mute = channel.mute;
    bool solo = channel.solo;
    bool invertedPhase = channel.invertedPhase;

    switch (param) {
      case mixer_api.UiMixerChannelParams_Volume():
        volume = param.field0;
      case mixer_api.UiMixerChannelParams_Pan():
        pan = param.field0;
      case mixer_api.UiMixerChannelParams_Mute():
        mute = param.field0;
      case mixer_api.UiMixerChannelParams_Solo():
        solo = param.field0;
      case mixer_api.UiMixerChannelParams_InvertedPhase():
        invertedPhase = param.field0;
    }

    final updated = mixer_api.UiMixerChannel(
      volume: volume,
      pan: pan,
      mute: mute,
      solo: solo,
      invertedPhase: invertedPhase,
      effects: channel.effects,
    );

    if (isMaster) {
      _projectNotifier.upsertMixerChannels(MixerTarget.master(updated));
    } else {
      _projectNotifier.upsertTrackMixerChannel(trackId, updated);
    }
  }

  void _applyParamToBusChannel(int busId, mixer_api.UiMixerChannelParams param) {
    final mixer = _mixerState;
    if (mixer == null) return;

    final bus = mixer.buses[busId];
    if (bus == null) return;
    final ch = bus.channel;

    double volume = ch.volume;
    double pan = ch.pan;
    bool mute = ch.mute;
    bool solo = ch.solo;
    bool invertedPhase = ch.invertedPhase;

    switch (param) {
      case mixer_api.UiMixerChannelParams_Volume():
        volume = param.field0;
      case mixer_api.UiMixerChannelParams_Pan():
        pan = param.field0;
      case mixer_api.UiMixerChannelParams_Mute():
        mute = param.field0;
      case mixer_api.UiMixerChannelParams_Solo():
        solo = param.field0;
      case mixer_api.UiMixerChannelParams_InvertedPhase():
        invertedPhase = param.field0;
    }

    final updatedBus = mixer_api.UiBus(
      id: bus.id,
      name: bus.name,
      channel: mixer_api.UiMixerChannel(
        volume: volume,
        pan: pan,
        mute: mute,
        solo: solo,
        invertedPhase: invertedPhase,
        effects: ch.effects,
      ),
    );
    _projectNotifier.upsertBusMixerChannel(busId, updatedBus);
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for mixer state.
///
/// Read: `ref.watch(mixerStateProvider)`
/// Mutate: `ref.read(mixerStateProvider.notifier).syncMixerState()`
final mixerStateProvider = NotifierProvider<MixerNotifier, MixerEditorState>(MixerNotifier.new);
