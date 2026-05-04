import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app.dart';
import 'package:karbeat/src/rust/frb_generated.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (isDesktop) {
    // Initialize the window manager ONLY on desktop
    await windowManager.ensureInitialized();
    
    // Set the initial title
    await windowManager.setTitle('Karbeat — Untitled');
  }
  

  await RustLib.init();

  runApp(const ProviderScope(child: KarbeatApp()));
}
