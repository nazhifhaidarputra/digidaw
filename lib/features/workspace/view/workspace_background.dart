import 'dart:io';

import 'package:flutter/material.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';

class WorkspaceBackground extends StatefulWidget {
  const WorkspaceBackground({
    required this.imagePath,
    required this.fit,
    required this.overlayOpacity,
    super.key,
  });

  final String? imagePath;
  final AppBackgroundFit fit;
  final double overlayOpacity;

  @override
  State<WorkspaceBackground> createState() => _WorkspaceBackgroundState();
}

class _WorkspaceBackgroundState extends State<WorkspaceBackground> {
  ImageProvider<Object>? _image;

  @override
  void initState() {
    super.initState();
    _updateImage();
  }

  @override
  void didUpdateWidget(WorkspaceBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _updateImage();
  }

  void _updateImage() {
    final path = widget.imagePath;
    _image = path == null ? null : FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: image == null
          ? const SizedBox.expand()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: image,
                  fit: _boxFit(widget.fit),
                  errorBuilder: (_, _, _) => ColoredBox(color: scheme.surface),
                ),
                ColoredBox(
                  color: Colors.black.withValues(alpha: widget.overlayOpacity),
                ),
              ],
            ),
    );
  }
}

BoxFit _boxFit(AppBackgroundFit fit) => switch (fit) {
  AppBackgroundFit.cover => BoxFit.cover,
  AppBackgroundFit.contain => BoxFit.contain,
  AppBackgroundFit.fill => BoxFit.fill,
};
