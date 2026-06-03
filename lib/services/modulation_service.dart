import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/models/id.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/utils/result_type.dart';

Future<Result<ModulationId>> addModulation() async {
  return await attemptAsync(() async {
    return 0;
  });
}

/// Fetch all Automation lane for all buses. call this when we update
/// the list of automation lane of buses.
Future<Result<Map<int,List<(AutomationId, ModulationId, AutomationLaneDto)>>>> fetchAutomationLaneBuses({required WidgetRef ref}) async {
  return await attemptAsync(() async {
    return {};
  });
}

/// Fetch all Automation lane for all buses. call this when we do an update
/// that affects only on single track. For example: removing lane from a track.
Future<Result<List<(AutomationId, ModulationId, AutomationLaneDto)>>> fetchAutomationLaneBus({required WidgetRef ref, required int busId}) async {
  return await attemptAsync(() async {
    final lanes = await getAutomationLanesForBus(busId: busId);
    // TODO: Add to store in globalState
    return lanes;
  });
}

/// Fetch all Automation lane for all buses. call this when we update
/// the list of automation lane of buses.
Future<Result<List<(AutomationId, ModulationId, AutomationLaneDto)>>> fetchAutomationLaneTrack({required WidgetRef ref, required int busId}) async {
  return await attemptAsync(() async {
    final lanes = await getAutomationLanesForBus(busId: busId);
    // TODO: Add to store in globalState
    return lanes;
  });
}

Future<Result<List<(AutomationId, ModulationId, AutomationLaneDto)>>> fetchAllModulationAutomationLane({required WidgetRef ref}) async {
  return await attemptAsync(() async {
    return [];
  });
}