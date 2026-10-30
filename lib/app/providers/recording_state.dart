import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/host_devices_settings_provider.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/recording.dart' as recording_api;

part 'recording_state.freezed.dart';

/// One armed track's take as the UI draws it.
@freezed
abstract class TrackTake with _$TrackTake {
  const factory TrackTake({
    /// Song playhead, in samples, the take starts at; `null` while it waits
    /// for playback.
    int? startSamples,

    /// Frames recorded so far.
    @Default(0) int frames,
    @Default(0) int sampleRate,

    /// Lowest and highest sample of every 256 frames, in pairs.
    @Default(IListConst<double>([])) IList<double> peaks,

    /// Whether the take is being written as a clip.
    @Default(false) bool isStopping,
  }) = _TrackTake;
}

/// Takes of the armed tracks, by track ID.
@freezed
abstract class RecordingState with _$RecordingState {
  const factory RecordingState({
    @Default(IMapConst<int, TrackTake>({})) IMap<int, TrackTake> takes,
  }) = _RecordingState;
}

/// What the engine recorded for each take, about 30 times a second.
final recordingProgressStreamProvider =
    StreamProvider<recording_api.UiRecordingProgress>((ref) async* {
      final ctx = ref.watch(projectProvider.notifier).dawContext;
      yield* recording_api.createRecordingStream(ctx: ctx);
    });

final recordingProvider = NotifierProvider<RecordingNotifier, RecordingState>(
  RecordingNotifier.new,
);

/// Arms tracks to record, follows their takes, and turns finished takes into
/// clips.
class RecordingNotifier extends Notifier<RecordingState> {
  DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  @override
  RecordingState build() {
    ref.listen(recordingProgressStreamProvider, (previous, next) {
      if (next case AsyncData(:final value)) _applyProgress(value);
    });
    return const RecordingState();
  }

  bool isArmed(int trackId) => state.takes.containsKey(trackId);

  /// Arms [trackId], or ends its take when it is armed.
  Future<Result<void>> toggleTrack(int trackId) =>
      isArmed(trackId) ? stopTrack(trackId) : startTrack(trackId);

  /// Arms [trackId]; it records once the song plays.
  Future<Result<void>> startTrack(int trackId) async {
    if (isArmed(trackId)) return Result.ok(null);
    final recording_api.UiStartedTake started;
    try {
      started = await recording_api.startTrackRecording(
        ctx: _ctx,
        trackId: trackId,
      );
    } catch (error, stackTrace) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not arm the track',
        stackTrace: stackTrace,
      );
    }
    state = state.copyWith(takes: state.takes.add(trackId, const TrackTake()));
    if (started.enabledInput) {
      await ref
          .read(hostDevicesSettingsProvider.notifier)
          .inputEnabledForRecording();
      ref
          .read(notificationProvider.notifier)
          .info(
            'Audio input was off, so it was turned on. Change the input device in Settings.',
            title: 'Audio input on',
          );
    }
    return Result.ok(null);
  }

  /// Arms the selected track, which must be an audio track.
  Future<Result<void>> recordSelectedTrack() {
    final trackId = ref.read(trackListStateProvider).selectedTrackId;
    final track = trackId == null
        ? null
        : ref.read(projectProvider).value?.tracks[trackId];
    if (trackId == null || track?.trackType != UiTrackType.audio) {
      ref
          .read(notificationProvider.notifier)
          .warn(
            'Select an audio track to record on.',
            title: 'Nothing to record',
          );
      return Future.value(Result.ok(null));
    }
    return startTrack(trackId);
  }

  /// Ends the take of [trackId] and places what it recorded as a clip.
  Future<Result<void>> stopTrack(int trackId) async {
    final take = state.takes[trackId];
    if (take == null || take.isStopping) return Result.ok(null);
    state = state.copyWith(
      takes: state.takes.add(trackId, take.copyWith(isStopping: true)),
    );
    try {
      final track = await recording_api.stopTrackRecording(
        ctx: _ctx,
        trackId: trackId,
      );
      if (track != null) {
        ref.read(projectProvider.notifier).upsertTrack(track.id, track);
      }
      return Result.ok(null);
    } catch (error, stackTrace) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not save the recording',
        stackTrace: stackTrace,
      );
    } finally {
      state = state.copyWith(takes: state.takes.remove(trackId));
    }
  }

  /// Ends every take at once and places what they recorded as clips.
  Future<Result<void>> stopAll() async {
    if (state.takes.isEmpty) return Result.ok(null);
    final stopping = state.takes.keys.toISet();
    state = state.copyWith(
      takes: state.takes.map(
        (trackId, take) => MapEntry(trackId, take.copyWith(isStopping: true)),
      ),
    );
    try {
      final tracks = await recording_api.stopAllRecordings(ctx: _ctx);
      ref.read(projectProvider.notifier).upsertTracksBulk({
        for (final track in tracks) track.id: track,
      });
      return Result.ok(null);
    } catch (error, stackTrace) {
      return ref.notifyErrorResult(
        error,
        title: 'Could not save the recordings',
        stackTrace: stackTrace,
      );
    } finally {
      state = state.copyWith(
        takes: state.takes.removeWhere(
          (trackId, _) => stopping.contains(trackId),
        ),
      );
    }
  }

  void _applyProgress(recording_api.UiRecordingProgress progress) {
    final take = state.takes[progress.trackId];
    if (take == null || take.isStopping) return;
    // Pairs already shown are skipped, so a repeated report adds nothing.
    final known = take.peaks.length ~/ 2;
    final skip = (known - progress.peakOffset).clamp(
      0,
      progress.peaks.length ~/ 2,
    );
    final updated = take.copyWith(
      startSamples: progress.startSamples,
      frames: progress.frames,
      sampleRate: progress.sampleRate,
      peaks: take.peaks.addAll(progress.peaks.skip(skip * 2)),
    );
    state = state.copyWith(takes: state.takes.add(progress.trackId, updated));
    // The engine ends a take when the song stops or is seeked.
    if (progress.ended) unawaited(stopTrack(progress.trackId));
  }
}
