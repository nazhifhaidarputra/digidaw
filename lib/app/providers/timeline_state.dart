import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/telemetry_polling_suppression.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/src/rust/api/project.dart' as project_api;
import 'package:karbeat/src/rust/api/timeline.dart' as timeline_api;
import 'package:karbeat/src/rust/api/timeline.dart';

/// The song loop region, or null when none is set.
final loopRegionProvider = Provider<UiLoopRegion?>(
  (ref) => ref.watch(
    projectProvider.select((project) => project.value?.timeline.loopRegion),
  ),
);

/// Cue markers ordered by position.
final cueMarkersProvider = Provider<List<UiCueMarker>>(
  (ref) => ref.watch(
    projectProvider.select(
      (project) => project.value?.timeline.markers ?? const [],
    ),
  ),
);

/// Edits the song loop region and cue markers, and bounces the loop region.
///
/// The timeline lives in [projectProvider]; every edit here calls the backend
/// and publishes the timeline it returns, so undo, save, and the UI agree.
class TimelineNotifier extends Notifier<void> {
  @override
  void build() {}

  ProjectNotifier get _project => ref.read(projectProvider.notifier);

  Future<Result<void>> setLoopRegion(int startTick, int endTick) {
    final (start, end) = startTick <= endTick
        ? (startTick, endTick)
        : (endTick, startTick);
    return _apply(
      () => timeline_api.setLoopRegion(
        ctx: _project.dawContext,
        region: UiLoopRegion(startTick: start < 0 ? 0 : start, endTick: end),
      ),
      title: tr('app-timeline-loop-set-failed'),
    );
  }

  Future<Result<void>> clearLoopRegion() {
    return _apply(
      () => timeline_api.setLoopRegion(ctx: _project.dawContext, region: null),
      title: tr('app-timeline-loop-clear-failed'),
    );
  }

  Future<Result<void>> addCueMarker(int tick, {String? name}) {
    return _apply(
      () => timeline_api.addCueMarker(
        ctx: _project.dawContext,
        tick: tick < 0 ? 0 : tick,
        name: name,
      ),
      title: tr('app-timeline-cue-add-failed'),
    );
  }

  Future<Result<void>> moveCueMarker(UiCueMarker marker, int tick) {
    return _update(marker, tick: tick < 0 ? 0 : tick);
  }

  Future<Result<void>> renameCueMarker(UiCueMarker marker, String name) {
    return _update(marker, name: name);
  }

  Future<Result<void>> recolorCueMarker(UiCueMarker marker, Color color) {
    return _update(marker, color: color.toRGBA());
  }

  Future<Result<void>> removeCueMarker(UiCueMarker marker) {
    return _apply(
      () =>
          timeline_api.removeCueMarker(ctx: _project.dawContext, id: marker.id),
      title: tr('app-timeline-cue-remove-failed'),
    );
  }

  /// Renders the loop region, every track and bus without the master bus,
  /// into a new audio source and resolves with its ID.
  Future<Result<int>> bounceLoopRegion() async {
    Future<int> render() =>
        project_api.bounceLoopRegion(ctx: _project.dawContext);
    final result = await ref.guardApi(
      render.suppressesTelemetryPolling(
        ref.read(telemetryPollingSuppressionProvider.notifier),
      ),
      title: tr('app-timeline-bounce-failed'),
    );
    switch (result) {
      case AsyncData(:final value):
        ref.invalidate(audioSourcesProvider);
        ref
            .read(notificationProvider.notifier)
            .info(
              tr('app-timeline-bounced-message'),
              title: tr('app-timeline-bounced-title'),
            );
        return Result.ok(value);
      case AsyncError(:final error):
        return Result.error(Exception(error.toString()));
      default:
        return Result.error(Exception('Bounce did not finish'));
    }
  }

  Future<Result<void>> _update(
    UiCueMarker marker, {
    String? name,
    int? tick,
    String? color,
  }) {
    return _apply(
      () => timeline_api.updateCueMarker(
        ctx: _project.dawContext,
        id: marker.id,
        name: name ?? marker.name,
        tick: tick ?? marker.tick,
        color: color ?? marker.color,
      ),
      title: tr('app-timeline-cue-edit-failed'),
    );
  }

  Future<Result<void>> _apply(
    Future<UiTimelineState> Function() edit, {
    required String title,
  }) async {
    final result = await ref.guardApi(edit, title: title);
    switch (result) {
      case AsyncData(:final value):
        _project.updateTimeline(value);
        return Result.ok(null);
      case AsyncError(:final error):
        return Result.error(Exception(error.toString()));
      default:
        return Result.error(Exception('$title: no result'));
    }
  }
}

final timelineProvider = NotifierProvider<TimelineNotifier, void>(
  TimelineNotifier.new,
);
