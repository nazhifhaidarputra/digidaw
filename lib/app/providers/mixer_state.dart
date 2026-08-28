import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
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
    @Default(IMapConst<int, double>({})) IMap<int, double> trackMagnitudes,
    @Default(IMapConst<int, double>({})) IMap<int, double> busMagnitudes,
    @Default(0.0) double masterMagnitude,
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
    assert(
      ref.read(projectProvider).hasValue,
      "Attempted to access DawContext before ProjectProvider finished loading!",
    );
    return ref.read(projectProvider.notifier).dawContext;
  }

  mixer_api.UiMixerState? get _mixerState =>
      ref.read(projectProvider).value?.mixer;

  @override
  MixerEditorState build() {
    return const MixerEditorState();
  }

  // ------------------------------------------------------------------
  // Synchronisation
  // ------------------------------------------------------------------

  /// Fetch the full mixer state from Rust and kick off per-channel queries.
  Future<void> syncMixerState() async {
    await ref.guardApi(() async {
      final newState = await mixer_api.getMixerState(ctx: _ctx);
      _projectNotifier.updateMixer(newState);
      queryAllMixerChannels();
    });
  }

  /// Sync only the bus channels.
  Future<void> syncBuses() async {
    await ref.guardApi(() async {
      final newBuses = await mixer_api.getBuses(ctx: _ctx);
      _projectNotifier.upsertMixerChannels(MixerTarget.buses(newBuses));

      for (final busId in newBuses.keys) {
        mixer_api.queryMixerChannel(
          ctx: _ctx,
          target: mixer_api.UiMixerChannelTarget.bus(busId),
        );
      }
    });
  }

  /// Sync a single track channel by [trackId].
  Future<void> syncMixerChannel(int trackId) async {
    await ref.guardApi(() async {
      final updated = await mixer_api.getMixerChannel(
        ctx: _ctx,
        trackId: trackId,
      );
      _projectNotifier.upsertTrackMixerChannel(trackId, updated);
      mixer_api.queryMixerChannel(
        ctx: _ctx,
        target: mixer_api.UiMixerChannelTarget.track(trackId),
      );
    });
  }

  /// Sync the master bus.
  Future<void> syncMasterBus() async {
    await ref.guardApi(() async {
      final updated = await mixer_api.getMasterBus(ctx: _ctx);
      _projectNotifier.upsertMixerChannels(MixerTarget.master(updated));
      mixer_api.queryMixerChannel(
        ctx: _ctx,
        target: const mixer_api.UiMixerChannelTarget.master(),
      );
    });
  }

  /// Sync the routing matrix.
  Future<void> syncRoutingConnection() async {
    await ref.guardApi(() async {
      final newRouting = await mixer_api.getRoutingMatrix(ctx: _ctx);
      if (_mixerState != null) {
        _projectNotifier.updateMixer(
          _mixerState!.copyWith(routing: newRouting),
        );
      }
    });
  }

  // ------------------------------------------------------------------
  // Real-time snapshot stream
  // ------------------------------------------------------------------

  /// Apply a real-time DSP snapshot pushed from the audio thread.
  /// Params listed in [MixerEditorState.touchedParams] are ignored to prevent
  /// in-flight slider values from being overwritten.
  /// Called 60 times a second by the UI Ticker.
  /// Reads the latest snapshot from triple_buffer SPSC ring buffer
  void pollTelemetry() {
    final mixer = _mixerState;
    if (mixer == null) return;

    // 1. Instantly load the shared pointer from Rust
    final snapshot = getMixerTelemetrySync(ctx: _ctx);
    final touched = state.touchedParams;

    state = state.copyWith(
      trackMagnitudes: snapshot.tracks
          .map((id, channel) => MapEntry(id, channel.magnitude))
          .lock,
      busMagnitudes: snapshot.buses
          .map((id, channel) => MapEntry(id, channel.magnitude))
          .lock,
      masterMagnitude: snapshot.master?.magnitude ?? 0.0,
    );

    // 2. MASTER BUS
    var newMaster = mixer.masterBus;
    if (snapshot.master != null) {
      final snap = snapshot.master!;
      const int masterSentinel = 4294967294; // u32::MAX - 1
      newMaster = mixer_api.UiMixerChannel(
        volume: touched.contains((masterSentinel, 'volume'))
            ? newMaster.volume
            : snap.volume,
        pan: touched.contains((masterSentinel, 'pan'))
            ? newMaster.pan
            : snap.pan,
        mute: touched.contains((masterSentinel, 'mute'))
            ? newMaster.mute
            : snap.mute,
        solo: touched.contains((masterSentinel, 'solo'))
            ? newMaster.solo
            : snap.solo,
        invertedPhase: snap.invertedPhase,
        effects: newMaster.effects,
      );
    }

    // 3. TRACK CHANNELS
    final newTracks = Map<int, mixer_api.UiMixerChannel>.from(mixer.channels);
    for (final entry in snapshot.tracks.entries) {
      final trackId = entry.key;
      final snap = entry.value;
      final currentCh = newTracks[trackId];

      if (currentCh != null) {
        newTracks[trackId] = mixer_api.UiMixerChannel(
          volume: touched.contains((trackId, 'volume'))
              ? currentCh.volume
              : snap.volume,
          pan: touched.contains((trackId, 'pan')) ? currentCh.pan : snap.pan,
          mute: touched.contains((trackId, 'mute'))
              ? currentCh.mute
              : snap.mute,
          solo: touched.contains((trackId, 'solo'))
              ? currentCh.solo
              : snap.solo,
          invertedPhase: snap.invertedPhase,
          effects: currentCh.effects,
        );
      }
    }

    // 4. BUS CHANNELS
    final newBuses = Map<int, mixer_api.UiBus>.from(mixer.buses);
    for (final entry in snapshot.buses.entries) {
      final busId = entry.key;
      final snap = entry.value;
      final currentBus = newBuses[busId];

      if (currentBus != null) {
        final currentCh = currentBus.channel;
        newBuses[busId] = currentBus.copyWith(
          channel: mixer_api.UiMixerChannel(
            volume: touched.contains((busId, 'volume'))
                ? currentCh.volume
                : snap.volume,
            pan: touched.contains((busId, 'pan')) ? currentCh.pan : snap.pan,
            mute: touched.contains((busId, 'mute'))
                ? currentCh.mute
                : snap.mute,
            solo: touched.contains((busId, 'solo'))
                ? currentCh.solo
                : snap.solo,
            invertedPhase: snap.invertedPhase,
            effects: currentCh.effects,
          ),
        );
      }
    }

    // 5. BULK UPDATE: Fire a single state change to Riverpod to prevent UI stutter
    _projectNotifier.updateMixer(
      mixer.copyWith(
        masterBus: newMaster,
        channels: newTracks,
        buses: newBuses,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Touch tracking
  // ------------------------------------------------------------------

  /// Mark a param as actively being dragged — suppresses snapshot overrides.
  void markParamTouched(int channelId, String paramName) {
    state = state.copyWith(
      touchedParams: state.touchedParams.add((channelId, paramName)),
    );
  }

  /// Mark a param as released — resumes accepting snapshot updates.
  void markParamReleased(int channelId, String paramName) {
    state = state.copyWith(
      touchedParams: state.touchedParams.remove((channelId, paramName)),
    );
  }

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// Ask the audio thread for real-time DSP snapshots for every channel.
  void queryAllMixerChannels() {
    final mixer = _mixerState;
    if (mixer == null) return;
    mixer_api.queryMixerChannel(
      ctx: _ctx,
      target: const mixer_api.UiMixerChannelTarget.master(),
    );
    for (final busId in mixer.buses.keys) {
      mixer_api.queryMixerChannel(
        ctx: _ctx,
        target: mixer_api.UiMixerChannelTarget.bus(busId),
      );
    }
    for (final trackId in mixer.channels.keys) {
      mixer_api.queryMixerChannel(
        ctx: _ctx,
        target: mixer_api.UiMixerChannelTarget.track(trackId),
      );
    }
  }

  /// Makes Result-returning extension methods use the notifier's Riverpod ref
  /// without exposing UI notification plumbing at each call site.
  Result<T> notifyErrorResult<T>(Object error) {
    return ref.notifyErrorResult<T>(error);
  }

  // ------------------------------------------------------------------
  // Private optimistic helpers
  // ------------------------------------------------------------------

  void _applyParamToLocalChannel(
    int trackId,
    mixer_api.UiMixerChannelParams param, {
    required bool isMaster,
  }) {
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

  void _applyParamToBusChannel(
    int busId,
    mixer_api.UiMixerChannelParams param,
  ) {
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

extension MixerService on MixerNotifier {
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
      ctx: _ctx,
      target: mixer_api.UiMixerChannelTarget.track(trackId),
      param: param,
    );
  }

  /// Apply a param change to the master bus immediately and push it to Rust.
  void setMasterBusParam({required mixer_api.UiMixerChannelParams param}) {
    _applyParamToLocalChannel(0, param, isMaster: true);
    mixer_api.setMixerChannelParam(
      ctx: _ctx,
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
      ctx: _ctx,
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
    final result = await AsyncValue.guard(() async {
      if (channelId == -1) {
        await mixer_api.addEffectToMasterBus(ctx: _ctx, registryId: registryId);
        await syncMasterBus();
      } else {
        await mixer_api.addEffectToMixerChannelById(
          ctx: _ctx,
          trackId: channelId,
          registryId: registryId,
        );
        await syncMixerChannel(channelId);
      }
    });

    if (result.hasError) {
      AppLogger.error(
        'MixerNotifier: failed to add effect to channel: ${result.error}',
      );
      return notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Add an effect to a bus channel.
  Future<Result<void>> addEffectToBusChannel(int busId, int registryId) async {
    final result = await AsyncValue.guard(() async {
      await mixer_api.addEffectToBus(
        ctx: _ctx,
        busId: busId,
        registryId: registryId,
      );
      await syncBuses();
    });

    if (result.hasError) {
      AppLogger.error(
        'MixerNotifier: failed to add effect to bus $busId: ${result.error}',
      );
      return notifyErrorResult(Exception(result.error.toString()));
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
      AppLogger.error(
        'MixerNotifier: failed to add effect to master bus: ${result.error}',
      );
      return notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Bus management
  // ------------------------------------------------------------------

  List<mixer_api.UiRoutingConnection> getMixerChannelDest({
    required mixer_api.UiRoutingNode source,
  }) {
    final mixer = _mixerState;
    if (mixer == null) return [];

    return mixer.routing.where((conn) => conn.source == source).toList();
  }

  /// Create a new bus channel with the given [name].
  Future<Result<void>> createNewBusChannel({String name = 'Untitled'}) async {
    final result = await AsyncValue.guard(() async {
      await mixer_api.createBus(ctx: _ctx, name: name);
      await syncBuses();
    });

    if (result.hasError) {
      AppLogger.error(
        'MixerNotifier: failed to create bus channel: ${result.error}',
      );
      await syncBuses();
      return notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<Null>> removeBus({required int busId}) async {
    final originalMixer = _mixerState;
    if (originalMixer == null) {
      return notifyErrorResult(Exception("Mixer state missing"));
    }

    // 1. Optimistic Update (Remove bus AND cascading routes)
    final newBuses = Map<int, mixer_api.UiBus>.from(originalMixer.buses)
      ..remove(busId);
    final targetNode = mixer_api.UiRoutingNode.bus(busId);

    final newRouting = originalMixer.routing.where((conn) {
      return conn.source != targetNode && conn.destination != targetNode;
    }).toList();

    _projectNotifier.updateMixer(
      originalMixer.copyWith(buses: newBuses, routing: newRouting),
    );

    // 2. Fire FFI
    final result = await AsyncValue.guard(() async {
      await mixer_api.deleteBus(ctx: _ctx, busId: busId);
    });

    // 3. Rollback
    if (result.hasError) {
      AppLogger.error("Failed to remove bus: ${result.error}");
      _projectNotifier.updateMixer(originalMixer);
      return notifyErrorResult(Exception(result.error.toString()));
    }

    return Result.ok(null);
  }

  /// Add or update a routing connection.
  Future<Result<void>> updateRoutingCall({
    required mixer_api.UiRoutingNode src,
    required mixer_api.UiRoutingNode dest,
    required double sendLvl,
    required bool isSend,
  }) async {
    final originalMixer = _mixerState;
    if (originalMixer == null) {
      return notifyErrorResult(Exception("Mixer state missing"));
    }

    // 1. Optimistic Update
    final newConn = mixer_api.UiRoutingConnection(
      source: src,
      destination: dest,
      sendLevel: sendLvl,
      isSend: isSend,
    );

    final currentRoutes = List<mixer_api.UiRoutingConnection>.from(
      originalMixer.routing,
    );
    final existingIdx = currentRoutes.indexWhere(
      (r) => r.source == src && r.destination == dest && r.isSend == isSend,
    );

    if (existingIdx != -1) {
      currentRoutes[existingIdx] = newConn;
    } else {
      currentRoutes.add(newConn);
    }

    _projectNotifier.updateMixer(
      originalMixer.copyWith(routing: currentRoutes),
    );

    // 2. Fire FFI
    final result = await AsyncValue.guard(() async {
      await mixer_api.updateRouting(ctx: _ctx, conn: newConn);
    });

    // 3. Rollback
    if (result.hasError) {
      AppLogger.error("Failed to update routing: ${result.error}");
      _projectNotifier.updateMixer(originalMixer);
      return notifyErrorResult(Exception(result.error.toString()));
    }

    return Result.ok(null);
  }

  /// Remove a specific routing connection.
  Future<Result<void>> removeRouting({
    required mixer_api.UiRoutingNode source,
    required mixer_api.UiRoutingNode destination,
    required bool isSend,
  }) async {
    final originalMixer = _mixerState;
    if (originalMixer == null) {
      return notifyErrorResult(Exception("Mixer state missing"));
    }

    // 1. Optimistic Update
    final currentRoutes = originalMixer.routing
        .where(
          (r) =>
              !(r.source == source &&
                  r.destination == destination &&
                  r.isSend == isSend),
        )
        .toList();

    _projectNotifier.updateMixer(
      originalMixer.copyWith(routing: currentRoutes),
    );

    // 2. Fire FFI
    final result = await AsyncValue.guard(() async {
      await mixer_api.removeRouting(
        ctx: _ctx,
        source: source,
        destination: destination,
        isSend: isSend,
      );
    });

    // 3. Rollback
    if (result.hasError) {
      AppLogger.error("Failed to remove routing: ${result.error}");
      _projectNotifier.updateMixer(originalMixer);
      return notifyErrorResult(Exception(result.error.toString()));
    }

    return Result.ok(null);
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for mixer state.
///
/// Read: `ref.watch(mixerStateProvider)`
/// Mutate: `ref.read(mixerStateProvider.notifier).syncMixerState()`
final mixerStateProvider = NotifierProvider<MixerNotifier, MixerEditorState>(
  MixerNotifier.new,
);
