import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/project.dart' show DawContext;
import 'package:karbeat/src/rust/api/track.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';

part 'clip_placement_state.freezed.dart';

@freezed
abstract class ClipPlacementState with _$ClipPlacementState {
  const factory ClipPlacementState({
    int? sourceId,
    UiSourceType? sourceType,
    @Default(-1) int trackId,
    @Default(0.0) double timeSamples,
  }) = _ClipPlacementState;
}

extension ClipPlacementHelper on ClipPlacementState {
  bool get isPlacing => sourceId != null;
}

class ClipPlacementNotifier extends Notifier<ClipPlacementState> {
  @override
  ClipPlacementState build() => const ClipPlacementState();

  ProjectNotifier get _projectProvider => ref.read(projectProvider.notifier);
  DawContext get _ctx => _projectProvider.dawContext;

  void startPlacement(int sourceId, {required UiSourceType type}) {
    state = ClipPlacementState(sourceId: sourceId, sourceType: type);
    ref.read(globalStateProvider).navigateTo(WorkspaceView.trackList);
  }

  void updatePlacementTarget(int trackId, double timeSamples) {
    state = state.copyWith(trackId: trackId, timeSamples: timeSamples);
  }

  void cancelPlacement() {
    state = const ClipPlacementState();
  }

  Future<Result<void>> confirmPlacement() async {
    final s = state;
    AppLogger.info("CONFIRM Placement");
    if (s.sourceId != null && s.sourceType != null && s.trackId != -1) {
      try {
        await createClip(
          ctx: _ctx,
          sourceId: s.sourceId!,
          sourceType: s.sourceType!,
          trackId: s.trackId,
          startTime: s.timeSamples.toInt(),
        );
        ref.read(globalStateProvider).notifyCustomBackendChange(() async {
          await ref.read(globalStateProvider).syncTrackState(s.trackId);
        });
        state = const ClipPlacementState();
        return Result.ok(null);
      } catch (e) {
        AppLogger.error("Error creating clip: $e");
        return Result.error(Exception("$e"));
      }
    }
    return Result.ok(null);
  }
}

final clipPlacementProvider = NotifierProvider<ClipPlacementNotifier, ClipPlacementState>(
  () => ClipPlacementNotifier(),
);
