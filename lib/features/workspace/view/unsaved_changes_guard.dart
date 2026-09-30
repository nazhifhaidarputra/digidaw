import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/services/project_file_actions.dart';
import 'package:karbeat/src/rust/api/mitigation.dart' as mitigation_api;
import 'package:karbeat/src/rust/api/serialization.dart' as serialization_api;
import 'package:window_manager/window_manager.dart';

enum _UnsavedChangesChoice { save, discard, cancel }

/// Asks what to do with unsaved changes before the current project is closed
/// or replaced.
///
/// Returns `true` when the caller may continue: the project had no unsaved
/// changes, the user saved it, or the user chose to discard the changes.
Future<bool> confirmDiscardUnsavedChanges(
  BuildContext context,
  WidgetRef ref,
) async {
  final dawContext = ref.read(projectProvider.notifier).dawContext;
  final saved = attempt(
    () => serialization_api.isProjectSaved(ctx: dawContext),
  );
  if (saved case Ok<bool>(value: true)) return true;
  if (saved case Error<bool>(error: final error)) {
    AppLogger.warn('Could not read the project save status: $error');
  }
  if (!context.mounted) return false;

  final projectName = projectDisplayName(
    ref.read(projectProvider).value?.currentFilePath,
  );
  final choice = await showDialog<_UnsavedChangesChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _UnsavedChangesDialog(projectName: projectName),
  );

  return switch (choice) {
    _UnsavedChangesChoice.save => saveCurrentProject(ref),
    _UnsavedChangesChoice.discard => true,
    _UnsavedChangesChoice.cancel || null => false,
  };
}

class _UnsavedChangesDialog extends StatelessWidget {
  const _UnsavedChangesDialog({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('unsaved-changes-dialog'),
      title: const Text('Unsaved changes'),
      content: Text(
        'Save the changes to "$projectName" before closing it? '
        'Unsaved changes will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_UnsavedChangesChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_UnsavedChangesChoice.discard),
          child: const Text("Don't save"),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_UnsavedChangesChoice.save),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Intercepts the desktop window close button while mounted so unsaved
/// changes are confirmed first, then ends the session cleanly before the
/// window closes.
///
/// Mobile apps have no close button and may be killed in the background, so
/// there the session is suspended while backgrounded instead; the auto saved
/// recovery copy is kept.
class UnsavedChangesGuard extends ConsumerStatefulWidget {
  const UnsavedChangesGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UnsavedChangesGuard> createState() =>
      _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends ConsumerState<UnsavedChangesGuard>
    with WindowListener, WidgetsBindingObserver {
  static final bool _isDesktop =
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) {
      WidgetsBinding.instance.addObserver(this);
      return;
    }
    windowManager.addListener(this);
    // Only intercept closing while this guard can answer it; loading and
    // error screens keep the default close behavior.
    unawaited(_setPreventClose(true));
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      unawaited(_setPreventClose(false));
    } else {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final suspended = switch (state) {
      AppLifecycleState.paused => true,
      AppLifecycleState.resumed => false,
      _ => null,
    };
    if (suspended == null) return;
    unawaited(_setSessionSuspended(suspended));
  }

  Future<void> _setSessionSuspended(bool suspended) async {
    final dawContext = ref.read(projectProvider.notifier).dawContext;
    final updated = await attemptAsync(
      () => mitigation_api.setSessionSuspended(
        ctx: dawContext,
        suspended: suspended,
      ),
    );
    if (updated case Error<void>(error: final error)) {
      AppLogger.warn('Could not update the session marker: $error');
    }
  }

  static Future<void> _setPreventClose(bool prevent) async {
    final updated = await attemptAsync(
      () => windowManager.setPreventClose(prevent),
    );
    if (updated case Error<void>(error: final error)) {
      AppLogger.warn('Could not update window close handling: $error');
    }
  }

  @override
  void onWindowClose() {
    unawaited(_closeWindow());
  }

  Future<void> _closeWindow() async {
    if (_isClosing) return;
    _isClosing = true;

    final proceed = await confirmDiscardUnsavedChanges(context, ref);
    if (!proceed || !mounted) {
      _isClosing = false;
      return;
    }

    final dawContext = ref.read(projectProvider.notifier).dawContext;
    final shutdown = await attemptAsync(
      () => mitigation_api.markCleanShutdown(ctx: dawContext),
    );
    if (shutdown case Error<void>(error: final error)) {
      AppLogger.warn('Could not record a clean shutdown: $error');
    }
    if (Platform.isLinux) {
      // Destroying the GTK window under a running engine segfaults once the
      // engine's pending task timers fire; the engine's own exit path quits
      // the application in order instead.
      await WidgetsBinding.instance.exitApplication(AppExitType.required);
    } else {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
