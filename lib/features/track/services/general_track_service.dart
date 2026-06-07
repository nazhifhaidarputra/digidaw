// ‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒
// Function to call API from provider
// ‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/track.dart';

Future<Result<void>> handleUpdateTrackOrder({
  required WidgetRef ref,
  required int trackId,
  required int newIdx,
}) async {
  return await attemptAsync(() async {
    return await updateTrackOrder(trackId: trackId, newIdx: newIdx);
  }).andThenAsync((_) async {
    await ref.read(globalStateProvider).syncTracksState();
    return Result.ok(null);
  });
}
