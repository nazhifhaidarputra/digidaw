import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:karbeat/features/setting/services/cover_art_service.dart';

/// Lets the user pan and zoom an image inside a square frame.
///
/// Pops with the chosen square region in image pixels, or `null` when
/// cancelled. The image starts centered, filling the frame.
class CoverCropDialog extends StatefulWidget {
  const CoverCropDialog({super.key, required this.image});

  final ui.Image image;

  static Future<Rect?> show(BuildContext context, ui.Image image) {
    return showDialog<Rect>(
      context: context,
      builder: (_) => CoverCropDialog(image: image),
    );
  }

  @override
  State<CoverCropDialog> createState() => _CoverCropDialogState();
}

class _CoverCropDialogState extends State<CoverCropDialog> {
  static const _viewportExtent = 360.0;

  late final Size _imageSize;
  late final Size _childSize;
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _imageSize = Size(
      widget.image.width.toDouble(),
      widget.image.height.toDouble(),
    );
    _childSize = _imageSize * coverBaseScale(_imageSize, _viewportExtent);
    _controller = TransformationController(
      Matrix4.translationValues(
        -(_childSize.width - _viewportExtent) / 2,
        -(_childSize.height - _viewportExtent) / 2,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(
      coverCropRect(
        imageSize: _imageSize,
        viewportExtent: _viewportExtent,
        transform: _controller.value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Crop cover'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: _viewportExtent,
            child: ClipRect(
              child: Stack(
                children: [
                  // Zero margin keeps the image covering the whole frame
                  InteractiveViewer(
                    key: const ValueKey('cover-crop-viewer'),
                    transformationController: _controller,
                    constrained: false,
                    boundaryMargin: EdgeInsets.zero,
                    minScale: 1,
                    maxScale: 8,
                    child: SizedBox.fromSize(
                      size: _childSize,
                      child: RawImage(image: widget.image, fit: BoxFit.fill),
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      size: const Size.square(_viewportExtent),
                      painter: _ThirdsGridPainter(
                        colors.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Drag to move, scroll or pinch to zoom',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('cover-crop-confirm'),
          onPressed: _confirm,
          child: const Text('Use image'),
        ),
      ],
    );
  }
}

/// Rule-of-thirds guides over the crop frame
class _ThirdsGridPainter extends CustomPainter {
  const _ThirdsGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final fraction in const [1 / 3, 2 / 3]) {
      final x = size.width * fraction;
      final y = size.height * fraction;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), paint)
        ..drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(Offset.zero & size, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_ThirdsGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
