import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/models/id.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/state/app_state.dart';
import 'package:karbeat/utils/result_type.dart';

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

/// Fetch all Automation lane for all buses. call this when we update
/// the list of automation lane of buses.
Future<Result<Map<int, List<(AutomationId, ModulationId, AutomationLaneDto)>>>>
getAutomationLaneBuses({required WidgetRef ref}) async {
  return await attemptAsync(() async {
    // final something = await getAut
    return {};
  });
}

/// Fetch all Automation lane for all buses. call this when we do an update
/// that affects only on single track. For example: removing lane from a track.
Future<Result<List<AutomationLaneDto>>>
getAutomationLaneBus(GlobalAppState state, {required int sourceBusId}) async {
  return await attemptAsync(() async {
    // Because all of automation lanes in pools are stored inside the ModulationLinks where
    // we can inspect its connection target. we just iterate that
    final lanes = state.modulationLinks.entries.where((entry) {
      switch (entry.value.target) {

        case AutomationTargetDto_Track():
          return false;
        case AutomationTargetDto_Bus(:final busId):
          return sourceBusId == busId;
        case AutomationTargetDto_Master():
          return false;
        case AutomationTargetDto_TempoBpm():
          return false;
      }
    }).map((entry) => entry.value).toList();

    // final lanes = await getAutomationLanesForBus(busId: busId);
    // TODO: Add to store in globalState
    return lanes;
  });
}

/// Fetch all Automation lane for all buses. call this when we update
/// the list of automation lane of buses.
Future<Result<List<(AutomationId, ModulationId, AutomationLaneDto)>>>
getAutomationLaneTrack({required WidgetRef ref, required int busId}) async {
  return await attemptAsync(() async {
    final lanes = await getAutomationLanesForBus(busId: busId);
    // TODO: Add to store in globalState
    return lanes;
  });
}

// Future<Result<void>>
// gethAllModulations(GlobalAppState state) async {
//   return await attemptAsync(() async {
//     final mod = await getAllLinkedModulationParams();
//     state.sync
//     return mod;
//   });
// }

// Future<Result<ModulationLinkDto>> getModulation