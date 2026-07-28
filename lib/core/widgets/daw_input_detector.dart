import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listens to input events and dispatches them to the appropriate handlers.
class DawInputDetector extends StatelessWidget {
  final Widget child;
  final void Function(double scrollDelta, Offset localPosition)? onCtrlScroll;
  final void Function(double scrollDelta, Offset localPosition)? onAltScroll;
  final void Function(ScaleUpdateDetails details)? onPinchZoom;

  const DawInputDetector({
    super.key,
    required this.child,
    this.onCtrlScroll,
    this.onAltScroll,
    this.onPinchZoom,
  });

  bool get _isCtrlPressed =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);

  bool get _isAltPressed =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.altLeft) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.altRight);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          if (_isCtrlPressed && onCtrlScroll != null) {
            onCtrlScroll!(event.scrollDelta.dy, event.localPosition);
          } else if (_isAltPressed && onAltScroll != null) {
            onAltScroll!(event.scrollDelta.dy, event.localPosition);
          }
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleUpdate: onPinchZoom,
        child: child,
      ),
    );
  }
}