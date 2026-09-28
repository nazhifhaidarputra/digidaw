import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/project.dart' show encodeCoverArt;

/// Edge length of an encoded cover, a common ceiling for album art.
const coverOutputEdge = 1400;

/// Short-side ceiling when decoding a picked image, so a 2x zoom stays sharp
/// without holding a full-resolution photo in memory.
const _decodeShortSideLimit = coverOutputEdge * 2;

const coverImageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'];

/// Asks the user for an image and decodes it for cropping.
///
/// Returns `Ok(null)` when the picker is cancelled. The caller owns the
/// returned image and must dispose it.
Future<Result<ui.Image?>> pickCoverSource() {
  return attemptAsync(() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose a cover image',
      type: FileType.custom,
      allowedExtensions: coverImageExtensions,
    );
    final path = picked?.files.single.path;
    if (path == null) return null;
    return decodeCoverSource(await File(path).readAsBytes());
  });
}

/// Decodes any image format Flutter supports, downscaling large photos.
Future<ui.Image> decodeCoverSource(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final shortSide = math.min(descriptor.width, descriptor.height);
  final scale = shortSide > _decodeShortSideLimit
      ? _decodeShortSideLimit / shortSide
      : 1.0;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

/// Scale that fits the image's short side to a square viewport, so the image
/// always covers the crop frame.
double coverBaseScale(Size imageSize, double viewportExtent) =>
    viewportExtent / math.min(imageSize.width, imageSize.height);

/// The square region of the image, in image pixels, visible through a crop
/// viewport of [viewportExtent] after the viewer's [transform].
Rect coverCropRect({
  required Size imageSize,
  required double viewportExtent,
  required Matrix4 transform,
}) {
  final baseScale = coverBaseScale(imageSize, viewportExtent);
  final visible = MatrixUtils.transformRect(
    Matrix4.inverted(transform),
    Rect.fromLTWH(0, 0, viewportExtent, viewportExtent),
  );
  final side = math.min(
    visible.width / baseScale,
    math.min(imageSize.width, imageSize.height),
  );
  return Rect.fromLTWH(
    (visible.left / baseScale).clamp(0.0, imageSize.width - side),
    (visible.top / baseScale).clamp(0.0, imageSize.height - side),
    side,
    side,
  );
}

/// Renders [crop] of [image] as a square and has the backend encode it as a
/// JPEG in the app cache. Returns the cover file path.
Future<Result<String>> encodeCoverCrop(ui.Image image, Rect crop) {
  return attemptAsync(() async {
    final edge = math
        .min(crop.width.round(), coverOutputEdge)
        .clamp(1, coverOutputEdge);
    final target = Rect.fromLTWH(0, 0, edge.toDouble(), edge.toDouble());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      // JPEG has no alpha, so transparent areas flatten onto black
      ..drawRect(target, ui.Paint()..color = const ui.Color(0xFF000000))
      ..drawImageRect(
        image,
        crop,
        target,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(edge, edge);
    picture.dispose();
    final pixels = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (pixels == null) {
      throw const FormatException('Cover crop could not be rendered');
    }
    return encodeCoverArt(size: edge, rgba: pixels.buffer.asUint8List());
  });
}
