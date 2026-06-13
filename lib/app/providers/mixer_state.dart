import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;

// ============================================================
// State data class
// ============================================================

/// Immutable state for the mixer.
///
/// Wraps [mixer_api.UiMixerState] together with the set of params that are
/// currently "touched" (actively being dragged by the user), so that
/// real-time snapshots from the audio thread do not overwrite in-flight edits.
class MixerEditorState {
  /// Full mixer state returned from the Rust backend.
  final mixer_api.UiMixerState mixerState;

  /// Params currently being dragged by the user `(channelId, paramName)`.
  /// Audio-thread snapshots for these params are suppressed while touched.
  final Set<(int, String)> touchedParams;

  const MixerEditorState({
    required this.mixerState,
    this.touchedParams = const {},
  });

  MixerEditorState copyWith({
    mixer_api.UiMixerState? mixerState,
    Set<(int, String)>? touchedParams,
  }) {
    return MixerEditorState(
      mixerState: mixerState ?? this.mixerState,
      touchedParams: touchedParams ?? this.touchedParams,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MixerEditorState &&
        other.mixerState == mixerState &&
        other.touchedParams == touchedParams;
  }

  @override
  int get hashCode => Object.hash(mixerState, touchedParams);
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
  StreamSubscription<mixer_api.UiMixerChannelSnapshot>? _snapshotSub;

  @override
  MixerEditorState build() {
    // Subscribe to the real-time DSP snapshot stream from the audio thread.
    _snapshotSub?.cancel();
    _snapshotSub = mixer_api.createMixerSnapshotStream().listen(
      _applySnapshot,
      onError: (e) => AppLogger.error('MixerNotifier: snapshot stream error: $e'),
    );

    // Tear down the subscription when the provider is disposed.
    ref.onDispose(() {
      _snapshotSub?.cancel();
    });

    return MixerEditorState(mixerState: mixer_api.UiMixerState());
  }

  // ------------------------------------------------------------------
  // Synchronisation
  // ------------------------------------------------------------------

  /// Fetch the full mixer state from Rust and kick off per-channel queries.
  Future<void> syncMixerState() async {
    try {
      final newState = await mixer_api.getMixerState();
      state = state.copyWith(mixerState: newState);
      queryAllMixerChannels();
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to sync mixer state: $e');
    }
  }

  /// Sync only the bus channels.
  Future<void> syncBuses() async {
    try {
      final newBuses = await mixer_api.getBuses();
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(buses: newBuses),
      );
      for (final busId in newBuses.keys) {
        mixer_api.queryMixerChannel(
          target: mixer_api.UiMixerChannelTarget.bus(busId),
        );
      }
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to sync buses: $e');
    }
  }

  /// Sync a single track channel by [trackId].
  Future<void> syncMixerChannel(int trackId) async {
    try {
      final updated = await mixer_api.getMixerChannel(trackId: trackId);
      final newChannels = Map<int, mixer_api.UiMixerChannel>.from(
        state.mixerState.channels,
      );
      newChannels[trackId] = updated;
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(channels: newChannels),
      );
      mixer_api.queryMixerChannel(
        target: mixer_api.UiMixerChannelTarget.track(trackId),
      );
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to sync channel $trackId: $e');
    }
  }

  /// Sync the master bus.
  Future<void> syncMasterBus() async {
    try {
      final updated = await mixer_api.getMasterBus();
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(masterBus: updated),
      );
      mixer_api.queryMixerChannel(
        target: const mixer_api.UiMixerChannelTarget.master(),
      );
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to sync master bus: $e');
    }
  }

  /// Sync the routing matrix.
  Future<void> syncRoutingConnection() async {
    try {
      final newRouting = await mixer_api.getRoutingMatrix();
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(routing: newRouting),
      );
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to sync routing: $e');
    }
  }

  // ------------------------------------------------------------------
  // Real-time snapshot stream
  // ------------------------------------------------------------------

  /// Apply a real-time DSP snapshot pushed from the audio thread.
  /// Params listed in [MixerEditorState.touchedParams] are ignored to prevent
  /// in-flight slider values from being overwritten.
  void _applySnapshot(mixer_api.UiMixerChannelSnapshot snapshot) {
    final touched = state.touchedParams;

    if (snapshot.isMaster) {
      const int masterSentinel = 4294967294; // u32::MAX - 1
      final ch = state.mixerState.masterBus;
      final updated = mixer_api.UiMixerChannel(
        volume: touched.contains((masterSentinel, 'volume'))
            ? ch.volume
            : snapshot.volume,
        pan: touched.contains((masterSentinel, 'pan'))
            ? ch.pan
            : snapshot.pan,
        mute: touched.contains((masterSentinel, 'mute'))
            ? ch.mute
            : snapshot.mute,
        solo: touched.contains((masterSentinel, 'solo'))
            ? ch.solo
            : snapshot.solo,
        invertedPhase: snapshot.invertedPhase,
        effects: ch.effects,
      );
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(masterBus: updated),
      );
    } else if (snapshot.busId != null) {
      final busId = snapshot.busId!;
      final bus = state.mixerState.buses[busId];
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
      final newBuses = Map<int, mixer_api.UiBus>.from(state.mixerState.buses);
      newBuses[busId] = mixer_api.UiBus(
        id: bus.id,
        name: bus.name,
        channel: updated,
      );
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(buses: newBuses),
      );
    } else {
      final trackId = snapshot.trackId;
      final ch = state.mixerState.channels[trackId];
      if (ch == null) return;
      final updated = mixer_api.UiMixerChannel(
        volume:
            touched.contains((trackId, 'volume')) ? ch.volume : snapshot.volume,
        pan: touched.contains((trackId, 'pan')) ? ch.pan : snapshot.pan,
        mute: touched.contains((trackId, 'mute')) ? ch.mute : snapshot.mute,
        solo: touched.contains((trackId, 'solo')) ? ch.solo : snapshot.solo,
        invertedPhase: snapshot.invertedPhase,
        effects: ch.effects,
      );
      final newChannels = Map<int, mixer_api.UiMixerChannel>.from(
        state.mixerState.channels,
      );
      newChannels[trackId] = updated;
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(channels: newChannels),
      );
    }
  }

  // ------------------------------------------------------------------
  // Touch tracking
  // ------------------------------------------------------------------

  /// Mark a param as actively being dragged — suppresses snapshot overrides.
  void markParamTouched(int channelId, String paramName) {
    final newTouched = Set<(int, String)>.from(state.touchedParams)
      ..add((channelId, paramName));
    state = state.copyWith(touchedParams: newTouched);
  }

  /// Mark a param as released — resumes accepting snapshot updates.
  void markParamReleased(int channelId, String paramName) {
    final newTouched = Set<(int, String)>.from(state.touchedParams)
      ..remove((channelId, paramName));
    state = state.copyWith(touchedParams: newTouched);
  }

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// Ask the audio thread for real-time DSP snapshots for every channel.
  void queryAllMixerChannels() {
    mixer_api.queryMixerChannel(
      target: const mixer_api.UiMixerChannelTarget.master(),
    );
    for (final busId in state.mixerState.buses.keys) {
      mixer_api.queryMixerChannel(
        target: mixer_api.UiMixerChannelTarget.bus(busId),
      );
    }
    for (final trackId in state.mixerState.channels.keys) {
      mixer_api.queryMixerChannel(
        target: mixer_api.UiMixerChannelTarget.track(trackId),
      );
    }
  }

  // ------------------------------------------------------------------
  // Fire-and-forget param updates (optimistic)
  // ------------------------------------------------------------------

  /// Apply a param change to a track channel immediately and push it to Rust.
  void setMixerChannelParam({
    required int trackId,
    required mixer_api.UiMixerChannelParams param,
  }) {
    _applyParamToLocalChannel(trackId, param, isMaster: false);
    mixer_api.setMixerChannelParam(
      target: mixer_api.UiMixerChannelTarget.track(trackId),
      param: param,
    );
  }

  /// Apply a param change to the master bus immediately and push it to Rust.
  void setMasterBusParam({required mixer_api.UiMixerChannelParams param}) {
    _applyParamToLocalChannel(0, param, isMaster: true);
    mixer_api.setMixerChannelParam(
      target: const mixer_api.UiMixerChannelTarget.master(),
      param: param,
    );
  }

  /// Apply a param change to a bus channel immediately and push it to Rust.
  void setBusChannelParam({
    required int busId,
    required mixer_api.UiMixerChannelParams param,
  }) {
    _applyParamToBusChannel(busId, param);
    mixer_api.setMixerChannelParam(
      target: mixer_api.UiMixerChannelTarget.bus(busId),
      param: param,
    );
  }

  // ------------------------------------------------------------------
  // Effect management
  // ------------------------------------------------------------------

  /// Add an effect to a track channel or the master bus.
  ///
  /// Pass `channelId == -1` to target the master bus.
  Future<Result<void>> addEffectToMixerChannel(
    int channelId,
    int registryId,
  ) async {
    try {
      if (channelId == -1) {
        await mixer_api.addEffectToMasterBus(registryId: registryId);
        await syncMasterBus();
      } else {
        await mixer_api.addEffectToMixerChannelById(
          trackId: channelId,
          registryId: registryId,
        );
        await syncMixerChannel(channelId);
      }
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to add effect to channel: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Add an effect to a bus channel.
  Future<Result<void>> addEffectToBusChannel(
    int busId,
    int registryId,
  ) async {
    try {
      await mixer_api.addEffectToBus(busId: busId, registryId: registryId);
      await syncBuses();
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to add effect to bus $busId: $e');
      return Result.error(Exception('$e'));
    }
  }

  /// Add an effect to the master bus.
  Future<Result<void>> addEffectToMasterBus(int registryId) async {
    try {
      await mixer_api.addEffectToMasterBus(registryId: registryId);
      await syncMasterBus();
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to add effect to master bus: $e');
      return Result.error(Exception('$e'));
    }
  }

  // ------------------------------------------------------------------
  // Bus management
  // ------------------------------------------------------------------

  /// Create a new bus channel with the given [name].
  Future<Result<void>> createNewBusChannel({String name = 'Untitled'}) async {
    try {
      await mixer_api.createBus(name: name);
      await syncBuses();
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('MixerNotifier: failed to create bus channel: $e');
      await syncBuses();
      return Result.error(Exception('$e'));
    }
  }

  // ------------------------------------------------------------------
  // Private optimistic helpers
  // ------------------------------------------------------------------

  void _applyParamToLocalChannel(
    int trackId,
    mixer_api.UiMixerChannelParams param, {
    required bool isMaster,
  }) {
    final channel = isMaster
        ? state.mixerState.masterBus
        : state.mixerState.channels[trackId];
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
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(masterBus: updated),
      );
    } else {
      final newChannels = Map<int, mixer_api.UiMixerChannel>.from(
        state.mixerState.channels,
      );
      newChannels[trackId] = updated;
      state = state.copyWith(
        mixerState: state.mixerState.copyWith(channels: newChannels),
      );
    }
  }

  void _applyParamToBusChannel(
    int busId,
    mixer_api.UiMixerChannelParams param,
  ) {
    final bus = state.mixerState.buses[busId];
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
    final newBuses = Map<int, mixer_api.UiBus>.from(state.mixerState.buses);
    newBuses[busId] = updatedBus;
    state = state.copyWith(
      mixerState: state.mixerState.copyWith(buses: newBuses),
    );
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for mixer state.
///
/// Read: `ref.watch(mixerStateProvider)`
/// Mutate: `ref.read(mixerStateProvider.notifier).syncMixerState()`
final mixerStateProvider =
    NotifierProvider<MixerNotifier, MixerEditorState>(
  MixerNotifier.new,
);
