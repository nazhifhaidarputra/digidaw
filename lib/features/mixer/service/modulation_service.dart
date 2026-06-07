import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/result_type.dart';

typedef ChannelAutomationEntry = (
  int laneId,
  int linkId,
  AutomationLaneDto lane,
);

Future<Result<void>> addModulation(
  GlobalAppState state,
  ModulationSourceDto source,
) async {
  final addModRes = await attemptAsync(() async {
    final _ = await addModulationSource(source: source);
  });
  if (addModRes.isErr()) return addModRes;
  final syncRes = await state.syncAutomationAndModulationState();
  return syncRes;
}

/// Fetch all Automation lanes for all buses, grouped by Bus ID.
/// Call this when you want to render the whole mixer's automation state at once.
Map<int, List<ChannelAutomationEntry>> getAutomationLaneBuses(
  GlobalAppState state,
) {
  final map = <int, List<ChannelAutomationEntry>>{};

  for (final link in state.modulationLinks.values) {
    final target = link.target;

    if (target is AutomationTargetDto_Bus) {
      final busId = target.busId;
      final source = state.modulationSources[link.sourceId];

      // Ensure the source driving this link is an Automation Lane
      if (source is ModulationSourceDto_Automation) {
        final laneId = source.laneId;
        final lane = state.automationPool[laneId];

        if (lane != null) {
          map.putIfAbsent(busId, () => []).add((laneId, link.id, lane));
        }
      }
    }
  }

  // Sort each bus's lanes by the link's UI order index
  for (final busLanes in map.values) {
    busLanes.sort((a, b) {
      final linkA = state.modulationLinks[a.$2]!;
      final linkB = state.modulationLinks[b.$2]!;
      return linkA.orderIdx.compareTo(linkB.orderIdx);
    });
  }

  return map;
}

/// Fetch all Automation lanes specifically for a single bus.
List<ChannelAutomationEntry> getAutomationLaneBus(
  GlobalAppState state, {
  required int sourceBusId,
}) {
  final lanes = <ChannelAutomationEntry>[];

  for (final link in state.modulationLinks.values) {
    final target = link.target;

    if (target is AutomationTargetDto_Bus && target.busId == sourceBusId) {
      final source = state.modulationSources[link.sourceId];

      if (source is ModulationSourceDto_Automation) {
        final laneId = source.laneId;
        final lane = state.automationPool[laneId];

        if (lane != null) {
          lanes.add((laneId, link.id, lane));
        }
      }
    }
  }

  // Sort visually based on the UI order index
  lanes.sort((a, b) {
    final linkA = state.modulationLinks[a.$2]!;
    final linkB = state.modulationLinks[b.$2]!;
    return linkA.orderIdx.compareTo(linkB.orderIdx);
  });

  return lanes;
}

/// Fetch all Automation lanes specifically for a single track.
List<ChannelAutomationEntry> getAutomationLaneTrack(
  GlobalAppState state, {
  required int trackId,
}) {
  final lanes = <ChannelAutomationEntry>[];

  for (final link in state.modulationLinks.values) {
    final target = link.target;

    if (target is AutomationTargetDto_Track && target.trackId == trackId) {
      final source = state.modulationSources[link.sourceId];

      if (source is ModulationSourceDto_Automation) {
        final laneId = source.laneId;
        final lane = state.automationPool[laneId];

        if (lane != null) {
          lanes.add((laneId, link.id, lane));
        }
      }
    }
  }

  // Sort visually based on the UI order index
  lanes.sort((a, b) {
    final linkA = state.modulationLinks[a.$2]!;
    final linkB = state.modulationLinks[b.$2]!;
    return linkA.orderIdx.compareTo(linkB.orderIdx);
  });

  return lanes;
}

/// Provider to get all automation lanes for a specific Bus ID.
/// Usage in Widget: `final lanes = ref.watch(busAutomationProvider(busId));`
final busAutomationProvider =
    Provider.family<List<ChannelAutomationEntry>, int>((ref, busId) {
      final state = ref.watch(globalStateProvider);
      return getAutomationLaneBus(state, sourceBusId: busId);
    });

/// Provider to get all automation lanes for a specific Track ID.
/// Usage in Widget: `final lanes = ref.watch(trackAutomationProvider(trackId));`
final trackAutomationProvider =
    Provider.family<List<ChannelAutomationEntry>, int>((ref, trackId) {
      final state = ref.watch(globalStateProvider);
      final track = getAutomationLaneTrack(state, trackId: trackId);
      AppLogger.info("$track");
      return track;
    });
