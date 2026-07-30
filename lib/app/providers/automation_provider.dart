import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/src/rust/api/automation.dart';
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
  }) = _AutomationDataState;
}

typedef ChannelAutomationEntry = (
  int laneId,
  int linkId,
  AutomationLaneDto lane,
);

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

  void toggleBusAutomationExpanded(int busId) {
    final collapsed = state.collapsedBusAutomations;
    if (collapsed.contains(busId)) {
      state = state.copyWith(
        collapsedBusAutomations: collapsed.remove(busId),
      );
    } else {
      state = state.copyWith(collapsedBusAutomations: collapsed.add(busId));
    }
  }

  void selectAutomationLane(int? laneId) {
    state = state.copyWith(selectedAutomationLaneId: laneId);
  }

  // =========================================================================
  // BACKEND INTERACTION
  // =========================================================================

  Future<AsyncValue<void>> handleAddAutomationForTarget({
    required AutomationTargetDto target,
    required String label,
    required double min,
    required double max,
    required double defaultValue,
  }) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
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
        defaultValue: defaultValue,
      );

      AppLogger.debug(
        "Add automation lane for $target with $min - $max default: $defaultValue",
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

  Future<AsyncValue<void>> addModulation(ModulationSourceDto source) async {
    final projectData = ref.read(projectProvider).value;

    if (projectData == null) {
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
      return;
    }

    final result = await AsyncValue.guard(() async {
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
      return;
    }

    final removalResult = await AsyncValue.guard(() async {
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
      return;
    }

    final updateRes = await AsyncValue.guard(() async {
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

/// Tracks whether a bus's automation accordion is expanded.
/// Defaults to true unless explicitly collapsed in the AutomationDataState.
final busAutomationExpandedProvider = Provider.family<bool, int>((
  ref,
  busId,
) {
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
              lanes.add((laneId, link.id, lane));
            }
          }
        }
      }

      // Sort visually based on the UI order index
      lanes.sort((a, b) {
        final linkA = projectData.modulationLinks[a.$2]!;
        final linkB = projectData.modulationLinks[b.$2]!;
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

        if (target is AutomationTargetDto_Track && target.trackId == trackId) {
          final source = projectData.modulationSources[link.sourceId];

          if (source is ModulationSourceDto_Automation) {
            final laneId = source.laneId;
            final lane = projectData.automationPool[laneId];

            if (lane != null) {
              lanes.add((laneId, link.id, lane));
            }
          }
        }
      }

      // Sort visually based on the UI order index
      lanes.sort((a, b) {
        final linkA = projectData.modulationLinks[a.$2]!;
        final linkB = projectData.modulationLinks[b.$2]!;
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
              map.putIfAbsent(busId, () => []).add((laneId, link.id, lane));
            }
          }
        }
      }

      for (final busLanes in map.values) {
        busLanes.sort((a, b) {
          final linkA = projectData.modulationLinks[a.$2]!;
          final linkB = projectData.modulationLinks[b.$2]!;
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
          lanes.add((laneId, link.id, lane));
        }
      }
    }
  }

  lanes.sort((a, b) {
    final linkA = projectData.modulationLinks[a.$2]!;
    final linkB = projectData.modulationLinks[b.$2]!;
    return linkA.orderIdx.compareTo(linkB.orderIdx);
  });

  return lanes;
});

final automationProvider =
    NotifierProvider<AutomationNotifier, AutomationDataState>(
      () => AutomationNotifier(),
    );
