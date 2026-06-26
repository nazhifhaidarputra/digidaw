import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/automation_provider.dart';

/// Accordion Widget to show all automation link connected to corresponding track
class TrackAccordion extends ConsumerStatefulWidget {
  final int trackId;

  const TrackAccordion({super.key, required this.trackId});

  @override
  TrackAccordionState createState() {
    return TrackAccordionState();
  }
}

class TrackAccordionState extends ConsumerState<TrackAccordion> {
  @override
  Widget build(BuildContext context) {
    final trackAutomationLanes = ref.watch(
      trackAutomationProvider(widget.trackId),
    );
    // TODO: implement build
    throw UnimplementedError();
  }
}

class TrackAccordionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
