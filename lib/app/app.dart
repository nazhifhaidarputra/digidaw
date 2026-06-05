import 'package:flutter/material.dart';
import 'package:karbeat/features/workspace/view/main_screen.dart';

class KarbeatApp extends StatelessWidget {
  const KarbeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiDAW',
      theme: ThemeData.dark(),
      home: const MainScreen(),
    );
  }
}
