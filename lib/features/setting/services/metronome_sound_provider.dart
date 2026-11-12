import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/settings.dart' as settings_api;

/// Picks, stores and applies the custom metronome sound.
class MetronomeSoundService {
  Future<Result<String?>> loadPath() {
    return attemptAsync(
      () async => (await settings_api.loadAudioPreferences()).metronomeSound,
    );
  }

  Future<Result<void>> savePath(String? path) {
    return attemptAsync(() => settings_api.saveMetronomeSound(path: path));
  }

  Future<Result<String?>> pickSound() {
    return attemptAsync(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: tr('settings-audio-metronome-dialog'),
        type: FileType.audio,
      );
      return result?.files.single.path;
    });
  }

  Future<Result<bool>> fileExists(String path) {
    return attemptAsync(() => File(path).exists());
  }

  /// Makes the engine play the file at [path], or its built-in click when
  /// [path] is null.
  Future<Result<void>> apply(DawContext context, String? path) {
    return attemptAsync(
      () => audio_api.setMetronomeSound(ctx: context, filePath: path),
    );
  }
}

final metronomeSoundServiceProvider = Provider<MetronomeSoundService>((ref) {
  return MetronomeSoundService();
});

/// Path of the custom metronome sound, or null while the built-in click is
/// used.
///
/// The engine plays the file as recorded on offbeats and an octave higher on
/// downbeats.
class MetronomeSoundNotifier extends Notifier<String?> {
  bool _initializationStarted = false;
  DawContext? _dawContext;

  @override
  String? build() => null;

  MetronomeSoundService get _service => ref.read(metronomeSoundServiceProvider);

  /// Restores the saved sound. A sound that can no longer be loaded falls back
  /// to the built-in click.
  Future<Result<void>> initialize(DawContext context) async {
    if (_initializationStarted) return Result.ok(null);
    _initializationStarted = true;
    _dawContext = context;

    final loaded = await _service.loadPath();
    if (loaded case Error<String?>(error: final error)) {
      _initializationStarted = false;
      return ref.notifyErrorResult(
        error,
        title: tr('settings-audio-metronome-setting-load-failed'),
      );
    }
    final path = loaded.ok();
    if (path == null) return Result.ok(null);

    final exists = await _service.fileExists(path);
    final applied = exists.isOk() && exists.ok()
        ? await _service.apply(context, path)
        : Result<void>.error(Exception('File not found'));
    if (applied.isErr()) {
      ref
          .read(notificationProvider.notifier)
          .warn(
            tr('settings-audio-metronome-unavailable-message'),
            title: tr('settings-audio-metronome-unavailable-title'),
          );
      return _service.savePath(null);
    }
    state = path;
    return Result.ok(null);
  }

  Future<Result<void>> chooseSound() async {
    final picked = await _service.pickSound();
    if (picked case Error<String?>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: tr('settings-audio-metronome-choose-failed'),
      );
    }
    final path = picked.ok();
    if (path == null) return Result.ok(null);
    return _applyAndSave(
      path,
      failureTitle: tr('settings-audio-metronome-load-failed'),
    );
  }

  Future<Result<void>> useDefaultSound() {
    return _applyAndSave(
      null,
      failureTitle: tr('settings-audio-metronome-restore-failed'),
    );
  }

  Future<Result<void>> _applyAndSave(
    String? path, {
    required String failureTitle,
  }) async {
    final context = _dawContext;
    if (context == null) {
      return ref.notifyErrorResult(
        Exception('The audio engine is not ready'),
        title: failureTitle,
      );
    }
    final applied = await _service.apply(context, path);
    if (applied case Error<void>(error: final error)) {
      return ref.notifyErrorResult(error, title: failureTitle);
    }
    state = path;
    final saved = await _service.savePath(path);
    if (saved case Error<void>(error: final error)) {
      return ref.notifyErrorResult(
        error,
        title: tr('settings-audio-metronome-not-saved'),
      );
    }
    return Result.ok(null);
  }
}

final metronomeSoundProvider =
    NotifierProvider<MetronomeSoundNotifier, String?>(
      MetronomeSoundNotifier.new,
    );
