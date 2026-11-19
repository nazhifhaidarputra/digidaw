import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';

/// Opens the audio picker and imports the chosen file into the source list.
///
/// Shared by the Source view's add button and the Ctrl+I shortcut so both
/// paths use the same blocking task, error reporting, and cache refresh.
Future<void> importAudioSource(BuildContext context, WidgetRef ref) async {
  final path = await _pickAudioFile(ref);
  if (path == null || !context.mounted) return;

  final projectNotifier = ref.read(projectProvider.notifier);
  final importResult = await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: tr('source-loading-audio'),
        task: () => projectNotifier.loadAudioSource(path),
      );

  if (context.mounted && importResult.isOk()) {
    ref.invalidate(audioSourcesProvider);
  }
}

/// Opens the audio picker and swaps the audio of source [sourceId] for the
/// chosen file. Clips that play the source keep their place.
Future<void> replaceAudioSourceWithPicker(
  BuildContext context,
  WidgetRef ref,
  int sourceId,
) async {
  final path = await _pickAudioFile(ref);
  if (path == null || !context.mounted) return;

  final projectNotifier = ref.read(projectProvider.notifier);
  final result = await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: tr('source-loading-audio'),
        task: () => projectNotifier.replaceAudioSource(sourceId, path),
      );
  if (!context.mounted || result.isErr()) return;
  ref
    ..invalidate(audioSourcesProvider)
    ..invalidate(audioPropertiesProvider(sourceId))
    ..invalidate(audioWaveformHandleProvider(sourceId))
    ..invalidate(trackWaveformProvider);
  await ref.read(trackListStateProvider.notifier).syncTracks();
}

/// The path of an audio file the user picks, or `null` when they cancel or
/// the picker fails, which is reported.
Future<String?> _pickAudioFile(WidgetRef ref) async {
  try {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    return result?.files.single.path;
  } catch (error, stackTrace) {
    AppLogger.error('Could not select an audio file: $error');
    ref
        .read(notificationProvider.notifier)
        .error(
          error,
          title: tr('source-could-not-select-audio'),
          stackTrace: stackTrace,
        );
    return null;
  }
}
