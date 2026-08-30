import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';

class WorkspaceBackground extends ConsumerWidget {
  const WorkspaceBackground({
    required this.fit,
    required this.overlayOpacity,
    super.key,
  });

  final AppBackgroundFit fit;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(workspaceBackgroundImageProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: imageAsync.when(
        loading: () => const SizedBox.expand(),
        error: (_, _) => const SizedBox.expand(),
        data: (image) => image == null
            ? const SizedBox.expand()
            : Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(image: image, fit: _boxFit(fit)),
                  ColoredBox(
                    color: Colors.black.withValues(alpha: overlayOpacity),
                  ),
                ],
              ),
      ),
    );
  }
}

BoxFit _boxFit(AppBackgroundFit fit) => switch (fit) {
  AppBackgroundFit.cover => BoxFit.cover,
  AppBackgroundFit.contain => BoxFit.contain,
  AppBackgroundFit.fill => BoxFit.fill,
};
