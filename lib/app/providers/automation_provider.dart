import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/project.dart';

part 'automation_provider.freezed.dart';

@freezed
abstract class AutomationDataState with _$AutomationDataState {
  const factory AutomationDataState() = _AutomationDataState;
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

      // Fetch the generated source based on the new link
      final source = await getModulationSource(ctx: _ctx, id: link.sourceId);
      
      if (source == null) {
        throw Exception("Failed to retrieve the new modulation source from Rust.");
      }

      // Create the updated immutable maps
      final newPool = originalPool.add(newLane.id, newLane);
      final newLinks = originalLinks.add(link.id, link);
      final newSources = originalSources.add(link.sourceId, source);

      // Push the full patch to the project provider
      ref.read(projectProvider.notifier).updateAutomations(
            pool: newPool,
            links: newLinks,
            sources: newSources,
          );

      return const AsyncData(null);
    } catch (e, s) {
      // Rollback all three maps if anything fails
      if (ref.read(projectProvider).hasValue) {
        ref.read(projectProvider.notifier).updateAutomations(
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
      final newSourceId = await addModulationSource(
        ctx: _ctx,
        source: source,
      );
      final newSources = originalSources.add(newSourceId, source);
      ref.read(projectProvider.notifier).updateAutomations(sources: newSources);

      return const AsyncData(null);
    } catch (e, s) {
      if (ref.read(projectProvider).hasValue) {
        ref.read(projectProvider.notifier).updateAutomations(sources: originalSources);
      }
      return AsyncError(e, s);
    }
  }
}

// ==========================================================
// Reactive UI Providers
// ==========================================================

/// Provider to get all automation lanes for a specific Bus ID.
/// Usage in Widget: `final lanes = ref.watch(busAutomationProvider(busId));`
final busAutomationProvider = Provider.family<List<ChannelAutomationEntry>, int>((ref, busId) {
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
final trackAutomationProvider = Provider.family<List<ChannelAutomationEntry>, int>((ref, trackId) {
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
final allBusesAutomationProvider = Provider<Map<int, List<ChannelAutomationEntry>>>((ref) {
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

final automationProvider =
    NotifierProvider<AutomationNotifier, AutomationDataState>(
      () => AutomationNotifier(),
    );
