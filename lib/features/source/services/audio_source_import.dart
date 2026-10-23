import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/blocking_task_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';

/// Opens the audio picker and imports the chosen file into the source list.
///
/// Shared by the Source view's add button and the Ctrl+I shortcut so both
/// paths use the same blocking task, error reporting, and cache refresh.
Future<void> importAudioSource(BuildContext context, WidgetRef ref) async {
  final notifications = ref.read(notificationProvider.notifier);
  FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(type: FileType.audio);
  } catch (error, stackTrace) {
    AppLogger.error('Could not select an audio file: $error');
    notifications.error(
      error,
      title: 'Could not select audio',
      stackTrace: stackTrace,
    );
    return;
  }

  final path = result?.files.single.path;
  if (path == null || !context.mounted) return;

  final projectNotifier = ref.read(projectProvider.notifier);
  final importResult = await ref
      .read(blockingTaskProvider.notifier)
      .run(
        label: 'Loading audio...',
        task: () => projectNotifier.loadAudioSource(path),
      );

  if (context.mounted && importResult.isOk()) {
    ref.invalidate(audioSourcesProvider);
  }
}
