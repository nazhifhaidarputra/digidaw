import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/jobs.dart';

part 'background_jobs_provider.freezed.dart';

/// Latest known state of one unfinished background job.
@freezed
abstract class BackgroundJob with _$BackgroundJob {
  const factory BackgroundJob({
    required int id,
    required UiJobKind kind,
    required UiJobTarget target,
    required UiJobState state,
  }) = _BackgroundJob;
}

@freezed
abstract class BackgroundJobsState with _$BackgroundJobsState {
  const BackgroundJobsState._();

  const factory BackgroundJobsState({
    /// Unfinished jobs by id. Finished jobs are removed.
    @Default(IMapConst<int, BackgroundJob>({})) IMap<int, BackgroundJob> active,

    /// Bumped each time a job that changed an audio source completes, keyed by
    /// source ID. Watch an entry to refetch that source.
    @Default(IMapConst<int, int>({})) IMap<int, int> sourceRevisions,
  }) = _BackgroundJobsState;

  bool get isBusy => active.isNotEmpty;

  /// Whether a job of [kind] is unfinished for audio source [sourceId].
  bool isRunningFor(int sourceId, UiJobKind kind) => active.values.any(
    (job) =>
        job.kind == kind &&
        switch (job.target) {
          UiJobTarget_Source(sourceId: final target) => target == sourceId,
          _ => false,
        },
  );
}

/// The job was stopped before it finished.
class BackgroundJobCancelledException implements Exception {
  const BackgroundJobCancelledException(this.id);

  final int id;

  @override
  String toString() => 'Background job $id was cancelled.';
}

/// The job finished with an error.
class BackgroundJobFailedException implements Exception {
  const BackgroundJobFailedException(this.id, this.message);

  final int id;
  final String message;

  @override
  String toString() => message;
}

/// Mirrors the Rust job manager: tracks unfinished jobs and lets callers await one.
///
/// Subscribes to the job event stream once for the app lifetime, so jobs keep reporting
/// after the widget that started them is gone.
class BackgroundJobsNotifier extends Notifier<BackgroundJobsState> {
  /// Jobs whose failure nobody awaits; the notifier reports them to the user.
  static const _unattendedKinds = {
    UiJobKind.tempoDetection,
    UiJobKind.waveformRender,
  };

  final Map<int, Completer<Result<void>>> _waiters = {};

  /// Terminal outcomes that arrived before anyone called [awaitJob], bounded in size.
  final Map<int, Result<void>> _settled = {};
  static const _maxSettled = 64;

  @override
  BackgroundJobsState build() {
    final subscription = subscribeJobEvents().listen(
      _onEvent,
      onError: (Object error, StackTrace stackTrace) => AppLogger.error(
        'Background job stream failed',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    ref.onDispose(subscription.cancel);
    return const BackgroundJobsState();
  }

  void _onEvent(UiJobEvent event) {
    final outcome = switch (event.state) {
      UiJobState_Completed() => const Ok<void>(null),
      UiJobState_Failed(:final message) => Error<void>(
        BackgroundJobFailedException(event.id, message),
      ),
      UiJobState_Cancelled() => Error<void>(
        BackgroundJobCancelledException(event.id),
      ),
      _ => null,
    };

    if (outcome == null) {
      state = state.copyWith(
        active: state.active.add(
          event.id,
          BackgroundJob(
            id: event.id,
            kind: event.kind,
            target: event.target,
            state: event.state,
          ),
        ),
      );
      return;
    }

    final completedSource = switch ((event.state, event.target)) {
      (UiJobState_Completed(), UiJobTarget_Source(:final sourceId)) => sourceId,
      _ => null,
    };
    state = state.copyWith(
      active: state.active.remove(event.id),
      sourceRevisions: completedSource == null
          ? state.sourceRevisions
          : state.sourceRevisions.update(
              completedSource,
              (revision) => revision + 1,
              ifAbsent: () => 1,
            ),
    );
    if (event.state case UiJobState_Failed(
      :final message,
    ) when _unattendedKinds.contains(event.kind)) {
      ref.notifyError(message, title: 'Background task failed');
    }

    final waiter = _waiters.remove(event.id);
    if (waiter != null) {
      waiter.complete(outcome);
      return;
    }
    _settled[event.id] = outcome;
    if (_settled.length > _maxSettled) {
      _settled.remove(_settled.keys.first);
    }
  }

  /// Completes when job [id] finishes, successfully or not.
  Future<Result<void>> awaitJob(int id) {
    final settled = _settled.remove(id);
    if (settled != null) return Future.value(settled);
    return _waiters.putIfAbsent(id, Completer<Result<void>>.new).future;
  }

  /// Asks job [id] to stop. Returns `false` when it already finished.
  Future<bool> cancel(int id) => cancelJob(id: id);
}

final backgroundJobsProvider =
    NotifierProvider<BackgroundJobsNotifier, BackgroundJobsState>(
      BackgroundJobsNotifier.new,
    );
