import 'package:flutter/material.dart';

class ZoomIntent extends Intent {
  final double scale;
  final Offset focalPoint;

  const ZoomIntent({
    required this.scale,
    required this.focalPoint,
  });
}