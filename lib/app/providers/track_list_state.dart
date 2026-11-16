import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/automation_provider.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/app/providers/telemetry_polling_suppression.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/mixer/services/mixer_channel_targets.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/track/services/automation_region_edit.dart';
import 'package:karbeat/features/track/models/mixer_channel_sidepanel.dart';
import 'package:karbeat/shared/models/grid.dart';
import 'package:karbeat/src/rust/api/mixer.dart' show UiMixerChannelTarget;
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/automation.dart'
    show
        AutomationLaneDto,
        AutomationRegionDto,
        getAllLinkedModulationParams,
        getAllModulationSources,
        getAutomationsLanesAll;
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/session.dart' as session_api;
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/src/rust/api/track.dart' as track_api;
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/waveform.dart';

part 'track_list_state.freezed.dart';

// ============================================================
// State data class
// ============================================================

/// Immutable state for the track list / arranger view.
///
/// Owns the clip selection state, and
/// view-specific metadata (track heights, open file path, max sample index).
///
/// All clip mutation actions call the Rust backend and then sync state back
/// via the matching `sync*` helpers, applying optimistic local updates first
/// wherever possible.
@freezed
abstract class TrackListState with _$TrackListState {
  const TrackListState._();

  const factory TrackListState({
    /// Selected clips grouped by track ID. A track is listed only while it has
    /// selected clips.
    @Default(IMapConst<int, IList<int>>({}))
    IMap<int, IList<int>> selectedClips,

    /// Selected automation regions grouped by automation lane ID. A lane is
    /// listed only while it has selected regions.
    @Default(IMapConst<int, IList<int>>({}))
    IMap<int, IList<int>> selectedRegions,

    /// The clip that should receive keyboard focus (last clicked).
    int? focusClipId,

    /// Track and tick of the last timeline click. Ctrl+V pastes here.
    int? lastClickedTrackId,
    int? lastClickedTick,

    /// Per-track pixel heights for the arranger rows, keyed by track ID.
    @Default(IMapConst<int, int>({})) IMap<int, int> trackIdHeightMap,

    /// Tracks shrunk to a title-only row. Their stored height is kept so
    /// expanding restores it.
    @Default(ISetConst<int>({})) ISet<int> collapsedTrackIds,

    /// Mixer channel panel beside the track headers.
    @Default(MixerChannelPanelState()) MixerChannelPanelState mixerChannelPanel,
  }) = _TrackListState;

  /// The track holding the whole selection, when the selection is clips of a
  /// single track. Single-track clip actions (copy, paste, duplicate,
  /// quantize, draw) act on it.
  int? get selectedTrackId =>
      selectedClips.length == 1 && selectedRegions.isEmpty
      ? selectedClips.keys.first
      : null;

  /// The clips of [selectedTrackId]; empty for any other selection.
  IList<int> get selectedClipIds {
    final trackId = selectedTrackId;
    if (trackId == null) return const IListConst<int>([]);
    return selectedClips[trackId] ?? const IListConst<int>([]);
  }

  /// Selected clips of [trackId].
  IList<int> clipsSelectedOn(int trackId) =>
      selectedClips[trackId] ?? const IListConst<int>([]);

  /// Selected regions of the automation lane [laneId].
  IList<int> regionsSelectedOn(int laneId) =>
      selectedRegions[laneId] ?? const IListConst<int>([]);

  /// Number of selected clips and regions.
  int get selectionCount =>
      selectedClips.values.fold(0, (sum, ids) => sum + ids.length) +
      selectedRegions.values.fold(0, (sum, ids) => sum + ids.length);

  bool get hasSelection =>
      selectedClips.isNotEmpty || selectedRegions.isNotEmpty;

  /// Whether the selection spans several tracks or lanes. Such a selection
  /// only moves, resizes, slices and deletes, and nothing leaves its track or
  /// lane.
  bool get spansLanes => selectedClips.length + selectedRegions.length > 1;

  /// The lane holding the whole selection, when the selection is regions of a
  /// single automation lane.
  int? get selectedRegionLaneId =>
      selectedRegions.length == 1 && selectedClips.isEmpty
      ? selectedRegions.keys.first
      : null;
}

/// Clip IDs as a selection of one track; an empty list selects nothing.
IMap<int, IList<int>> _onTrack(int trackId, Iterable<int> clipIds) {
  final ids = clipIds.toIList();
  return ids.isEmpty
      ? const IMapConst<int, IList<int>>({})
      : IMap<int, IList<int>>({trackId: ids});
}

/// The channel shown in the track list's mixer panel; null while the panel is
/// closed or once its track or bus no longer exists.
final mixerChannelPanelTargetProvider = Provider<UiMixerChannelTarget?>((ref) {
  final panel = ref.watch(
    trackListStateProvider.select((s) => s.mixerChannelPanel),
  );
  final target = panel.target;
  if (!panel.isOpen || target == null) return null;
  final exists = ref.watch(
    projectProvider.select((s) {
      final mixer = s.value?.mixer;
      return mixer != null && target.channelIn(mixer) != null;
    }),
  );
  return exists ? target : null;
});

// ============================================================
// Notifier
// ============================================================

/// Riverpod 3 [Notifier] that owns [TrackListState].
///
/// All actions here mirror the track-list / clip methods of [GlobalAppState]
/// and are intended as a drop-in replacement during the slow migration.
class TrackListNotifier extends Notifier<TrackListState> {
  @override
  TrackListState build() {
    // Fitting a source to the tempo or detecting its tempo rescales the clips
    // that play it, so refetch them when such a job finishes.
    ref.listen(
      backgroundJobsProvider.select((s) => s.sourceRevisions),
      (_, _) => syncTracks(),
    );
    return const TrackListState();
  }

  ProjectNotifier get _projectNotifierRead =>
      ref.read(projectProvider.notifier);
  DawContext get _ctx {
    // Optional: Add a debug assert to catch architectural mistakes early
    assert(
      ref.read(projectProvider).hasValue,
      "Attempted to access DawContext before ProjectProvider finished loading!",
    );
    return ref.read(projectProvider.notifier).dawContext;
  }

  // ==================================================================
  // CLIENT-SIDE REACTIVITY
  // ==================================================================

  static const int minTrackHeight = 48;
  static const int maxTrackHeight = 400;

  /// Height of a shrunk track or automation lane: title row only.
  static const double collapsedLaneHeight = 24;

  /// Sets (upserts) the pixel height of [trackId].
  void changeHeight({required int trackId, required int newHeight}) {
    final clamped = newHeight.clamp(minTrackHeight, maxTrackHeight).toInt();
    // Skip no-op notifications (e.g. when pinned at min/max during a drag).
    if (state.trackIdHeightMap.get(trackId) == clamped) return;

    final builder = state.trackIdHeightMap.unlock..[trackId] = clamped;
    state = state.copyWith(trackIdHeightMap: builder.lock);
  }

  /// Removes the override so the track falls back to the default height.
  void resetTrackHeight({required int trackId}) {
    if (state.trackIdHeightMap.get(trackId) == null) return;
    final builder = state.trackIdHeightMap.unlock..remove(trackId);
    state = state.copyWith(trackIdHeightMap: builder.lock);
  }

  /// Shrinks a track to its title row, or expands it back to its height.
  void toggleTrackCollapsed({required int trackId}) {
    final collapsed = state.collapsedTrackIds;
    state = state.copyWith(
      collapsedTrackIds: collapsed.contains(trackId)
          ? collapsed.remove(trackId)
          : collapsed.add(trackId),
    );
  }

  /// Shows [target] in the mixer channel panel; selecting the channel that
  /// is already shown closes the panel.
  void selectMixerChannel(UiMixerChannelTarget target) {
    final panel = state.mixerChannelPanel;
    state = state.copyWith(
      mixerChannelPanel: panel.isOpen && panel.target == target
          ? panel.copyWith(isOpen: false)
          : MixerChannelPanelState(isOpen: true, target: target),
    );
  }

  void closeMixerChannelPanel() {
    if (!state.mixerChannelPanel.isOpen) return;
    state = state.copyWith(
      mixerChannelPanel: state.mixerChannelPanel.copyWith(isOpen: false),
    );
  }

  // ==================================================================
  // Synchronisation
  // ==================================================================

  /// Sync a single track by its backend [trackId].
  Future<void> syncTracks() async {
    final result = await ref.guardApi(() async {
      final (newTracksMap, newPatternMap) = await (
        getTracks(ctx: _ctx),
        getPatterns(ctx: _ctx), // Requires the pattern FFI endpoint
      ).wait;
      _projectNotifierRead.upsertTracksBulk(newTracksMap);
      _projectNotifierRead.upsertPatternBulk(newPatternMap);
    });

    return result.value;
  }

  /// Sync a single track (creates a new map reference to trigger selectors).
  Future<void> syncTrack(int trackId) async {
    final res = await ref.guardApi(() async {
      final updatedTrack = await getTrack(ctx: _ctx, trackId: trackId);
      if (updatedTrack == null) {
        AppLogger.warn(
          "Track list state: track not found (id: $trackId), attempting to delete!",
        );
        _projectNotifierRead.removeTrack(trackId);
        return;
      }
      _projectNotifierRead.upsertTrack(trackId, updatedTrack);

      final newPatternMap = await getPatterns(ctx: _ctx);
      _projectNotifierRead.upsertPatternBulk(newPatternMap);
    });

    return res.value;
  }

  IMap<int, UiTrack> getTracksFromProjectProvider() {
    return ref.read(projectProvider).value?.tracks ?? IMap();
  }

  // ------------------------------------------------------------------
  // Clip selection
  // ------------------------------------------------------------------

  /// Select a single clip (clears any existing multi-selection).
  void selectClip({required int trackId, required int clipId}) {
    state = state.copyWith(
      selectedClips: _onTrack(trackId, [clipId]),
      selectedRegions: const IMapConst({}),
      focusClipId: clipId,
    );
  }

  /// Add a clip to the selection (Ctrl+Click behaviour). Clips of other
  /// tracks stay selected.
  void addClipToSelection({required int trackId, required int clipId}) {
    final current = state.clipsSelectedOn(trackId);
    state = state.copyWith(
      selectedClips: state.selectedClips.add(
        trackId,
        current.contains(clipId) ? current : current.add(clipId),
      ),
      focusClipId: clipId,
    );
  }

  /// Remove a clip from the selection.
  void removeClipFromSelection({required int clipId}) {
    final selected = state.selectedClips.map(
      (trackId, ids) => MapEntry(trackId, ids.remove(clipId)),
    );
    final remaining = selected.where((_, ids) => ids.isNotEmpty);

    int? newFocus = state.focusClipId;
    if (newFocus == clipId) {
      newFocus = remaining.values.lastOrNull?.lastOrNull;
    }

    state = state.copyWith(selectedClips: remaining, focusClipId: newFocus);
  }

  /// Select a specific set of clips on a given track.
  void selectClips({required int trackId, required List<int> clipIds}) {
    final updated = clipIds.lock;
    state = state.copyWith(
      selectedClips: _onTrack(trackId, updated),
      selectedRegions: const IMapConst({}),
      focusClipId: updated.isNotEmpty ? updated.last : null,
    );
  }

  /// Replaces the selection with clips and automation regions of any number
  /// of tracks and lanes.
  void selectTimelineItems({
    required IMap<int, IList<int>> clips,
    required IMap<int, IList<int>> regions,
  }) {
    final selectedClips = clips.where((_, ids) => ids.isNotEmpty);
    state = state.copyWith(
      selectedClips: selectedClips,
      selectedRegions: regions.where((_, ids) => ids.isNotEmpty),
      focusClipId: selectedClips.values.lastOrNull?.lastOrNull,
    );
  }

  /// Selects a single automation region, or with [additive] adds it to the
  /// selection.
  void selectRegion({
    required int laneId,
    required int regionId,
    bool additive = false,
  }) {
    if (!additive) {
      state = state.copyWith(
        selectedClips: const IMapConst({}),
        selectedRegions: IMap({
          laneId: IList([regionId]),
        }),
        focusClipId: null,
      );
      return;
    }
    final current = state.regionsSelectedOn(laneId);
    state = state.copyWith(
      selectedRegions: state.selectedRegions.add(
        laneId,
        current.contains(regionId) ? current : current.add(regionId),
      ),
    );
  }

  /// Removes one automation region from the selection.
  void removeRegionFromSelection({required int laneId, required int regionId}) {
    final remaining = state.regionsSelectedOn(laneId).remove(regionId);
    state = state.copyWith(
      selectedRegions: remaining.isEmpty
          ? state.selectedRegions.remove(laneId)
          : state.selectedRegions.add(laneId, remaining),
    );
  }

  /// Selects every clip of [trackId], replacing the selection.
  void selectAllClipsOn(int trackId) {
    final clips = ref.read(projectProvider).value?.tracks[trackId]?.clips;
    if (clips == null) return;
    selectClips(trackId: trackId, clipIds: [for (final clip in clips) clip.id]);
  }

  /// Selects every region of the automation lane [laneId], replacing the
  /// selection.
  void selectAllRegionsOn(int laneId) {
    final lane = ref.read(projectProvider).value?.automationPool[laneId];
    if (lane == null) return;
    selectTimelineItems(
      clips: const IMapConst({}),
      regions: IMap({
        laneId: [for (final region in lane.regions) region.id].lock,
      }),
    );
  }

  /// Clear all clip selection.
  void deselectAllClips() {
    state = state.copyWith(
      selectedClips: const IMapConst({}),
      selectedRegions: const IMapConst({}),
      focusClipId: null,
    );
  }

  /// Drops regions that no longer exist in [lane] from the selection.
  void pruneRegionSelection(int laneId, Set<int> existingRegionIds) {
    final selected = state.regionsSelectedOn(laneId);
    if (selected.isEmpty) return;
    final remaining = selected.where(existingRegionIds.contains).toIList();
    if (remaining.length == selected.length) return;
    state = state.copyWith(
      selectedRegions: remaining.isEmpty
          ? state.selectedRegions.remove(laneId)
          : state.selectedRegions.add(laneId, remaining),
    );
  }

  /// Remember where the last timeline click landed. Paste and other
  /// click-relative actions use it as their insertion point.
  void recordTimelineClick({required int trackId, required int tick}) {
    final safeTick = tick < 0 ? 0 : tick;
    if (state.lastClickedTrackId == trackId &&
        state.lastClickedTick == safeTick) {
      return;
    }
    state = state.copyWith(
      lastClickedTrackId: trackId,
      lastClickedTick: safeTick,
    );
  }

  // ------------------------------------------------------------------
  // Track metadata mutations
  // ------------------------------------------------------------------

  /// Rename a track with optimistic update and backend rollback on failure.
  Future<Result<void>> changeTrackName(int trackId, String newName) async {
    final original = ref.read(projectProvider).value?.tracks[trackId];

    if (original == null) {
      return ref.notifyErrorResult(Exception('Track not found'));
    }

    // Optimistic update
    _patchTrack(trackId, name: newName, color: original.color);

    final result = await AsyncValue.guard(
      () => track_api.changeTrackName(
        ctx: _ctx,
        trackId: trackId,
        newName: newName,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to rename track: ${result.error}',
      );
      _patchTrack(
        trackId,
        name: original.name,
        color: original.color,
      ); // Rollback
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ================================================
  // Track CRUD
  // ================================================

  /// Change a track's color with optimistic update and backend rollback.
  Future<Result<void>> changeTrackColor(int trackId, Color newColor) async {
    final original = ref.read(projectProvider).value?.tracks[trackId];
    if (original == null) {
      return ref.notifyErrorResult(Exception('Track not found'));
    }

    final colorStr = newColor.toRGBA();
    _patchTrack(trackId, color: colorStr, name: original.name);

    final result = await AsyncValue.guard(
      () => track_api.changeTrackColor(
        ctx: _ctx,
        trackId: trackId,
        newColor: colorStr,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to change track color: ${result.error}',
      );
      _patchTrack(
        trackId,
        color: original.color,
        name: original.name,
      ); // Rollback
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Sets the device channels [trackId] records and whether its input is
  /// heard through it.
  Future<Result<void>> setTrackInput(int trackId, UiTrackInput input) async {
    try {
      final track = await track_api.setTrackInput(
        ctx: _ctx,
        trackId: trackId,
        input: input,
      );
      _projectNotifierRead.upsertTrack(track.id, track);
      return Result.ok(null);
    } catch (error, stackTrace) {
      return ref.notifyErrorResult(
        error,
        title: tr('app-tracks-input-change-failed'),
        stackTrace: stackTrace,
      );
    }
  }

  Future<AsyncValue<Null>> addAudioTrack() async {
    final createRes = await ref.guardApi(() async {
      final newTrack = await addNewAudioTrack(ctx: _ctx);
      _projectNotifierRead.upsertTrack(newTrack.id, newTrack);
      await ref.read(mixerStateProvider.notifier).syncMixerChannel(newTrack.id);
      await ref.read(mixerStateProvider.notifier).syncRoutingConnection();
    });

    if (createRes.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to add audio track: ${createRes.error}',
      );
      return AsyncValue.error(
        Exception(createRes.error.toString()),
        createRes.stackTrace!,
      );
    }
    return createRes;
  }

  Future<Result<void>> addMidiTrackWithGeneratorId(int id) async {
    return (() async {
      final result = await ref.guardApi(() async {
        final newTrack = await track_api.addMidiTrackWithGeneratorId(
          ctx: _ctx,
          registryId: id,
        );
        _projectNotifierRead.upsertTrack(newTrack.id, newTrack);
        if (newTrack.generatorId != null) {
          final generator = await plugin_api.getGenerator(
            ctx: _ctx,
            generatorId: newTrack.generatorId!,
          );
          _projectNotifierRead.upsertGenerator(
            newTrack.generatorId!,
            generator,
          );
        }

        await ref
            .read(mixerStateProvider.notifier)
            .syncMixerChannel(newTrack.id);
        await ref.read(mixerStateProvider.notifier).syncRoutingConnection();
      });

      if (result.hasError) {
        AppLogger.error("Error adding MIDI track: ${result.error}");
        return Result.error(Exception(result.error.toString()));
      }
      return Result.ok(null);
    }).suppressesTelemetryPolling(
      ref.read(telemetryPollingSuppressionProvider.notifier),
    )();
  }

  /// Swaps the generator of a MIDI track for the plugin [registryId], keeping
  /// its clips, mixer channel, and routing.
  Future<Result<void>> replaceTrackGenerator({
    required int trackId,
    required int registryId,
  }) async {
    return (() async {
      final previousGeneratorId = ref
          .read(projectProvider)
          .value
          ?.tracks[trackId]
          ?.generatorId;
      final result = await ref.guardApi(() async {
        final updatedTrack = await track_api.replaceTrackGenerator(
          ctx: _ctx,
          trackId: trackId,
          registryId: registryId,
        );
        final generatorId = updatedTrack.generatorId;
        final generator = generatorId == null
            ? null
            : await plugin_api.getGenerator(
                ctx: _ctx,
                generatorId: generatorId,
              );
        // The replaced generator's automation was removed with it.
        final lanes = await getAutomationsLanesAll(ctx: _ctx);
        final links = await getAllLinkedModulationParams(ctx: _ctx);
        final sources = await getAllModulationSources(ctx: _ctx);

        if (previousGeneratorId != null) {
          _projectNotifierRead.removeGenerator(previousGeneratorId);
        }
        if (generatorId != null && generator != null) {
          _projectNotifierRead.upsertGenerator(generatorId, generator);
        }
        _projectNotifierRead.upsertTrack(trackId, updatedTrack);
        _projectNotifierRead.updateAutomations(
          pool: lanes.lock,
          links: links.lock,
          sources: sources.lock,
        );

        // A piano roll previewing through the replaced generator follows the
        // track to its new one.
        final pianoRoll = ref.read(pianoRollProvider.notifier);
        if (previousGeneratorId != null &&
            ref.read(pianoRollProvider).previewGeneratorId ==
                previousGeneratorId) {
          pianoRoll.setPreviewGenerator(generatorId: generatorId);
        }
      });

      if (result.hasError) {
        AppLogger.error("Error replacing track generator: ${result.error}");
        return Result.error(Exception(result.error.toString()));
      }
      return Result.ok(null);
    }).suppressesTelemetryPolling(
      ref.read(telemetryPollingSuppressionProvider.notifier),
    )();
  }

  Future<void> deleteTrack({required int trackId}) {
    return (() async {
      final result = await ref.guardApi(() async {
        await track_api.deleteTrack(ctx: _ctx, trackId: trackId);
        _projectNotifierRead.removeTrack(trackId);

        await ref.read(mixerStateProvider.notifier).syncMixerState();
      });

      if (result.hasError) {
        AppLogger.error(
          'TrackListNotifier: failed to delete track: ${result.error}',
        );
      }
    }).suppressesTelemetryPolling(
      ref.read(telemetryPollingSuppressionProvider.notifier),
    )();
  }
  // ------------------------------------------------------------------
  // Clip CRUD
  // ------------------------------------------------------------------

  /// Create an empty MIDI pattern clip on [trackId] at [startTime].
  Future<Result<void>> createEmptyPatternClip({
    required int trackId,
    required int startTime,
  }) async {
    final result = await AsyncValue.guard(() async {
      final newClip = await createClip(
        ctx: _ctx,
        sourceType: UiSourceType.midi,
        trackId: trackId,
        startTime: startTime,
      );
      // await syncTrack(trackId);
      // insert the new clip into the track
      final track = ref.read(projectProvider).value?.tracks[trackId];
      if (track == null) {
        throw Exception("Track not found");
      }

      final updated = track.copyWith(clips: [...track.clips, newClip]);
      _projectNotifierRead.upsertTrack(trackId, updated);

      switch (newClip.source) {
        case UiClipSource_Midi(:final patternId):
          final newPattern = await getPattern(ctx: _ctx, patternId: patternId);
          _projectNotifierRead.upsertPattern(patternId, newPattern);
        default:
      }
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error creating pattern clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Import [filePath] into the project and place it on an audio track.
  ///
  /// The Rust source import and the central project-state merge stay paired so
  /// the arranger cannot drift from the audio engine after a browser drop.
  Future<Result<void>> createAudioClipFromFile({
    required String filePath,
    required int trackId,
    required int startTick,
  }) async {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) {
      return ref.notifyErrorResult(Exception('Target track not found'));
    }
    if (track.trackType != UiTrackType.audio) {
      return ref.notifyErrorResult(
        Exception(tr('app-tracks-samples-audio-only')),
      );
    }

    final sourceResult = await _projectNotifierRead.loadAudioSource(filePath);
    if (sourceResult.isErr()) return Result.error(sourceResult.err());

    final result = await AsyncValue.guard(() async {
      final sourceId = sourceResult.ok();
      final newClip = await createClip(
        ctx: _ctx,
        sourceId: sourceId,
        sourceType: UiSourceType.audio,
        trackId: trackId,
        startTime: startTick,
      );

      final currentTrack = ref.read(projectProvider).value?.tracks[trackId];
      if (currentTrack == null) {
        await syncTrack(trackId);
      } else {
        _projectNotifierRead.upsertTrack(
          trackId,
          currentTrack.copyWith(clips: [...currentTrack.clips, newClip]),
        );
      }

      selectClip(trackId: trackId, clipId: newClip.id);
      ref.invalidate(audioSourcesProvider);
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: failed to create browser sample clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  Future<Result<void>> renameClip(
    int trackId,
    int clipId,
    String newName,
  ) async {
    final result = await AsyncValue.guard(() async {
      await track_api.renameClip(ctx: _ctx, clipId: clipId, newName: newName);
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error renaming clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }

    final currentTrack = ref.read(projectProvider).value?.tracks[trackId];
    if (currentTrack == null) {
      await syncTrack(trackId);
    } else {
      _projectNotifierRead.upsertTrack(
        trackId,
        currentTrack.copyWith(
          clips: currentTrack.clips
              .map(
                (clip) =>
                    clip.id == clipId ? clip.copyWith(name: newName) : clip,
              )
              .toList(),
        ),
      );
    }

    return Result.ok(null);
  }

  /// Delete a single clip, with an optimistic local removal.
  Future<Result<void>> deleteClip(int trackId, int clipId) async {
    _optimisticDeleteClips(trackId, {clipId});
    _pruneSelection(trackId, {clipId});
    final result = await AsyncValue.guard(() async {
      await track_api.deleteClip(ctx: _ctx, trackId: trackId, clipId: clipId);
      syncTrack(trackId);
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error deleting clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Slice a clip at the timeline tick [cutPoint].
  Future<Result<void>> sliceClip(int trackId, int clipId, int cutPoint) async {
    final result = await AsyncValue.guard(() async {
      await track_api.sliceClip(
        ctx: _ctx,
        sourceTrackId: trackId,
        clipId: clipId,
        cutPoint: cutPoint,
      );
      await syncTrack(trackId);
    });

    if (result.hasError) {
      AppLogger.error('TrackListNotifier: error slicing clip: ${result.error}');
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Resize a clip edge, with an optimistic local update. With [stretch], an
  /// audio clip's audio is stretched to the new length instead of trimmed.
  Future<Result<void>> resizeClip(
    int trackId,
    int clipId,
    UiResizeEdge edge,
    int newTime, {
    bool stretch = false,
  }) async {
    final sourcesBefore = _clipSources(trackId);
    _applyOptimisticResize(trackId, clipId, edge, newTime);
    final result = await AsyncValue.guard(
      () => track_api.resizeClip(
        ctx: _ctx,
        trackId: trackId,
        clipId: clipId,
        edge: edge,
        newTimeVal: newTime,
        stretch: stretch,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error resizing clip: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    final clip = result.requireValue;
    _replaceClips(trackId, [clip]);
    await _refreshSourcesIfChanged(sourcesBefore, [clip]);
    return Result.ok(null);
  }

  /// Move a clip, optionally to a different track, with an optimistic update.
  Future<Result<void>> moveClip(
    int trackId,
    int clipId,
    int newStartTime, {
    int? newTrackId,
  }) async {
    final validationError = _validateClipMove(
      trackId,
      newTrackId,
      plural: false,
    );
    if (validationError != null) return validationError;

    final tracks = ref.read(projectProvider).value?.tracks;
    final originalSourceTrack = tracks?[trackId];
    final originalTargetTrack = newTrackId == null || newTrackId == trackId
        ? null
        : tracks?[newTrackId];

    _applyOptimisticMove(trackId, clipId, newStartTime, newTrackId);
    final result = await AsyncValue.guard(
      () => track_api.moveClip(
        ctx: _ctx,
        sourceTrackId: trackId,
        clipId: clipId,
        newStartTime: newStartTime,
        newTrackId: newTrackId,
      ),
    );

    if (result.hasError) {
      AppLogger.error('TrackListNotifier: error moving clip: ${result.error}');
      _restoreMovedTracks(
        trackId: trackId,
        sourceTrack: originalSourceTrack,
        targetTrackId: newTrackId,
        targetTrack: originalTargetTrack,
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Batch clip operations
  // ------------------------------------------------------------------

  /// Moves the selected clips [steps] cells of [grid] along the timeline (a
  /// single tick per step without a grid). Stops at the start of the timeline.
  Future<Result<void>> nudgeSelectedClips({
    required int steps,
    required GridSize grid,
  }) async {
    if (state.spansLanes || state.selectedRegions.isNotEmpty) {
      return moveSelection(steps * grid.ticks);
    }
    final trackId = state.selectedTrackId;
    final clipIds = state.selectedClipIds;
    final track = trackId == null
        ? null
        : ref.read(projectProvider).value?.tracks[trackId];
    if (trackId == null || track == null || clipIds.isEmpty) {
      return Result.ok(null);
    }
    final starts = track.clips
        .where((clip) => clipIds.contains(clip.id))
        .map((clip) => clip.startTimeInTicks);
    if (starts.isEmpty) return Result.ok(null);
    final earliestStart = starts.reduce((a, b) => a < b ? a : b);

    var deltaTicks = steps * grid.ticks;
    if (deltaTicks < -earliestStart) deltaTicks = -earliestStart;
    if (deltaTicks == 0) return Result.ok(null);

    return moveClipBatch(trackId, clipIds.toList(), deltaTicks);
  }

  /// Move multiple clips by [deltaTicks], with an optimistic update.
  Future<Result<void>> moveClipBatch(
    int trackId,
    List<int> clipIds,
    int deltaTicks, {
    int? newTrackId,
  }) async {
    final validationError = _validateClipMove(
      trackId,
      newTrackId,
      plural: true,
    );
    if (validationError != null) return validationError;

    final tracks = ref.read(projectProvider).value?.tracks;
    final originalSourceTrack = tracks?[trackId];
    final originalTargetTrack = newTrackId == null || newTrackId == trackId
        ? null
        : tracks?[newTrackId];

    _applyOptimisticMoveBatch(trackId, clipIds, deltaTicks, newTrackId);
    final result = await AsyncValue.guard(
      () => track_api.moveClipBatch(
        ctx: _ctx,
        sourceTrackId: trackId,
        clipIds: clipIds,
        deltaTicks: deltaTicks,
        newTrackId: newTrackId,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error batch-moving clips: ${result.error}',
      );
      _restoreMovedTracks(
        trackId: trackId,
        sourceTrack: originalSourceTrack,
        targetTrackId: newTrackId,
        targetTrack: originalTargetTrack,
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Resize multiple clips by [deltaTicks], with an optimistic update. With
  /// [stretch], audio clips stretch their audio to the new length.
  Future<Result<void>> resizeClipBatch(
    int trackId,
    List<int> clipIds,
    UiResizeEdge edge,
    int deltaTicks, {
    bool stretch = false,
  }) async {
    final sourcesBefore = _clipSources(trackId);
    _applyOptimisticResizeBatch(trackId, clipIds, edge, deltaTicks);
    final result = await AsyncValue.guard(
      () => track_api.resizeClipBatch(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
        edge: edge,
        deltaTicks: deltaTicks,
        stretch: stretch,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error batch-resizing clips: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    // Stretching resizes scale the content offset and may give a clip its own
    // copy of its source, so adopt the backend's clips.
    final clips = result.requireValue;
    _replaceClips(trackId, clips);
    await _refreshSourcesIfChanged(sourcesBefore, clips);
    return Result.ok(null);
  }

  /// Atomically duplicate a selected clip group at predetermined start times.
  /// Start times are timeline ticks. Unlike the clipboard APIs below, this
  /// operation never changes ClipboardContent.
  Future<Result<List<UiClip>>> duplicateClipGroups({
    required int trackId,
    required List<int> clipIds,
    required List<int> groupStartTimes,
  }) async {
    if (clipIds.isEmpty || groupStartTimes.isEmpty) {
      return Result.ok(const []);
    }

    try {
      final duplicated = await track_api.duplicateClipGroups(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
        groupStartTimes: groupStartTimes,
      );
      if (duplicated.isEmpty) return Result.ok(const []);

      final track = ref.read(projectProvider).value?.tracks[trackId];
      if (track == null) {
        await syncTrack(trackId);
      } else {
        _projectNotifierRead.upsertTrack(
          trackId,
          track.copyWith(clips: [...track.clips, ...duplicated]),
        );
      }

      return Result.ok(duplicated);
    } catch (error) {
      AppLogger.error(
        'TrackListNotifier: error atomically duplicating clip groups: $error',
      );
      return ref.notifyErrorResult(Exception(error.toString()));
    }
  }

  /// Gives the clips their own copies of the waveforms or patterns they share
  /// with other clips (hard copy). Clips whose content is already unique are
  /// left unchanged.
  Future<Result<List<UiClip>>> makeClipsUnique({
    required int trackId,
    required List<int> clipIds,
  }) async {
    if (clipIds.isEmpty) return Result.ok(const []);

    try {
      final made = await track_api.makeClipsUnique(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
      );
      if (made.clips.isEmpty) return Result.ok(const []);

      _projectNotifierRead
        ..upsertPatternBulk(made.patterns)
        ..upsertSourceEnvelopes(made.sourceEnvelopes);
      _replaceClips(trackId, made.clips);
      if (made.sourceEnvelopes.isNotEmpty) {
        ref.invalidate(audioSourcesProvider);
      }
      return Result.ok(made.clips);
    } catch (error) {
      AppLogger.error('TrackListNotifier: error making clips unique: $error');
      return ref.notifyErrorResult(Exception(error.toString()));
    }
  }

  /// Replaces an audio clip's own gain envelope.
  Future<Result<void>> setClipEnvelope({
    required int trackId,
    required int clipId,
    required UiGainEnvelope envelope,
  }) async {
    try {
      final clip = await track_api.setClipEnvelope(
        ctx: _ctx,
        clipId: clipId,
        envelope: envelope,
      );
      _replaceClips(trackId, [clip]);
      return Result.ok(null);
    } catch (error) {
      AppLogger.error('TrackListNotifier: error editing clip envelope: $error');
      return ref.notifyErrorResult(Exception(error.toString()));
    }
  }

  /// Replaces a clip's pan and pitch curves and loop.
  Future<Result<void>> setClipModulation({
    required int trackId,
    required int clipId,
    required UiClipModulation modulation,
  }) async {
    try {
      final clip = await track_api.setClipModulation(
        ctx: _ctx,
        clipId: clipId,
        modulation: modulation,
      );
      _replaceClips(trackId, [clip]);
      return Result.ok(null);
    } catch (error) {
      AppLogger.error(
        'TrackListNotifier: error editing clip modulation: $error',
      );
      return ref.notifyErrorResult(Exception(error.toString()));
    }
  }

  /// Delete multiple clips at once, with an optimistic local removal.
  Future<Result<void>> deleteClipBatch(int trackId, List<int> clipIds) async {
    _optimisticDeleteClips(trackId, clipIds.toSet());
    _pruneSelection(trackId, clipIds.toSet());

    final result = await AsyncValue.guard(() async {
      await track_api.deleteClipBatch(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
      );
      await syncTrack(trackId);
    });

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error batch-deleting clips: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Delete all currently selected clips and clear the selection.
  Future<Result<void>> deleteSelectedClips() async {
    if (state.spansLanes || state.selectedRegions.isNotEmpty) {
      return deleteSelection();
    }
    final trackId = state.selectedTrackId;
    final clipIds = state.selectedClipIds;
    if (trackId == null || clipIds.isEmpty) return Result.ok(null);
    final result = await deleteClipBatch(trackId, clipIds.toList());
    deselectAllClips();
    return result;
  }

  // ------------------------------------------------------------------
  // Timeline selection: clips and automation regions of any lanes
  // ------------------------------------------------------------------

  List<UiSelectedClips> get _selectedClipGroups => [
    for (final MapEntry(:key, :value) in state.selectedClips.entries)
      UiSelectedClips(trackId: key, clipIds: value.toList()),
  ];

  List<UiSelectedRegions> get _selectedRegionGroups => [
    for (final MapEntry(:key, :value) in state.selectedRegions.entries)
      UiSelectedRegions(laneId: key, regionIds: value.toList()),
  ];

  /// Tick spans of every selected clip and region, as (start, end) pairs.
  List<(int, int)> selectionSpans() {
    final project = ref.read(projectProvider).value;
    if (project == null) return const [];
    final bpm = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    return [
      for (final MapEntry(:key, :value) in state.selectedClips.entries)
        for (final clip in project.tracks[key]?.clips ?? const <UiClip>[])
          if (value.contains(clip.id))
            (
              clip.startTimeInTicks,
              clip.startTimeInTicks + clip.loopLengthInTicks(bpm, sampleRate),
            ),
      for (final MapEntry(:key, :value) in state.selectedRegions.entries)
        for (final region
            in project.automationPool[key]?.regions ??
                const <AutomationRegionDto>[])
          if (value.contains(region.id)) (region.startTicks, region.endTicks),
    ];
  }

  /// Closest move to [deltaTicks] that keeps the selection at or after tick
  /// zero and its regions clear of the regions they would run into.
  int clampSelectionMove(int deltaTicks) {
    var delta = deltaTicks;
    final spans = selectionSpans();
    if (spans.isEmpty) return 0;
    final start = spans.map((span) => span.$1).reduce(math.min);
    if (delta < -start) delta = -start;
    final pool = ref.read(projectProvider).value?.automationPool;
    for (final MapEntry(:key, :value) in state.selectedRegions.entries) {
      final lane = pool?[key];
      if (lane == null) continue;
      delta = clampTowardZero(
        delta,
        clampRegionMove(lane, value.toSet(), delta),
      );
    }
    return delta;
  }

  /// Closest resize of [edge] to [deltaTicks] that keeps every selected item
  /// at least [minTicks] long and its regions clear of their neighbours.
  int clampSelectionResize(
    UiResizeEdge edge,
    int deltaTicks, {
    int minTicks = 10,
  }) {
    final spans = selectionSpans();
    if (spans.isEmpty) return 0;
    final shortest = spans.map((span) => span.$2 - span.$1).reduce(math.min);
    final maxShrink = math.max(0, shortest - minTicks);
    var delta = switch (edge) {
      UiResizeEdge.right => math.max(deltaTicks, -maxShrink),
      UiResizeEdge.left => math.min(deltaTicks, maxShrink),
    };
    if (edge == UiResizeEdge.left) {
      final start = spans.map((span) => span.$1).reduce(math.min);
      delta = math.max(delta, -start);
    }
    final pool = ref.read(projectProvider).value?.automationPool;
    for (final MapEntry(:key, :value) in state.selectedRegions.entries) {
      final lane = pool?[key];
      if (lane == null) continue;
      delta = clampTowardZero(
        delta,
        clampRegionResize(lane, value.toSet(), edge, delta),
      );
    }
    return delta;
  }

  /// Shows [previewLane] on every lane with selected regions until the engine
  /// confirms the edit.
  void _previewSelectedRegions(
    AutomationLaneDto Function(AutomationLaneDto lane, Set<int> ids)
    previewLane,
  ) {
    final project = ref.read(projectProvider).value;
    if (project == null || state.selectedRegions.isEmpty) return;
    var pool = project.automationPool;
    for (final MapEntry(:key, :value) in state.selectedRegions.entries) {
      final lane = pool[key];
      if (lane != null) pool = pool.add(key, previewLane(lane, value.toSet()));
    }
    ref.read(projectProvider.notifier).updateAutomations(pool: pool);
  }

  /// Reloads tracks and lanes after a selection edit and reports its error.
  Future<Result<void>> _finishSelectionEdit(
    AsyncValue<void> result,
    String action,
  ) async {
    await (
      syncTracks(),
      ref.read(automationProvider.notifier).syncLanes(),
    ).wait;
    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error $action the selection: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    return Result.ok(null);
  }

  /// Moves every selected clip and region by [deltaTicks] on its own track or
  /// lane, as one undo step.
  Future<Result<void>> moveSelection(int deltaTicks) async {
    final delta = clampSelectionMove(deltaTicks);
    if (delta == 0) return Result.ok(null);
    final clips = _selectedClipGroups;
    final regions = _selectedRegionGroups;

    for (final group in clips) {
      _applyOptimisticMoveBatch(group.trackId, group.clipIds, delta, null);
    }
    _previewSelectedRegions((lane, ids) => previewRegionMove(lane, ids, delta));

    final result = await AsyncValue.guard(
      () => track_api.moveSelection(
        ctx: _ctx,
        clips: clips,
        regions: regions,
        deltaTicks: delta,
      ),
    );
    return _finishSelectionEdit(result, 'moving');
  }

  /// Moves [edge] of every selected clip and region by [deltaTicks], as one
  /// undo step. With [stretch], audio clips stretch their audio.
  Future<Result<void>> resizeSelection(
    UiResizeEdge edge,
    int deltaTicks, {
    bool stretch = false,
  }) async {
    final delta = clampSelectionResize(edge, deltaTicks);
    if (delta == 0) return Result.ok(null);
    final clips = _selectedClipGroups;
    final regions = _selectedRegionGroups;

    if (!stretch) {
      for (final group in clips) {
        _applyOptimisticResizeBatch(group.trackId, group.clipIds, edge, delta);
      }
    }
    _previewSelectedRegions(
      (lane, ids) => previewRegionResize(lane, ids, edge, delta),
    );

    final result = await AsyncValue.guard(
      () => track_api.resizeSelection(
        ctx: _ctx,
        clips: clips,
        regions: regions,
        edge: edge,
        deltaTicks: delta,
        stretch: stretch,
      ),
    );
    return _finishSelectionEdit(result, 'resizing');
  }

  /// Deletes every selected clip and region as one undo step and clears the
  /// selection.
  Future<Result<void>> deleteSelection() async {
    if (!state.hasSelection) return Result.ok(null);
    final clips = _selectedClipGroups;
    final regions = _selectedRegionGroups;
    for (final group in clips) {
      _optimisticDeleteClips(group.trackId, group.clipIds.toSet());
    }
    deselectAllClips();

    final result = await AsyncValue.guard(
      () =>
          track_api.deleteSelection(ctx: _ctx, clips: clips, regions: regions),
    );
    return _finishSelectionEdit(result, 'deleting');
  }

  /// Cuts every selected clip and region that [atTick] passes through, as one
  /// undo step.
  Future<Result<void>> sliceSelection(int atTick) async {
    final project = ref.read(projectProvider).value;
    if (project == null) return Result.ok(null);
    final bpm = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    bool cuts(int start, int end) => atTick > start && atTick < end;

    final clips = [
      for (final MapEntry(:key, :value) in state.selectedClips.entries)
        UiSelectedClips(
          trackId: key,
          clipIds: [
            for (final clip in project.tracks[key]?.clips ?? const <UiClip>[])
              if (value.contains(clip.id) &&
                  cuts(
                    clip.startTimeInTicks,
                    clip.startTimeInTicks +
                        clip.loopLengthInTicks(bpm, sampleRate),
                  ))
                clip.id,
          ],
        ),
    ].where((group) => group.clipIds.isNotEmpty).toList();
    final regions = [
      for (final MapEntry(:key, :value) in state.selectedRegions.entries)
        UiSelectedRegions(
          laneId: key,
          regionIds: [
            for (final region
                in project.automationPool[key]?.regions ??
                    const <AutomationRegionDto>[])
              if (value.contains(region.id) &&
                  cuts(region.startTicks, region.endTicks))
                region.id,
          ],
        ),
    ].where((group) => group.regionIds.isNotEmpty).toList();
    if (clips.isEmpty && regions.isEmpty) return Result.ok(null);

    final result = await AsyncValue.guard(
      () => track_api.sliceSelection(
        ctx: _ctx,
        clips: clips,
        regions: regions,
        atTick: atTick,
      ),
    );
    return _finishSelectionEdit(result, 'slicing');
  }

  // ------------------------------------------------------------------
  // Clip timing
  // ------------------------------------------------------------------

  /// Snaps the starts and ends of the selected clips to [grid] as one undo
  /// step. Clips keep at least one grid cell.
  Future<Result<void>> quantizeSelectedClips(GridSize grid) =>
      _retimeSelectedClips(
        (trackId, clipIds) => track_api.quantizeClips(
          ctx: _ctx,
          trackId: trackId,
          clipIds: clipIds,
          stepTicks: grid.ticks,
        ),
      );

  /// Snaps the starts of the selected clips to [grid] as one undo step,
  /// keeping their lengths.
  Future<Result<void>> quantizeSelectedClipStarts(GridSize grid) =>
      _retimeSelectedClips(
        (trackId, clipIds) => track_api.quantizeClipStarts(
          ctx: _ctx,
          trackId: trackId,
          clipIds: clipIds,
          stepTicks: grid.ticks,
        ),
      );

  /// Makes each selected clip end where the next selected clip starts, as one
  /// undo step.
  Future<Result<void>> legatoSelectedClips() => _retimeSelectedClips(
    (trackId, clipIds) =>
        track_api.legatoClips(ctx: _ctx, trackId: trackId, clipIds: clipIds),
  );

  /// Runs [retime] on the selected clips and adopts the clips it changed.
  Future<Result<void>> _retimeSelectedClips(
    Future<List<UiClip>> Function(int trackId, List<int> clipIds) retime,
  ) async {
    final trackId = state.selectedTrackId;
    final clipIds = state.selectedClipIds;
    if (trackId == null || clipIds.isEmpty) return Result.ok(null);
    final result = await AsyncValue.guard(
      () => retime(trackId, clipIds.toList()),
    );
    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error retiming clips: ${result.error}',
      );
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }
    _replaceClips(trackId, result.requireValue);
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // Clipboard (clips)
  // ------------------------------------------------------------------

  /// Copy the given clips to the session clipboard.
  Future<Result<void>> copySelectedClips({
    required int trackId,
    required List<int> clipIds,
  }) async {
    try {
      await session_api.copyClips(
        ctx: _ctx,
        trackId: trackId,
        clipIds: clipIds,
      );
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error copying clips: $e');
      return ref.notifyErrorResult(Exception('$e'));
    }
  }

  /// Cut the given clips to the session clipboard, with optimistic removal.
  Future<Result<void>> cutSelectedClips({
    required int trackId,
    required List<int> clipIds,
  }) async {
    try {
      await session_api.cutClips(ctx: _ctx, trackId: trackId, clipIds: clipIds);
      _optimisticDeleteClips(trackId, clipIds.toSet());
      // Clear selection
      if (state.selectedTrackId == trackId) deselectAllClips();
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error cutting clips: $e');
      return ref.notifyErrorResult(Exception('$e'));
    }
  }

  /// Paste clips from the session clipboard onto [targetTrackId].
  Future<Result<void>> pasteClips({
    required int targetTrackId,
    required int pasteStartTime,
    required UiTrackType trackType,
  }) async {
    try {
      final clips = await session_api.pasteClips(
        ctx: _ctx,
        targetTrackId: targetTrackId,
        pasteStartTime: pasteStartTime,
        trackType: trackType,
      );

      if (clips.isEmpty) return Result.ok(null);

      // Optimistic: append pasted clips directly into central state
      final currentTracks = ref.read(projectProvider).value?.tracks;
      if (currentTracks != null && currentTracks.containsKey(targetTrackId)) {
        final track = currentTracks[targetTrackId]!;
        final updatedClips = List<UiClip>.from(track.clips)..addAll(clips);

        ref
            .read(projectProvider.notifier)
            .upsertTrack(targetTrackId, track.copyWith(clips: updatedClips));

        selectClips(
          trackId: targetTrackId,
          clipIds: clips.map((c) => c.id).toList(),
        );
      }

      // Background sync for authoritative state
      await syncTrack(targetTrackId);
      return Result.ok(null);
    } catch (e) {
      AppLogger.error('TrackListNotifier: error pasting clips: $e');
      return ref.notifyErrorResult(Exception('$e'));
    }
  }

  /// Paste clips from the session clipboard at the last clicked timeline
  /// position. Falls back to the selected track when no point was recorded.
  Future<Result<void>> pasteClipsAtLastClick() async {
    final tracks = ref.read(projectProvider).value?.tracks;
    final lastTrackId = state.lastClickedTrackId;
    final targetTrackId =
        lastTrackId != null && tracks?.containsKey(lastTrackId) == true
        ? lastTrackId
        : state.selectedTrackId;
    if (targetTrackId == null) return Result.ok(null);

    final track = tracks?[targetTrackId];
    if (track == null) return Result.ok(null);

    final workspace = ref.read(workspaceStateProvider);
    var pasteTick = state.lastClickedTick ?? 0;
    if (workspace.snapToGrid && workspace.gridSize.value > 0) {
      final ticksPerLine = (960.0 * 4.0) / workspace.gridSize.value;
      if (ticksPerLine > 0) {
        pasteTick = ((pasteTick / ticksPerLine).round() * ticksPerLine).toInt();
      }
    }

    return pasteClips(
      targetTrackId: targetTrackId,
      pasteStartTime: pasteTick < 0 ? 0 : pasteTick,
      trackType: track.trackType,
    );
  }

  /// Duplicates the selected clips directly after the selection and selects
  /// the copies.
  Future<Result<void>> duplicateSelectedClips() async {
    final trackId = state.selectedTrackId;
    final clipIds = state.selectedClipIds.toList(growable: false);
    if (trackId == null || clipIds.isEmpty) return Result.ok(null);

    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return Result.ok(null);

    final bpm = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
    final selected = track.clips
        .where((clip) => clipIds.contains(clip.id))
        .toList(growable: false);
    if (selected.isEmpty) return Result.ok(null);

    final selectionEnd = selected
        .map(
          (clip) =>
              clip.startTimeInTicks + clip.loopLengthInTicks(bpm, sampleRate),
        )
        .reduce((a, b) => a > b ? a : b);

    final result = await duplicateClipGroups(
      trackId: trackId,
      clipIds: clipIds,
      groupStartTimes: [selectionEnd],
    );
    if (result.isErr()) return Result.error(result.err());

    final duplicated = result.ok();
    if (duplicated.isNotEmpty) {
      selectClips(
        trackId: trackId,
        clipIds: duplicated.map((clip) => clip.id).toList(),
      );
    }
    return Result.ok(null);
  }

  /// Reorder [trackId] to [newIdx] within the track list.
  ///
  /// Updates the project tracks before calling the backend so the header and
  /// timeline rows move together immediately. Restores the previous order if
  /// the backend rejects the change.
  Future<Result<void>> handleUpdateTrackOrder({
    required int trackId,
    required int newIdx,
  }) async {
    final tracks = ref.read(projectProvider).value?.tracks;
    if (tracks == null || !tracks.containsKey(trackId)) {
      return ref.notifyErrorResult(Exception('Track not found'));
    }

    final sortedEntries = tracks.entries.toList()
      ..sort((a, b) => a.value.orderIdx.compareTo(b.value.orderIdx));
    final orderedIds = sortedEntries.map((e) => e.key).toList();

    final oldIdx = orderedIds.indexOf(trackId);
    final clampedIdx = newIdx.clamp(0, orderedIds.length - 1);
    if (oldIdx == -1 || oldIdx == clampedIdx) return Result.ok(null);

    final reorderedIds = List<int>.from(orderedIds)
      ..removeAt(oldIdx)
      ..insert(clampedIdx, trackId);

    // Snapshot the original order fields for rollback.
    final originalTracksById = {for (final id in reorderedIds) id: tracks[id]!};

    // Optimistic update: reassign contiguous order values 0..n-1 to match the
    // new sequence. Only tracks whose order actually shifted get pushed.
    final updates = <int, UiTrack>{};
    for (var i = 0; i < reorderedIds.length; i++) {
      final id = reorderedIds[i];
      final track = tracks[id]!;
      if (track.orderIdx != i) {
        updates[id] = track.copyWith(orderIdx: i);
      }
    }
    _projectNotifierRead.upsertTracksBulk(updates);

    final result = await ref.guardApi(
      () => track_api.updateTrackOrder(
        ctx: _ctx,
        trackId: trackId,
        newIdx: clampedIdx,
      ),
    );

    if (result.hasError) {
      AppLogger.error(
        'TrackListNotifier: error updating track order: ${result.error}',
      );
      _projectNotifierRead.upsertTracksBulk(originalTracksById); // rollback
      return ref.notifyErrorResult(Exception(result.error.toString()));
    }

    // Resync in case the backend's order values don't exactly match our
    // contiguous 0..n-1 guess (e.g. it leaves gaps or uses a different scheme).
    await syncTracks();
    return Result.ok(null);
  }

  // ------------------------------------------------------------------
  // View metadata (non-backend)
  // ------------------------------------------------------------------

  /// Update the pixel height for a specific track row.
  void setTrackHeight(int trackId, int height) {
    state = state.copyWith(
      trackIdHeightMap: state.trackIdHeightMap.add(trackId, height),
    );
  }

  // ------------------------------------------------------------------
  // Optimistic helpers
  // ------------------------------------------------------------------

  void _patchTrack(int trackId, {required String name, required String color}) {
    final original = ref.read(projectProvider).value?.tracks[trackId];
    if (original == null) return;

    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, original.copyWith(name: name, color: color));
  }

  void _optimisticDeleteClips(int trackId, Set<int> clipIdSet) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;
    final updatedClips = track.clips
        .where((c) => !clipIdSet.contains(c.id))
        .toList();
    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, track.copyWith(clips: updatedClips));
  }

  /// Drops deleted clips from the selection so a batch delete cannot leave
  /// stale IDs behind.
  void _pruneSelection(int trackId, Set<int> deletedClipIds) {
    final selected = state.clipsSelectedOn(trackId);
    if (selected.isEmpty) return;
    final remaining = selected
        .where((clipId) => !deletedClipIds.contains(clipId))
        .toIList();
    if (remaining.length == selected.length) return;
    final selectedClips = remaining.isEmpty
        ? state.selectedClips.remove(trackId)
        : state.selectedClips.add(trackId, remaining);
    state = state.copyWith(
      selectedClips: selectedClips,
      focusClipId: selectedClips.values.lastOrNull?.lastOrNull,
    );
  }

  void _applyOptimisticResize(
    int trackId,
    int clipId,
    UiResizeEdge edge,
    int newTime,
  ) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;
    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;
    final clip = track.clips[clipIndex];

    int newStart = clip.startTime.toInt();
    int newLength = clip.loopLength.toInt();
    int newOffset = clip.offsetStart.toInt();

    if (clip.isSampleBased) {
      final bpm = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
      final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;
      final oldEndTick =
          clip.startTime + samplesToTicks(clip.loopLength, bpm, sampleRate);
      if (edge == UiResizeEdge.right) {
        if (newTime > clip.startTime) {
          newLength = ticksToSamples(newTime - clip.startTime, bpm, sampleRate);
        }
      } else if (newTime < oldEndTick) {
        final deltaSamples = ticksToSamples(
          newTime - clip.startTime,
          bpm,
          sampleRate,
        );
        final potentialOffset = clip.offsetStart + deltaSamples;
        if (potentialOffset >= 0 && clip.loopLength - deltaSamples > 0) {
          newStart = newTime;
          newLength = clip.loopLength - deltaSamples;
          newOffset = potentialOffset;
        }
      }
    } else if (edge == UiResizeEdge.right) {
      if (newTime > clip.startTime) newLength = newTime - clip.startTime;
    } else {
      final oldEnd = clip.startTime + clip.loopLength;
      if (newTime < oldEnd) {
        final delta = newTime - clip.startTime;
        final potentialOffset = clip.offsetStart + delta;
        if (potentialOffset >= 0) {
          newStart = newTime;
          newLength = oldEnd - newTime;
          newOffset = potentialOffset.toInt();
        }
      }
    }

    final updatedClips = List<UiClip>.from(track.clips);
    updatedClips[clipIndex] = clip.copyWith(
      startTime: newStart,
      loopLength: newLength,
      offsetStart: newOffset,
    );
    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, track.copyWith(clips: updatedClips));
  }

  Result<void>? _validateClipMove(
    int sourceTrackId,
    int? targetTrackId, {
    required bool plural,
  }) {
    if (targetTrackId == null || targetTrackId == sourceTrackId) return null;

    final tracks = ref.read(projectProvider).value?.tracks;
    final sourceTrack = tracks?[sourceTrackId];
    final targetTrack = tracks?[targetTrackId];

    if (sourceTrack == null) {
      return ref.notifyErrorResult<void>(Exception('Source track not found'));
    }
    if (targetTrack == null) {
      return ref.notifyErrorResult<void>(Exception('Target track not found'));
    }
    if (sourceTrack.trackType == targetTrack.trackType) return null;

    return ref.notifyErrorResult<void>(
      Exception(
        tr('app-tracks-move-type-mismatch', {
          'source': sourceTrack.trackType.name,
          'target': targetTrack.trackType.name,
          'count': plural ? 2 : 1,
        }),
      ),
    );
  }

  void _restoreMovedTracks({
    required int trackId,
    required UiTrack? sourceTrack,
    required int? targetTrackId,
    required UiTrack? targetTrack,
  }) {
    final restoredTracks = <int, UiTrack>{};
    if (sourceTrack != null) restoredTracks[trackId] = sourceTrack;
    if (targetTrackId != null &&
        targetTrackId != trackId &&
        targetTrack != null) {
      restoredTracks[targetTrackId] = targetTrack;
    }
    if (restoredTracks.isNotEmpty) {
      ref.read(projectProvider.notifier).upsertTracksBulk(restoredTracks);
    }
  }

  void _applyOptimisticMove(
    int trackId,
    int clipId,
    int newStartTime,
    int? newTrackId,
  ) {
    final tracks = ref.read(projectProvider).value?.tracks;
    if (tracks == null) return;

    final track = tracks[trackId];
    if (track == null) return;

    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;

    final clip = track.clips[clipIndex];
    final updatedClip = clip.copyWith(startTime: newStartTime);

    if (newTrackId != null && newTrackId != trackId) {
      final targetTrack = tracks[newTrackId];
      if (targetTrack == null) return;

      final sourceClips = List<UiClip>.from(track.clips)..removeAt(clipIndex);
      final targetClips = List<UiClip>.from(targetTrack.clips)
        ..add(updatedClip);

      ref.read(projectProvider.notifier).upsertTracksBulk({
        trackId: track.copyWith(clips: sourceClips),
        newTrackId: targetTrack.copyWith(clips: targetClips),
      });
    } else {
      final updatedClips = List<UiClip>.from(track.clips);
      updatedClips[clipIndex] = updatedClip;
      ref
          .read(projectProvider.notifier)
          .upsertTrack(trackId, track.copyWith(clips: updatedClips));
    }
  }

  void _applyOptimisticMoveBatch(
    int trackId,
    List<int> clipIds,
    int deltaTicks,
    int? newTrackId,
  ) {
    final tracks = ref.read(projectProvider).value?.tracks;
    if (tracks == null) return;

    final track = tracks[trackId];
    final targetId = newTrackId ?? trackId;
    final targetTrack = tracks[targetId];
    if (track == null || targetTrack == null) return;

    final clipIdSet = clipIds.toSet();
    final clipsToMove = track.clips
        .where((c) => clipIdSet.contains(c.id))
        .toList();

    if (trackId != targetId) {
      final sourceClips = track.clips
          .where((c) => !clipIdSet.contains(c.id))
          .toList();
      final targetClips = List<UiClip>.from(targetTrack.clips);
      for (final clip in clipsToMove) {
        final newStart = (clip.startTime + deltaTicks).clamp(0, 1 << 62);
        targetClips.add(clip.copyWith(startTime: newStart.toInt()));
      }
      ref.read(projectProvider.notifier).upsertTracksBulk({
        trackId: track.copyWith(clips: sourceClips),
        targetId: targetTrack.copyWith(clips: targetClips),
      });
    } else {
      final updatedClips = track.clips.map((clip) {
        if (clipIdSet.contains(clip.id)) {
          final newStart = (clip.startTime + deltaTicks).clamp(0, 1 << 62);
          return clip.copyWith(startTime: newStart.toInt());
        }
        return clip;
      }).toList();
      ref
          .read(projectProvider.notifier)
          .upsertTrack(trackId, track.copyWith(clips: updatedClips));
    }
  }

  /// Replaces clips of [trackId] with the backend's versions, matched by ID.
  /// Audio source of each clip on [trackId], by clip ID.
  Map<int, UiClipSource?> _clipSources(int trackId) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    return {
      for (final clip in track?.clips ?? const <UiClip>[]) clip.id: clip.source,
    };
  }

  /// Reloads source data when [clips] moved to sources the UI has not seen, as
  /// a stretching resize does when it makes a shared clip unique.
  Future<void> _refreshSourcesIfChanged(
    Map<int, UiClipSource?> before,
    List<UiClip> clips,
  ) async {
    final changed = clips.any((clip) => before[clip.id] != clip.source);
    if (!changed) return;
    final envelopes = await attemptAsync(
      () => audio_api.getAudioSourceEnvelopes(ctx: _ctx),
    );
    if (envelopes case Ok(:final value)) {
      _projectNotifierRead.upsertSourceEnvelopes(value);
    }
    ref.invalidate(audioSourcesProvider);
  }

  void _replaceClips(int trackId, List<UiClip> clips) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;
    final byId = {for (final clip in clips) clip.id: clip};
    _projectNotifierRead.upsertTrack(
      trackId,
      track.copyWith(
        clips: [for (final clip in track.clips) byId[clip.id] ?? clip],
      ),
    );
  }

  void _applyOptimisticResizeBatch(
    int trackId,
    List<int> clipIds,
    UiResizeEdge edge,
    int deltaTicks,
  ) {
    final track = ref.read(projectProvider).value?.tracks[trackId];
    if (track == null) return;

    final clipIdSet = clipIds.toSet();
    final bpm = ref.read(transportProvider).value?.state?.bpm ?? 120.0;
    final sampleRate = ref.read(transportProvider).value?.sampleRate ?? 48000;

    final updatedClips = track.clips.map((clip) {
      if (!clipIdSet.contains(clip.id)) return clip;
      return resizedClip(clip, edge, deltaTicks, bpm, sampleRate);
    }).toList();

    ref
        .read(projectProvider.notifier)
        .upsertTrack(trackId, track.copyWith(clips: updatedClips));
  }
}

// ============================================================
// Provider
// ============================================================

/// Top-level Riverpod 3 provider for track list state.
///
/// Read: `ref.watch(trackListStateProvider)`
/// Mutate: `ref.read(trackListStateProvider.notifier).syncTracksState()`
final trackListStateProvider =
    NotifierProvider<TrackListNotifier, TrackListState>(TrackListNotifier.new);

/// Each handle keeps its whole decoded audio buffer alive in Rust, so stale
/// handles must be released: entries dispose with their last listener and
/// refresh when a full backend fetch may have replaced the buffers.
final trackWaveformProvider = Provider.autoDispose
    .family<Map<int, WaveformHandle>, ({int trackId})>((ref, arg) {
      ref.watch(
        projectProvider.select(
          (s) => (s.value?.tracks[arg.trackId], s.value?.fullStateRevision),
        ),
      );
      // A finished render or tempo edit replaces a source's playback state.
      ref.watch(backgroundJobsProvider.select((s) => s.sourceRevisions));
      final ctx = ref.read(projectProvider.notifier).dawContext;
      final handles = getWaveformHandlesForTrack(
        ctx: ctx,
        trackId: arg.trackId,
      );
      // Unmounted widget closures (e.g. kept by stale semantics) can outlive
      // this state, so release the buffers now instead of waiting for GC.
      ref.onDispose(() {
        for (final handle in handles.values) {
          handle.dispose();
        }
      });
      return handles;
    });
