// ‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒
// Function to call API from provider
// ‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart' as track_api;

class GeneralTrackService {
  Future<Result<void>> updateTrackOrder({required DawContext ctx, required int trackId, required int newIdx}) async {
    return attemptAsync(() =>track_api.updateTrackOrder(ctx: ctx, trackId: trackId, newIdx: newIdx));
  }
}

final generalTrackServiceProvider = Provider<GeneralTrackService>((ref) {
  return GeneralTrackService();
});

