import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeRust();
  }

  Future<void> _initializeRust() async {
    try {
      // Initialize Rust asynchronously while the UI is already rendering
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
        home: ErrorInitScreen(err: _rustError!, stack: _rustStackTrace!),
      );
    }

    // 2. Show Loading Screen while Rust boots up
    if (!_isRustInitialized) {
      return MaterialApp(
        title: 'DigiDAW',
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        home: const LoadingScreen(),
      );
    }

    final projectState = ref.watch(projectProvider);
    
    return MaterialApp(
      title: 'DigiDAW',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: projectState.when(
        data: (_) => const MainScreen(),
        loading: () => const LoadingScreen(),
        error: (err, stack) => ErrorInitScreen(err: err, stack: stack),
      ),
    );
  }
}