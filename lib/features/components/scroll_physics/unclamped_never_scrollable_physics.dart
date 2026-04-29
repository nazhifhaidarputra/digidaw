import 'package:flutter/material.dart';

/// Custom physics that prevents physical dragging but allows programmatic jumps 
/// to bypass layout boundaries. Essential for synchronous 1-frame zoom pivot updates.
class UnclampedNeverScrollableScrollPhysics extends NeverScrollableScrollPhysics {
  const UnclampedNeverScrollableScrollPhysics({super.parent});

  @override
  UnclampedNeverScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return UnclampedNeverScrollableScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Return 0.0 forces Flutter to allow out-of-bounds scrolling synchronously
    return 0.0; 
  }
}