import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';

part 'blocking_task_provider.freezed.dart';

/// Timeout presets, in seconds, for [BlockingTaskNotifier.run].
abstract final class BlockingTaskTimeout {
  /// Default limit for general user actions.
  static const double standard = 60;

  /// Explicitly keeps the UI blocked until the task settles.
  static const double unbounded = double.infinity;

  /// Finite timeouts beyond this (about 31 years) are treated as unbounded so
  /// they stay representable as a [Timer] duration.
  static const double _maximumFiniteSeconds = 1e9;
}

/// The task currently holding the UI block.
@freezed
abstract class BlockingTaskEvent with _$BlockingTaskEvent {
  const factory BlockingTaskEvent({
    required int id,
    required String label,

    /// `null` when the task was submitted with an unbounded timeout.
    Duration? timeout,
  }) = _BlockingTaskEvent;
}

@freezed
abstract class BlockingTaskState with _$BlockingTaskState {
  const BlockingTaskState._();

  const factory BlockingTaskState({
    BlockingTaskEvent? active,

    /// Submitted tasks waiting behind [active].
    @Default(0) int pendingCount,
  }) = _BlockingTaskState;

  bool get isBlocking => active != null;
}

/// The task did not settle within its timeout. It keeps running in the
/// background; its eventual outcome is logged.
class BlockingTaskTimeoutException implements Exception {
  const BlockingTaskTimeoutException(this.label, this.timeout);

  final String label;
  final Duration timeout;

  @override
  String toString() =>
      '"$label" did not finish within ${timeout.inSeconds} s and was '
      'released; it continues in the background.';
}

/// The mailbox was disposed before the task could start.
class BlockingTaskCancelledException implements Exception {
  const BlockingTaskCancelledException(this.label);

  final String label;

  @override
  String toString() => '"$label" was cancelled before it started.';
}

/// Global mailbox for asynchronous operations that must block the UI while
/// they run, such as saving or loading a project.
///
/// Opt in per call: most async work should not block the UI.
///
/// * Every submitted task is accepted: the mailbox is an unbounded FIFO and
///   tasks are never dropped or coalesced. Each [run] future always completes
///   with the task's result, a timeout error, or a cancellation error if the
///   provider is disposed before the task started.
/// * Tasks run one at a time. The overlay stays up until the mailbox is empty.
/// * A task that exceeds its timeout releases the UI and the mailbox. It keeps
///   running, and its late outcome is logged rather than discarded.
/// * Calling [run] from inside a running task executes the nested task inline
///   instead of queuing it behind its own caller, which would deadlock.
///
/// Acquire user input (file pickers, dialogs) before submitting: the UI cannot
/// be interacted with while a task runs.
class BlockingTaskNotifier extends Notifier<BlockingTaskState> {
  static final Object _zoneKey = Object();

  final ListQueue<_BlockingEnvelope> _mailbox = ListQueue();
  int _nextId = 0;
  bool _draining = false;
  bool _disposed = false;

  @override
  BlockingTaskState build() {
    ref.onDispose(() {
      _disposed = true;
      while (_mailbox.isNotEmpty) {
        _mailbox.removeFirst().cancel();
      }
    });
    return const BlockingTaskState();
  }

  /// Blocks the UI with [label] until [task] settles or [timeoutSeconds]
  /// elapses.
  ///
  /// [timeoutSeconds] defaults to [BlockingTaskTimeout.standard]; pass
  /// [BlockingTaskTimeout.unbounded] (`double.infinity`) for no timeout.
  /// Errors thrown by [task] are logged, notified once, and returned as
  /// [Error]; errors it returns as [Result] are passed through untouched.
  Future<Result<T>> run<T>({
    required String label,
    required Future<Result<T>> Function() task,
    double timeoutSeconds = BlockingTaskTimeout.standard,
  }) {
    final timeout = _timeoutFrom(timeoutSeconds);
    if (timeout case Error<Duration?>(error: final error)) {
      AppLogger.error('Rejected blocking task "$label"', error: error);
      return Future.value(Result.error(error));
    }

    if (identical(Zone.current[_zoneKey], this)) {
      return _execute(label, task, timeout.ok());
    }
    if (_disposed) {
      return Future.value(Result.error(BlockingTaskCancelledException(label)));
    }

    final envelope = _BlockingEnvelope<T>(
      event: BlockingTaskEvent(
        id: _nextId++,
        label: label,
        timeout: timeout.ok(),
      ),
      task: task,
    );
    _mailbox.addLast(envelope);
    if (_draining) {
      state = state.copyWith(pendingCount: _mailbox.length);
    } else {
      unawaited(_drain());
    }
    return envelope.result;
  }

  Future<void> _drain() async {
    _draining = true;
    try {
      while (_mailbox.isNotEmpty && !_disposed) {
        final envelope = _mailbox.removeFirst();
        state = BlockingTaskState(
          active: envelope.event,
          pendingCount: _mailbox.length,
        );
        await envelope.process(this);
      }
    } finally {
      _draining = false;
      if (!_disposed) state = const BlockingTaskState();
    }
  }

  Future<Result<T>> _execute<T>(
    String label,
    Future<Result<T>> Function() task,
    Duration? timeout,
  ) {
    final settled = Completer<Result<T>>();
    Timer? timer;

    final operation = runZoned(
      () => attemptAsync(task),
      zoneValues: {_zoneKey: this},
    );
    unawaited(
      operation.then((outcome) {
        final result = switch (outcome) {
          Ok(value: final result) => result,
          Error(error: final error) => _reportThrown<T>(label, error),
        };
        if (settled.isCompleted) {
          _reportLateOutcome(label, result);
          return;
        }
        timer?.cancel();
        settled.complete(result);
      }),
    );

    if (timeout != null) {
      timer = Timer(timeout, () {
        if (settled.isCompleted) return;
        final error = BlockingTaskTimeoutException(label, timeout);
        AppLogger.warn(error.toString());
        if (!_disposed) {
          ref
              .read(notificationProvider.notifier)
              .warn(error.toString(), title: 'Operation timed out');
        }
        settled.complete(Result.error(error));
      });
    }
    return settled.future;
  }

  Result<T> _reportThrown<T>(String label, Exception error) {
    AppLogger.error('Blocking task "$label" failed', error: error);
    if (!_disposed) {
      ref
          .read(notificationProvider.notifier)
          .error(error, title: 'Operation failed');
    }
    return Result.error(error);
  }

  static void _reportLateOutcome<T>(String label, Result<T> result) {
    switch (result) {
      case Ok():
        AppLogger.info('Blocking task "$label" completed after its timeout');
      case Error(error: final error):
        AppLogger.error(
          'Blocking task "$label" failed after its timeout',
          error: error,
        );
    }
  }

  static Result<Duration?> _timeoutFrom(double seconds) {
    if (seconds.isNaN || seconds <= 0) {
      return Result.error(
        Exception('Blocking task timeout must be positive, got $seconds'),
      );
    }
    if (seconds > BlockingTaskTimeout._maximumFiniteSeconds) {
      return Result.ok(null);
    }
    return Result.ok(
      Duration(microseconds: (seconds * Duration.microsecondsPerSecond).ceil()),
    );
  }
}

final class _BlockingEnvelope<T> {
  _BlockingEnvelope({required this.event, required this.task});

  final BlockingTaskEvent event;
  final Future<Result<T>> Function() task;
  final Completer<Result<T>> _completer = Completer<Result<T>>();

  Future<Result<T>> get result => _completer.future;

  Future<void> process(BlockingTaskNotifier owner) async {
    _completer.complete(await owner._execute(event.label, task, event.timeout));
  }

  void cancel() {
    _completer.complete(
      Result.error(BlockingTaskCancelledException(event.label)),
    );
  }
}

final blockingTaskProvider =
    NotifierProvider<BlockingTaskNotifier, BlockingTaskState>(
      BlockingTaskNotifier.new,
    );
