import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/setting/services/cover_art_service.dart';

void main() {
  const wide = Size(200, 100);

  test('a centered viewer crops the middle square', () {
    // Short side fits the 100 px frame, so the 200 px width overflows by 100
    final rect = coverCropRect(
      imageSize: wide,
      viewportExtent: 100,
      transform: Matrix4.translationValues(-50, 0, 0),
    );
    expect(rect, const Rect.fromLTWH(50, 0, 100, 100));
  });

  test('zooming in shrinks the crop around the visible area', () {
    final transform = Matrix4.identity()
      ..translateByDouble(-150, -50, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);
    final rect = coverCropRect(
      imageSize: wide,
      viewportExtent: 100,
      transform: transform,
    );
    expect(rect, const Rect.fromLTWH(75, 25, 50, 50));
  });

  test('crops map viewport pixels back to full-resolution image pixels', () {
    // A 2000x1000 photo shown in a 100 px frame is scaled by 1/10
    final rect = coverCropRect(
      imageSize: const Size(2000, 1000),
      viewportExtent: 100,
      transform: Matrix4.identity(),
    );
    expect(rect, const Rect.fromLTWH(0, 0, 1000, 1000));
  });
}
