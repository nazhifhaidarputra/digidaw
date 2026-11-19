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

  /// Renders the file at [path] into the downbeat and offbeat clicks, saves
  /// them to disk and makes the engine play them.
  Future<Result<void>> importSound(DawContext context, String path) {
    return attemptAsync(
      () => audio_api.importMetronomeSound(ctx: context, filePath: path),
    );
  }

  /// Makes the engine play the clicks saved by [importSound].
  Future<Result<void>> restoreSound(DawContext context) {
    return attemptAsync(() => audio_api.loadMetronomeSound(ctx: context));
  }

  /// Makes the engine play its built-in click.
  Future<Result<void>> useDefaultSound(DawContext context) {
    return attemptAsync(() => audio_api.useDefaultMetronomeSound(ctx: context));
  }
}

final metronomeSoundServiceProvider = Provider<MetronomeSoundService>((ref) {
  return MetronomeSoundService();
});

/// Path of the file the custom metronome sound was made from, or null while
/// the built-in click is used.
///
/// Choosing a file renders it into an offbeat click as recorded and a downbeat
/// click an octave higher with the same length. Both clicks are saved to disk,
/// so the chosen file is no longer needed afterwards.
class MetronomeSoundNotifier extends Notifier<String?> {
  bool _initializationStarted = false;
  DawContext? _dawContext;

  @override
  String? build() => null;

  MetronomeSoundService get _service => ref.read(metronomeSoundServiceProvider);

  /// Restores the saved clicks. Clicks that can no longer be loaded fall back
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

    final restored = await _service.restoreSound(context);
    if (restored.isErr()) {
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
      apply: (context) => _service.importSound(context, path),
      failureTitle: tr('settings-audio-metronome-load-failed'),
    );
  }

  Future<Result<void>> useDefaultSound() {
    return _applyAndSave(
      null,
      apply: _service.useDefaultSound,
      failureTitle: tr('settings-audio-metronome-restore-failed'),
    );
  }

  Future<Result<void>> _applyAndSave(
    String? path, {
    required Future<Result<void>> Function(DawContext context) apply,
    required String failureTitle,
  }) async {
    final context = _dawContext;
    if (context == null) {
      return ref.notifyErrorResult(
        Exception('The audio engine is not ready'),
        title: failureTitle,
      );
    }
    final applied = await apply(context);
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
