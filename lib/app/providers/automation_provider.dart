import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/project.dart';

part 'automation_provider.freezed.dart';

@freezed
abstract class AutomationDataState with _$AutomationDataState {
  const factory AutomationDataState({
    @Default(false) bool isMasterAutomationDrawerOpened,

    /// Tracks which track automations are collapsed.
    /// If a trackId is NOT in this set, it is considered expanded (defaults to true).
    @Default(ISetConst({})) ISet<int> collapsedTrackAutomations,

    /// Tracks which bus automations are collapsed.
    @Default(ISetConst({})) ISet<int> collapsedBusAutomations,

    /// Optional: Tracks the currently selected/highlighted automation lane in the UI
    int? selectedAutomationLaneId,

    /// Per-lane pixel heights, keyed by automation lane ID.
    @Default(IMapConst<int, int>({})) IMap<int, int> automationLaneHeights,

    /// Automation lanes shrunk to a title-only row.
    @Default(ISetConst<int>({})) ISet<int> collapsedAutomationLaneIds,
  }) = _AutomationDataState;
}

typedef ChannelAutomationEntry = ({
  int laneId,
  int linkId,
  AutomationTargetDto target,
  AutomationLaneDto lane,
});

/// A plugin parameter paired with its current automation availability.
final class PluginAutomationCandidate {
  /// The unified parameter metadata exposed by the plugin.
  final plugin_api.UiPluginParameter parameter;

  /// Whether an automation source already controls this exact parameter.
  final bool alreadyAutomated;

  const PluginAutomationCandidate({
    required this.parameter,
    required this.alreadyAutomated,
  });
}

/// Maps a plugin parameter to the automation target the engine applies it to.
AutomationTargetDto automationTargetForPluginParameter(
  plugin_api.UiPluginTarget target,
  int paramId,
) {
  MixerChannelParamTargetDto effectParam(int effectId) =>
      MixerChannelParamTargetDto.plugin(
        effectId: effectId,
        target: EffectAutomationTargetDto.pluginParam(paramId: paramId),
      );

  return switch (target) {
    plugin_api.UiPluginTarget_Generator(:final field0) =>
      AutomationTargetDto.generator(generatorId: field0, paramId: paramId),
    plugin_api.UiPluginTarget_TrackEffect(:final trackId, :final effectId) =>
      AutomationTargetDto.track(
        trackId: trackId,
        trackTarget: TrackAutomationTargetDto.mixerChannel(
          effectParam(effectId),
        ),
      ),
    plugin_api.UiPluginTarget_BusEffect(:final busId, :final effectId) =>
      AutomationTargetDto.bus(busId: busId, mixTarget: effectParam(effectId)),
    plugin_api.UiPluginTarget_MasterEffect(:final field0) =>
      AutomationTargetDto.master(
        MasterAutomationTargetDto.mixerChannel(effectParam(field0)),
      ),
  };
}

class AutomationNotifier extends Notifier<AutomationDataState> {
  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  @override
  AutomationDataState build() {
    return AutomationDataState();
  }

  // =========================================================================
  // UI STATE MANAGEMENT
  // =========================================================================

  void toggleMasterAutomationDrawer() {
    state = state.copyWith(
      isMasterAutomationDrawerOpened: !state.isMasterAutomationDrawerOpened,
    );
  }

  void toggleTrackAutomationExpanded(int trackId) {
    final collapsed = state.collapsedTrackAutomations;
    if (collapsed.contains(trackId)) {
      state = state.copyWith(
        collapsedTrackAutomations: collapsed.remove(trackId),
      );
    } else {
      state = state.copyWith(collapsedTrackAutomations: collapsed.add(trackId));
    }
  }

  /// Expands a track automation drawer without collapsing an open drawer.
  void ensureTrackAutomationExpanded(int trackId) {
    final collapsed = state.collapsedTrackAutomations;
    if (!collapsed.contains(trackId)) return;
    state = state.copyWith(
      collapsedTrackAutomations: collapsed.remove(trackId),
    );
  }

  void toggleBusAutomationExpanded(int busId) {
    final collapsed = state.collapsedBusAutomations;
    if (collapsed.contains(busId)) {
      state = state.copyWith(collapsedBusAutomations: collapsed.remove(busId));
    } else {
      state = state.copyWith(collapsedBusAutomations: collapsed.add(busId));
    }
  }

  void selectAutomationLane(int? laneId) {
    state = state.copyWith(selectedAutomationLaneId: laneId);
  }

  static const int defaultLaneHeight = 60;
  static const int minLaneHeight = 36;
  static const int maxLaneHeight = 300;

  /// Sets (upserts) the pixel height of an automation lane.
  void changeAutomationLaneHeight({
    required int laneId,
    required int newHeight,
  }) {
    final clamped = newHeight.clamp(minLaneHeight, maxLaneHeight).toInt();
    if (state.automationLaneHeights.get(laneId) == clamped) return;
    state = state.copyWith(
      automationLaneHeights: state.automationLaneHeights.add(laneId, clamped),
    );
  }

  /// Removes the override so the lane falls back to the default height.
  void resetAutomationLaneHeight({required int laneId}) {
    if (state.automationLaneHeights.get(laneId) == null) return;
    state = state.copyWith(
      automationLaneHeights: state.automationLaneHeights.remove(laneId),
    );
  }

  /// Shrinks an automation lane to its title row, or expands it back.
  void toggleAutomationLaneCollapsed({required int laneId}) {
    final collapsed = state.collapsedAutomationLaneIds;
    state = state.copyWith(
      collapsedAutomationLaneIds: collapsed.contains(laneId)
          ? collapsed.remove(laneId)
          : collapsed.add(laneId),
    );
  }

  /// Expands a bus automation drawer without collapsing an open drawer.
  void ensureBusAutomationExpanded(int busId) {
    final collapsed = state.collapsedBusAutomations;
    if (!collapsed.contains(busId)) return;
    state = state.copyWith(collapsedBusAutomations: collapsed.remove(busId));
  }

  /// Opens the master automation drawer without closing it.
  void ensureMasterAutomationDrawerOpened() {
    if (state.isMasterAutomationDrawerOpened) return;
    state = state.copyWith(isMasterAutomationDrawerOpened: true);
  }

  // =========================================================================
  // BACKEND INTERACTION
  // =========================================================================

  Future<AsyncValue<void>> handleAddAutomationForTarget({
    required AutomationTargetDto target,
    required String label,
    required double min,
    required double max,
    required double initialValue,
  }) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
      ref.notifyError('Project state is missing');
      return AsyncError("Project state is missing", StackTrace.current);
    }

    // Capture the original state before any modifications for a safe rollback
    final originalPool = projectData.automationPool;
    final originalLinks = projectData.modulationLinks;
    final originalSources = projectData.modulationSources;

    try {
      // Fetch the new lane and link from Rust
      final (newLane, link) = await addAutomationLane(
        ctx: _ctx,
        target: target,
        label: label,
        min: min,
        max: max,
        initialValue: initialValue,
      );

      AppLogger.debug(
        "Add automation lane for $target with $min - $max initial value: $initialValue",
      );

      // Fetch the generated source based on the new link
      final source = await getModulationSource(ctx: _ctx, id: link.sourceId);

      if (source == null) {
        throw Exception(
          "Failed to retrieve the new modulation source from Rust.",
        );
      }

      // Create the updated immutable maps
      final newPool = originalPool.add(newLane.id, newLane);
      final newLinks = originalLinks.add(link.id, link);
      final newSources = originalSources.add(link.sourceId, source);

      // Push the full patch to the project provider
      ref
          .read(projectProvider.notifier)
          .updateAutomations(
            pool: newPool,
            links: newLinks,
            sources: newSources,
          );

      return const AsyncData(null);
    } catch (e, s) {
      ref.notifyError(e, stackTrace: s);
      // Rollback all three maps if anything fails
      if (ref.read(projectProvider).hasValue) {
        ref
            .read(projectProvider.notifier)
            .updateAutomations(
              pool: originalPool,
              links: originalLinks,
              sources: originalSources,
            );
      }
      return AsyncError(e, s);
    }
  }

  /// Creates automation for one generator or effect parameter through the
  /// generic path, then reveals the drawer that shows the new lane.
  Future<AsyncValue<void>> handleAddPluginParameterAutomation({
    required plugin_api.UiPluginTarget target,
    required plugin_api.UiPluginParameter parameter,
  }) async {
    final result = await handleAddAutomationForTarget(
      target: automationTargetForPluginParameter(target, parameter.id),
      label: parameter.name,
      min: parameter.min,
      max: parameter.max,
      initialValue: parameter.value.clamp(parameter.min, parameter.max),
    );
    if (result.hasValue) _revealDrawerFor(target);
    return result;
  }

  void _revealDrawerFor(plugin_api.UiPluginTarget target) {
    switch (target) {
      case plugin_api.UiPluginTarget_Generator(:final field0):
        final track = ref
            .read(projectProvider)
            .value
            ?.tracks
            .values
            .where((track) => track.generatorId == field0)
            .firstOrNull;
        if (track != null) ensureTrackAutomationExpanded(track.id);
      case plugin_api.UiPluginTarget_TrackEffect(:final trackId):
        ensureTrackAutomationExpanded(trackId);
      case plugin_api.UiPluginTarget_BusEffect(:final busId):
        ensureBusAutomationExpanded(busId);
      case plugin_api.UiPluginTarget_MasterEffect():
        ensureMasterAutomationDrawerOpened();
    }
  }

  /// Enables or disables a lane while retaining its source, link, and points.
  Future<void> handleSetAutomationLaneEnabled({
    required int laneId,
    required bool enabled,
  }) async {
    final projectData = ref.read(projectProvider).value;
    if (projectData == null) {
      ref.notifyError('Project state is missing');
      return;
    }

    final result = await ref.guardApi(
      () => setAutomationLaneEnabled(
        ctx: _ctx,
        automationId: laneId,
        enabled: enabled,
      ),
    );
    if (!result.hasValue) return;

    final latestProjectData = ref.read(projectProvider).value;
    if (latestProjectData == null) return;
    ref
        .read(projectProvider.notifier)
        .updateAutomations(
          pool: latestProjectData.automationPool.add(laneId, result.value!),
        );
  }

  Future<void> handleRemoveAutomationForTarget({
    required AutomationTargetDto target,
  }) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
      // Used throwing exception here so that flutter widget able to catch it onError
      final error = Exception("Project state is missing");
      ref.notifyError(error);
      throw error;
    }

    final originalPool = projectData.automationPool;
    final originalLinks = projectData.modulationLinks;
    final originalSources = projectData.modulationSources;
    try {
      // wrap the async call to result type
      final removeResult = await attemptAsync(() async {
        return await removeAutomationLaneFor(ctx: _ctx, target: target);
      });

      if (removeResult.isErr()) {
        throw removeResult.err();
      }

      final (
        removedAutomationId,
        removedModulationSourceIds,
        removedModulationLinkIds,
      ) = removeResult
          .ok();

      // remove the link first
      final newLinks = originalLinks.removeWhere(
        (id, _) => removedModulationLinkIds.contains(id),
      );
      final newSources = originalSources.removeWhere(
        (id, _) => removedModulationSourceIds.contains(id),
      );
      final newAutomationPool = originalPool.remove(removedAutomationId);

      ref
          .read(projectProvider.notifier)
          .updateAutomations(
            pool: newAutomationPool,
            links: newLinks,
            sources: newSources,
          );
    } catch (e) {
      AppLogger.error("Cannot remove the targeted automation: $e");
      ref.notifyError(e);
      // Rollback all three maps if anything fails
      if (ref.read(projectProvider).hasValue) {
        ref
            .read(projectProvider.notifier)
            .updateAutomations(
              pool: originalPool,
              links: originalLinks,
              sources: originalSources,
            );
      }
    }
  }

  Future<AsyncValue<void>> addModulation(ModulationSourceDto source) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
      ref.notifyError('Project state is missing');
      return AsyncError("Project state is missing", StackTrace.current);
    }

    // Capture original state for rollback
    final originalSources = projectData.modulationSources;

    try {
      final newSourceId = await addModulationSource(ctx: _ctx, source: source);
      final newSources = originalSources.add(newSourceId, source);
      ref.read(projectProvider.notifier).updateAutomations(sources: newSources);

      return const AsyncData(null);
    } catch (e, s) {
      ref.notifyError(e, stackTrace: s);
      if (ref.read(projectProvider).hasValue) {
        ref
            .read(projectProvider.notifier)
            .updateAutomations(sources: originalSources);
      }
      return AsyncError(e, s);
    }
  }

  Future<void> addPoint(int laneId, int timeTicks, double value) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
      AppLogger.error("Project state is missing");
      ref.notifyError('Project state is missing');
      return;
    }

    final result = await ref.guardApi(() async {
      final newLane = await addNewAutomationPoint(
        ctx: _ctx,
        automationId: laneId,
        timeTicks: timeTicks,
        value: value,
      );

      return newLane;
    });

    if (result.hasError) {
      AppLogger.error(result.error!.toString());
      return;
    }

    final updatedLanes = projectData.automationPool.add(laneId, result.value!);

    ref.read(projectProvider.notifier).updateAutomations(pool: updatedLanes);

    AppLogger.info(
      "Successfully add new point for lane $laneId at $timeTicks with value $value",
    );
  }

  Future<void> removePoint(int laneId, int pointId) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
      AppLogger.error("Project state is missing");
      ref.notifyError('Project state is missing');
      return;
    }

    final removalResult = await ref.guardApi(() async {
      return await removeAutomationPoint(
        ctx: _ctx,
        automationId: laneId,
        id: pointId,
      );
    });

    if (removalResult.hasError) {
      AppLogger.error(removalResult.error!.toString());
      return;
    }

    final updatedLanes = projectData.automationPool.add(
      laneId,
      removalResult.value!,
    );
    ref.read(projectProvider.notifier).updateAutomations(pool: updatedLanes);
  }

  Future<void> updatePoint({
    required int automationLaneId,
    required int pointId,
    int? timeTicks,
    double? value,
    double? tension,
    AutomationCurveTypeDto? curveType,
  }) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
      AppLogger.error("Project state is missing");
      ref.notifyError('Project state is missing');
      return;
    }

    final updateRes = await ref.guardApi(() async {
      return await updateAutomationPoint(
        ctx: _ctx,
        automationId: automationLaneId,
        id: pointId,
        timeTicks: timeTicks,
        value: value,
        tension: tension,
        curveType: curveType,
      );
    });

    if (updateRes.hasError) {
      if (updateRes.error != null) {
        AppLogger.error(
          "Error when calling update automation point to Rust: ${updateRes.error.toString()}",
        );
        return;
      }
    }

    if (!updateRes.hasValue) return;

    final newIndex = updateRes.value!;

    final lane = projectData.automationPool[automationLaneId];
    if (lane == null) {
      AppLogger.error("Automation lane $automationLaneId not found in pool.");
      return;
    }

    // Copy the points for mutation
    final updatedPoints = List<AutomationPointDto>.from(lane.points);

    final oldIndex = updatedPoints.indexWhere((p) => p.id == pointId);
    if (oldIndex == -1) {
      AppLogger.error("Point ID $pointId not found in lane $automationLaneId.");
      return;
    }

    // Construct the updated point containing the new coordinates
    final oldPoint = updatedPoints[oldIndex];

    final finalTimeTicks = timeTicks ?? oldPoint.timeTicks;
    final finalValue = value ?? oldPoint.value;
    final finalTension = tension ?? oldPoint.tension;
    final finalCurveType = curveType ?? oldPoint.curveType;

    final newPoint = oldPoint.copyWith(
      value: finalValue,
      timeTicks: finalTimeTicks,
      tension: finalTension,
      curveType: finalCurveType,
    );

    updatedPoints.removeAt(oldIndex);

    final safeInsertIndex = newIndex.clamp(0, updatedPoints.length);
    updatedPoints.insert(safeInsertIndex, newPoint);

    final updatedLane = lane.copyWith(points: updatedPoints);
    final updatedPool = projectData.automationPool.add(
      automationLaneId,
      updatedLane,
    );

    ref.read(projectProvider.notifier).updateAutomations(pool: updatedPool);
  }
}

// ==========================================================
// Reactive UI Providers
// ==========================================================

/// Tracks whether a track's automation accordion is expanded.
/// Defaults to true unless explicitly collapsed in the AutomationDataState.
final trackAutomationExpandedProvider = Provider.family<bool, int>((
  ref,
  trackId,
) {
  final collapsed = ref.watch(
    automationProvider.select((s) => s.collapsedTrackAutomations),
  );
  return !collapsed.contains(trackId);
});

/// Layout of one automation lane row: whether it is shrunk, and its height.
typedef AutomationLaneLayout = ({bool collapsed, double height});

/// Effective layout for an automation lane, shared by its header and slot so
/// both sides of the arranger stay aligned.
final automationLaneLayoutProvider = Provider.family<AutomationLaneLayout, int>(
  (ref, laneId) {
    final collapsed = ref.watch(
      automationProvider.select(
        (s) => s.collapsedAutomationLaneIds.contains(laneId),
      ),
    );
    if (collapsed) {
      return (collapsed: true, height: TrackListNotifier.collapsedLaneHeight);
    }
    final height = ref.watch(
      automationProvider.select(
        (s) =>
            s.automationLaneHeights.get(laneId) ??
            AutomationNotifier.defaultLaneHeight,
      ),
    );
    return (collapsed: false, height: height.toDouble());
  },
);

/// Tracks whether a bus's automation accordion is expanded.
/// Defaults to true unless explicitly collapsed in the AutomationDataState.
final busAutomationExpandedProvider = Provider.family<bool, int>((ref, busId) {
  final collapsed = ref.watch(
    automationProvider.select((s) => s.collapsedBusAutomations),
  );
  return !collapsed.contains(busId);
});

/// Provider to get all automation lanes for a specific Bus ID.
/// Usage in Widget: `final lanes = ref.watch(busAutomationProvider(busId));`
final busAutomationProvider =
    Provider.family<List<ChannelAutomationEntry>, int>((ref, busId) {
      final projectData = ref.watch(projectProvider).value;
      if (projectData == null) return const [];

      final lanes = <ChannelAutomationEntry>[];

      for (final link in projectData.modulationLinks.values) {
        final target = link.target;

        if (target is AutomationTargetDto_Bus && target.busId == busId) {
          final source = projectData.modulationSources[link.sourceId];

          if (source is ModulationSourceDto_Automation) {
            final laneId = source.laneId;
            final lane = projectData.automationPool[laneId];

            if (lane != null) {
              lanes.add((
                laneId: laneId,
                linkId: link.id,
                target: target,
                lane: lane,
              ));
            }
          }
        }
      }

      // Sort visually based on the UI order index
      lanes.sort((a, b) {
        final linkA = projectData.modulationLinks[a.linkId]!;
        final linkB = projectData.modulationLinks[b.linkId]!;
        return linkA.orderIdx.compareTo(linkB.orderIdx);
      });

      return lanes;
    });

/// Provider to get all automation lanes for a specific Track ID.
/// Usage in Widget: `final lanes = ref.watch(trackAutomationProvider(trackId));`
final trackAutomationProvider =
    Provider.family<List<ChannelAutomationEntry>, int>((ref, trackId) {
      final projectData = ref.watch(projectProvider).value;
      if (projectData == null) return const [];

      final lanes = <ChannelAutomationEntry>[];

      for (final link in projectData.modulationLinks.values) {
        final target = link.target;
        target.when(
          generator: (generatorId, paramId) {
            // find the track associated with this generator
            final findTrackRes = attempt(() {
              return projectData.tracks.toValueIList().firstWhere((track) {
                return track.generatorId != null &&
                    track.generatorId == generatorId;
              });
            });

            if (findTrackRes.isOk()) {
              if (findTrackRes.ok().id == trackId) {
                final source = projectData.modulationSources[link.sourceId];
                if (source is ModulationSourceDto_Automation) {
                  final laneId = source.laneId;
                  final lane = projectData.automationPool[laneId];

                  if (lane != null) {
                    lanes.add((
                      laneId: laneId,
                      linkId: link.id,
                      target: target,
                      lane: lane,
                    ));
                  }
                }
              }
            }
          },
          track: (trackTargetId, trackTarget) {
            if (trackTargetId == trackId) {
              final source = projectData.modulationSources[link.sourceId];
              if (source is ModulationSourceDto_Automation) {
                final laneId = source.laneId;
                final lane = projectData.automationPool[laneId];

                if (lane != null) {
                  lanes.add((
                    laneId: laneId,
                    linkId: link.id,
                    target: target,
                    lane: lane,
                  ));
                }
              }
            }
          },
          bus: (_, _) {},
          master: (_) {},
        );
      }

      // Sort visually based on the UI order index
      lanes.sort((a, b) {
        final linkA = projectData.modulationLinks[a.linkId]!;
        final linkB = projectData.modulationLinks[b.linkId]!;
        return linkA.orderIdx.compareTo(linkB.orderIdx);
      });

      return lanes;
    });

/// Fetch all Automation lanes for all buses, grouped by Bus ID.
/// Call this when you want to render the whole mixer's automation state at once.
final allBusesAutomationProvider =
    Provider<Map<int, List<ChannelAutomationEntry>>>((ref) {
      final projectData = ref.watch(projectProvider).value;
      if (projectData == null) return const {};

      final map = <int, List<ChannelAutomationEntry>>{};

      for (final link in projectData.modulationLinks.values) {
        final target = link.target;

        if (target is AutomationTargetDto_Bus) {
          final busId = target.busId;
          final source = projectData.modulationSources[link.sourceId];

          if (source is ModulationSourceDto_Automation) {
            final laneId = source.laneId;
            final lane = projectData.automationPool[laneId];

            if (lane != null) {
              map.putIfAbsent(busId, () => []).add((
                laneId: laneId,
                linkId: link.id,
                target: target,
                lane: lane,
              ));
            }
          }
        }
      }

      for (final busLanes in map.values) {
        busLanes.sort((a, b) {
          final linkA = projectData.modulationLinks[a.linkId]!;
          final linkB = projectData.modulationLinks[b.linkId]!;
          return linkA.orderIdx.compareTo(linkB.orderIdx);
        });
      }

      return map;
    });

final masterAutomationProvider = Provider<List<ChannelAutomationEntry>>((ref) {
  final projectData = ref.watch(projectProvider).value;
  if (projectData == null) return const [];

  final lanes = <ChannelAutomationEntry>[];

  for (final link in projectData.modulationLinks.values) {
    final target = link.target;

    if (target is AutomationTargetDto_Master) {
      final source = projectData.modulationSources[link.sourceId];

      if (source is ModulationSourceDto_Automation) {
        final laneId = source.laneId;
        final lane = projectData.automationPool[laneId];

        if (lane != null) {
          lanes.add((
            laneId: laneId,
            linkId: link.id,
            target: target,
            lane: lane,
          ));
        }
      }
    }
  }

  lanes.sort((a, b) {
    final linkA = projectData.modulationLinks[a.linkId]!;
    final linkB = projectData.modulationLinks[b.linkId]!;
    return linkA.orderIdx.compareTo(linkB.orderIdx);
  });

  return lanes;
});

/// Loads a plugin's automatable parameters and marks those that already have
/// an automation lane.
final pluginAutomationCandidatesProvider = FutureProvider.autoDispose
    .family<List<PluginAutomationCandidate>, plugin_api.UiPluginTarget>((
      ref,
      target,
    ) async {
      final projectData = ref.watch(projectProvider).value;
      if (projectData == null) {
        throw StateError('Project state is missing');
      }

      final ctx = ref.read(projectProvider.notifier).dawContext;
      final parameters = await plugin_api.getAutomatablePluginParameterSpecs(
        ctx: ctx,
        target: target,
      );
      final automatedTargets = <AutomationTargetDto>{
        for (final link in projectData.modulationLinks.values)
          if (projectData.modulationSources[link.sourceId]
              is ModulationSourceDto_Automation)
            link.target,
      };

      final candidates = parameters
          .map(
            (parameter) => PluginAutomationCandidate(
              parameter: parameter,
              alreadyAutomated: automatedTargets.contains(
                automationTargetForPluginParameter(target, parameter.id),
              ),
            ),
          )
          .toList();
      String groupName(plugin_api.UiPluginParameter parameter) {
        final group = parameter.group.trim();
        return group.isEmpty ? 'Other' : group;
      }

      candidates.sort((a, b) {
        final groupComparison = groupName(
          a.parameter,
        ).toLowerCase().compareTo(groupName(b.parameter).toLowerCase());
        if (groupComparison != 0) return groupComparison;
        final nameComparison = a.parameter.name.toLowerCase().compareTo(
          b.parameter.name.toLowerCase(),
        );
        if (nameComparison != 0) return nameComparison;
        return a.parameter.id.compareTo(b.parameter.id);
      });
      return candidates;
    });

final automationProvider =
    NotifierProvider<AutomationNotifier, AutomationDataState>(
      () => AutomationNotifier(),
    );
