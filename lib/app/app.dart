import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/widgets/notification_overlay.dart';
import 'package:karbeat/features/misc/error_init_screen.dart';
import 'package:karbeat/features/misc/loading_screen.dart';
import 'package:karbeat/features/workspace/view/main_screen.dart';
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
  late final bool Function(Object, StackTrace) _uncaughtErrorHandler;
  bool Function(Object, StackTrace)? _previousUncaughtErrorHandler;

  @override
  void initState() {
    super.initState();
    _previousUncaughtErrorHandler = PlatformDispatcher.instance.onError;
    _uncaughtErrorHandler = (error, stackTrace) {
      ref
          .read(notificationProvider.notifier)
          .error(error, stackTrace: stackTrace);
      return _previousUncaughtErrorHandler?.call(error, stackTrace) ?? false;
    };
    PlatformDispatcher.instance.onError = _uncaughtErrorHandler;
    _initializeRust();
  }

  @override
  void dispose() {
    if (identical(PlatformDispatcher.instance.onError, _uncaughtErrorHandler)) {
      PlatformDispatcher.instance.onError = _previousUncaughtErrorHandler;
    }
    super.dispose();
  }

  Future<void> _initializeRust() async {
    try {
      await Future.wait([
        RustLib.init(),
        Future.delayed(const Duration(seconds: 5)),
      ]);

      if (mounted) {
        setState(() {
          _isRustInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      ref.read(notificationProvider.notifier).error(e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _rustError = e;
          _rustStackTrace = stackTrace;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle Rust Initialization Errors
    if (_rustError != null) {
      return MaterialApp(
        title: 'DigiDAW',
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        builder: _notificationBuilder,
        home: ErrorInitScreen(err: _rustError!, stack: _rustStackTrace!),
      );
    }

    // Show Loading Screen while Rust boots up
    if (!_isRustInitialized) {
      return MaterialApp(
        title: 'DigiDAW',
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        builder: _notificationBuilder,
        home: const LoadingScreen(),
      );
    }

    final projectState = ref.watch(projectProvider);
    final activeShortcuts = ref.watch(shortcutManagerProvider);

    return Shortcuts(
      shortcuts: activeShortcuts,
      child: MaterialApp(
        title: 'DigiDAW',
        theme: ThemeData.dark(),
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
    return NotificationOverlay(child: child ?? const SizedBox.shrink());
  }
}
