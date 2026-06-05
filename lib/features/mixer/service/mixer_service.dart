import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/result_type.dart';

List<UiRoutingConnection> getMixerChannelDest(
  GlobalAppState state, {
  required UiRoutingNode source,
}) {
  // find from the mixer state and return it. We don't fetch
  // the latest state from Rust side because we assume a guarantee that every
  // routing data update syncs the state from backend to the Flutter side
  return state.mixerState.routing.where((conn) {
    return conn.source == source;
  }).toList();
}

Future<Result<void>> addNewRouting(
  GlobalAppState state, {
  required UiRoutingNode source,
  required UiRoutingNode dest,
  required double sendLevel,
  required bool isSend,
}) async {
  return await attemptAsync(() async {
    await setRouting(
      source: source,
      destination: dest,
      sendLevel: sendLevel,
      isSend: isSend,
    );
    // TODO: Add optimistic update before syncing
    // Attempt a sync only on routing connection
    return await state.syncRoutingConnection();
  });
}

Future<Result<void>> removeRouting(
  GlobalAppState state, {
  required UiRoutingNode source,
  required UiRoutingNode destination,
  required bool isSend,
}) async {
  return await attemptAsync(() async {
    await mixer_api.removeRouting(
      source: source,
      destination: destination,
      isSend: isSend,
    );
    // TODO: Add optimistic update before syncing
    return await state.syncRoutingConnection();
  });
}

Future<Result<void>> removeBus(
  GlobalAppState state, {
  required int busId,
}) async {
  return await attemptAsync(() async {
    await mixer_api.deleteBus(busId: busId);
    // TODO: Add optimistic update before syncing

    (state.syncBuses(), state.syncRoutingConnection()).wait;
  });
}

Future<Result<void>> updateRoutingCall(
  GlobalAppState state, {
  required UiRoutingNode src,
  required UiRoutingNode dest,
  required double sendLvl,
  required bool isSend,
}) async {
  return await attemptAsync(() async {
    await mixer_api.updateRouting(
      conn: UiRoutingConnection(
        source: src,
        destination: dest,
        sendLevel: sendLvl,
        isSend: isSend,
      ),
    );

    return await state.syncRoutingConnection();
  });
}
