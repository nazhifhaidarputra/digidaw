import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/app.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/images/flags/LICENSE');
    yield LicenseEntryWithLineBreaks(['flag-icons'], license);
  });

  bool isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (isDesktop) {
    // Initialize the window manager ONLY on desktop
    await windowManager.ensureInitialized();

    // Set the initial title
    await windowManager.setTitle('DigiDAW — Untitled');

    // Small enough to shrink the window to a phone held sideways (about
    // 640 x 360 logical pixels and up), so the mobile layout can be checked on
    // desktop. No aspect ratio lock: phones are much wider than 16:9.
    await windowManager.setMinimumSize(const Size(640, 360));
    await windowManager.maximize();
  } else {
    if (kIsWeb) {
      throw Exception("This app is not compatible with Web");
    }
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Makes the status bar see-through
        statusBarIconBrightness:
            Brightness.light, // Use 'dark' if your background is light
        systemNavigationBarColor:
            Colors.transparent, // Optional: for bottom bar
      ),
    );

    // This line tells the app to extend its layout behind system bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  runApp(
    const ProviderScope(
      observers: [NotificationProviderObserver()],
      child: KarbeatApp(),
    ),
  );
}
