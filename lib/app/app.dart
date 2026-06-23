import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/misc/error_init_screen.dart';
import 'package:karbeat/features/misc/loading_screen.dart';
import 'package:karbeat/features/workspace/view/main_screen.dart';

class KarbeatApp extends ConsumerWidget {
  const KarbeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
