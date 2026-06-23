import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Customize this with your logo or branding
            Icon(Icons.graphic_eq, size: 64, color: Colors.cyanAccent),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.cyanAccent),
            SizedBox(height: 16),
            Text(
              'Initializing Audio Engine...',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
