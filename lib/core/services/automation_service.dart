import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/automation.dart';

Future<void> handleAddAutomationForTarget(
  GlobalAppState state, {
  required AutomationTargetDto target,
  required String label,
  required double min,
  required double max,
  required double defaultValue,
}) async {
  final newLaneResult = await attemptAsync(() async {
    final newLane = await addAutomationLane(
      target: target,
      label: label,
      min: min,
      max: max,
      defaultValue: defaultValue,
    );

    return newLane;
  });

  // if it is error, just return
  if (newLaneResult.isErr()) {
    return;
  }

  final newLane = newLaneResult.unwrap();

  // Push this new lane into automation pool in global state
  state.automationPool.putIfAbsent(newLane.id, () => newLane);
  await state.syncAutomationAndModulationState();
}
