import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Creates a continuous looping animation for the chibi
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Creates a smooth easing curve for a "breathing/floating" effect
    _animation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surface, colors.surfaceContainerHigh],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Animated Chibi Sticker
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  // Slight vertical bobbing motion
                  offset: Offset(0, 15 * (1 - _animation.value)),
                  child: Transform.scale(scale: _animation.value, child: child),
                );
              },
              child: Image.asset(
                'assets/images/splash_screen_icon.png',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
                // Safe fallback just in case the asset isn't linked in pubspec.yaml yet
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.graphic_eq, size: 100, color: colors.primary),
              ),
            ),

            const SizedBox(height: 48),

            // Game-style Loading Bar
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    color: colors.primary,
                    backgroundColor: colors.surfaceContainerHighest,
                    minHeight: 4,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing Audio Engine...',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom branding text
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'DigiDAW',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
