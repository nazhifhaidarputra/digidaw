import 'package:flutter/material.dart';

class ErrorInitScreen extends StatelessWidget {
  final Object err;
  final StackTrace? stack;

  const ErrorInitScreen({super.key, required this.err, this.stack});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Fatal Error Initializing DAW',
                style: TextStyle(color: colors.onSurface, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: TextStyle(color: colors.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
