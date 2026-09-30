import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/app/providers/crash_recovery_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/app_theme.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/text_input_shortcut_manager.dart';
import 'package:karbeat/core/services/crash_report_service.dart';
import 'package:karbeat/core/services/rust_log_bridge.dart';
import 'package:karbeat/core/services/tempo_model_installer.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/core/widgets/blocking_task_overlay.dart';
import 'package:karbeat/core/widgets/notification_overlay.dart';
import 'package:karbeat/features/misc/error_init_screen.dart';
import 'package:karbeat/features/misc/loading_screen.dart';
import 'package:karbeat/features/plugins/services/audio_plugins_service.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
import 'package:karbeat/features/setting/services/audio_settings_provider.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/services/host_devices_settings_provider.dart';
import 'package:karbeat/features/setting/services/log_provider.dart';
import 'package:karbeat/features/setting/services/plugin_settings_provider.dart';
import 'package:karbeat/features/workspace/view/main_screen.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/frb_generated.dart';

class KarbeatApp extends ConsumerStatefulWidget {
  const KarbeatApp({super.key});

  @override
  ConsumerState<KarbeatApp> createState() => _KarbeatAppState();
}

class _KarbeatAppState extends ConsumerState<KarbeatApp> {
  bool _isRustInitialized = false;
  Object? _rustError;
  StackTrace? _rustStackTrace;
  DawContext? _dawContextLifetimeAnchor;
  late final Future<void> _initialization;
  late final bool Function(Object, StackTrace) _uncaughtErrorHandler;
  bool Function(Object, StackTrace)? _previousUncaughtErrorHandler;
  late final FlutterExceptionHandler _frameworkErrorHandler;
  FlutterExceptionHandler? _previousFrameworkErrorHandler;
  final TextInputAwareShortcutManager _shortcutManager =
      TextInputAwareShortcutManager();

  @override
  void initState() {
    super.initState();
    _previousUncaughtErrorHandler = PlatformDispatcher.instance.onError;
    _uncaughtErrorHandler = (error, stackTrace) {
      AppLogger.error(
        'Unhandled asynchronous application error',
        error: error,
        stackTrace: stackTrace,
      );
      final recorded = CrashReportService.recordUncaughtError(
        error,
        stackTrace,
      );
      if (recorded case Error<void>(error: final recordError)) {
        AppLogger.warn('Crash report was not recorded: $recordError');
      }
      if (mounted) {
        ref
            .read(notificationProvider.notifier)
            .error(error, stackTrace: stackTrace);
      }
      _previousUncaughtErrorHandler?.call(error, stackTrace);
      return true;
    };
    PlatformDispatcher.instance.onError = _uncaughtErrorHandler;

    _previousFrameworkErrorHandler = FlutterError.onError;
    _frameworkErrorHandler = (details) {
      final recorded = CrashReportService.recordFrameworkError(details);
      if (recorded case Error<void>(error: final recordError)) {
        AppLogger.warn('Crash report was not recorded: $recordError');
      }
      _previousFrameworkErrorHandler?.call(details);
    };
    FlutterError.onError = _frameworkErrorHandler;
    _initialization = _initializeApplication();
  }

  @override
  void dispose() {
    if (identical(PlatformDispatcher.instance.onError, _uncaughtErrorHandler)) {
      PlatformDispatcher.instance.onError = _previousUncaughtErrorHandler;
    }
    if (identical(FlutterError.onError, _frameworkErrorHandler)) {
      FlutterError.onError = _previousFrameworkErrorHandler;
    }
    final dawContext = _dawContextLifetimeAnchor;
    if (dawContext != null) {
      unawaited(_retainDawContextUntilInitializationCompletes(dawContext));
    }
    _shortcutManager.dispose();
    super.dispose();
  }

  Future<void> _retainDawContextUntilInitializationCompletes(
    DawContext dawContext,
  ) async {
    await _initialization;
    // Reading the opaque handle after awaiting keeps its Rust Arc reachable
    // until all startup preference work has settled.
    if (dawContext.isDisposed) {
      AppLogger.warn(
        'DawContext was disposed before application startup settled',
      );
    }
  }

  Future<void> _initializeApplication() async {
    try {
      await ref.read(appearanceSettingsProvider.notifier).initialize();
      await ref.read(shortcutManagerProvider.notifier).initialize();
      if (!mounted) return;
      await Future.wait([
        RustLib.init(),
        Future.delayed(const Duration(seconds: 5)),
      ]);

      if (!mounted) return;
      // Subscribe before any project work so every job's events are seen.
      ref.read(backgroundJobsProvider);
      unawaited(
        TempoModelInstaller.install().then((result) {
          if (result case Error<void>(:final error)) {
            AppLogger.warn('Tempo detection is unavailable: $error');
          }
        }),
      );
      final rustLogs = ref.read(rustLogBridgeProvider).start();
      if (rustLogs.isErr()) {
        AppLogger.warn(
          'Rust logs are unavailable in the log viewer: ${rustLogs.err()}',
        );
      }

      // ProjectNotifier creates DawContext before its first asynchronous FFI
      // call. Awaiting the provider makes that context fully usable before any
      // plugin-backed preferences are initialized.
      await ref.read(projectProvider.future);
      if (!mounted) return;

      final dawContext = ref.read(projectProvider.notifier).dawContext;
      _dawContextLifetimeAnchor = dawContext;
      // Crash reporting starts before the remaining startup work so failures
      // there are captured. A failure is reported but does not block startup.
      await ref.read(crashRecoveryProvider.notifier).initialize(dawContext);
      if (!mounted) return;
      await ref.read(pluginSettingsProvider.notifier).initialize();
      if (!mounted) return;
      await ref.read(audioPluginProvider.future);
      if (!mounted) return;
      await ref.read(generalSettingsProvider.notifier).initialize(dawContext);
      if (!mounted) return;
      await ref
          .read(hostDevicesSettingsProvider.notifier)
          .initialize(dawContext);
      if (!mounted) return;
      await ref.read(audioSettingsProvider.notifier).initialize(dawContext);
      if (!mounted) return;
      await ref.read(logProvider.notifier).initialize();
      if (!mounted) return;
      await ref
          .read(workspaceStateProvider.notifier)
          .initializeSampleBrowser(dawContext);
      if (!mounted) return;

      setState(() {
        _isRustInitialized = true;
      });
    } catch (e, stackTrace) {
      if (mounted) {
        ref
            .read(notificationProvider.notifier)
            .error(e, stackTrace: stackTrace);
        setState(() {
          _rustError = e;
          _rustStackTrace = stackTrace;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(
      appearanceSettingsProvider.select(
        (state) => (
          themeMode: state.themeMode,
          palette: state.colorPalette,
          fontFamily: state.customFontFamily,
        ),
      ),
    );
    final lightTheme = AppTheme.light(
      appearance.palette,
      fontFamily: appearance.fontFamily,
    );
    final darkTheme = AppTheme.dark(
      appearance.palette,
      fontFamily: appearance.fontFamily,
    );
    final themeMode = AppTheme.themeMode(appearance.themeMode);

    // Handle Rust Initialization Errors
    if (_rustError != null) {
      return MaterialApp(
        title: 'DigiDAW',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        builder: _notificationBuilder,
        home: ErrorInitScreen(err: _rustError!, stack: _rustStackTrace!),
      );
    }

    // Show Loading Screen while Rust boots up
    if (!_isRustInitialized) {
      return MaterialApp(
        title: 'DigiDAW',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        builder: _notificationBuilder,
        home: const LoadingScreen(),
      );
    }

    final projectState = ref.watch(projectProvider);
    // The setter only notifies when the map actually changes
    _shortcutManager.shortcuts = ref.watch(activeShortcutMapProvider);

    return Shortcuts.manager(
      manager: _shortcutManager,
      child: MaterialApp(
        title: 'DigiDAW',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        builder: _notificationBuilder,
        home: projectState.when(
          data: (_) => const MainScreen(),
          loading: () => const LoadingScreen(),
          error: (err, stack) => ErrorInitScreen(err: err, stack: stack),
        ),
      ),
    );
  }

  Widget _notificationBuilder(BuildContext context, Widget? child) {
    // Notifications stay above the blocking barrier so timeouts and failures
    // remain visible while the UI is blocked.
    return NotificationOverlay(
      child: BlockingTaskOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
